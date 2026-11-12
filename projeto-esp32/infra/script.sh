#!/usr/bin/env bash
set -Eeuo pipefail

# Orquestrador do projeto. Pode ser invocado de qualquer diretorio.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"
LOG_DIR="$PROJECT_DIR/logs"
RUN_DIR="$SCRIPT_DIR/.run"

API_HOST="${API_HOST:-127.0.0.1}"
API_PORT="${API_PORT:-8080}"
FRONTEND_HOST="${FRONTEND_HOST:-127.0.0.1}"
FRONTEND_PORT="${FRONTEND_PORT:-5500}"
CHECK_HOST="127.0.0.1"
HEALTH_ATTEMPTS="${HEALTH_ATTEMPTS:-15}"
HEALTH_DELAY="${HEALTH_DELAY:-1}"
API_URL="http://${CHECK_HOST}:${API_PORT}"
FRONTEND_URL="http://${CHECK_HOST}:${FRONTEND_PORT}/code.html"
TUNNEL_URL=""
PUBLIC_URL=""

API_PID_FILE="$RUN_DIR/api.pid"
FRONTEND_PID_FILE="$RUN_DIR/frontend.pid"
CLOUDFLARE_PID_FILE="$RUN_DIR/cloudflare.pid"
API_STARTED_BY_SCRIPT=0
FRONTEND_STARTED_BY_SCRIPT=0
CLOUDFLARE_STARTED_BY_SCRIPT=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_BLUE=$'\033[0;34m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'
  C_RED=$'\033[0;31m'; C_RESET=$'\033[0m'
else
  C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi

info() { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok() { printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err() { printf '%s[ERRO]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
section() { printf '\n------------------------------------------------------------\n%s\n------------------------------------------------------------\n' "$1"; }

usage() {
  cat <<'EOF'
Uso:

  ./script.sh          Inicia todo o ambiente disponível
  ./script.sh start    Inicia todo o ambiente disponível
  ./script.sh status   Verifica o ambiente sem iniciar serviços
  ./script.sh stop     Para somente processos iniciados pelo script
  ./script.sh restart  Para e inicia novamente os processos do projeto
  ./script.sh help     Mostra esta ajuda

Configuracoes opcionais por variaveis de ambiente:
  API_HOST, API_PORT, FRONTEND_HOST, FRONTEND_PORT,
  HEALTH_ATTEMPTS, HEALTH_DELAY

PostgreSQL usa DATABASE_URL do ambiente ou de backend/.env.
Cloudflare Quick Tunnel gera uma URL publica aleatoria enquanto o script estiver ativo.
EOF
}

pid_is_expected_process() {
  local pid="$1" pattern="$2" command_line
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  command_line="$(ps -p "$pid" -o args= 2>/dev/null || true)"
  [[ -n "$command_line" && "$command_line" == *"$pattern"* ]]
}

port_pids() {
  local port="$1"
  if command -v fuser >/dev/null 2>&1; then
    fuser -n tcp "$port" 2>/dev/null || true
  elif command -v ss >/dev/null 2>&1; then
    ss -ltnp "sport = :$port" 2>/dev/null | sed -nE 's/.*pid=([0-9]+).*/\1/p' | sort -u | tr '\n' ' '
  fi
}

port_is_used() {
  local port="$1" pids
  pids="$(port_pids "$port")"
  [[ -n "${pids//[[:space:]]/}" ]]
}

show_port_owner() {
  local port="$1" pids pid
  pids="$(port_pids "$port")"
  if [[ -n "${pids//[[:space:]]/}" ]]; then
    for pid in $pids; do
      printf '      PID %s: %s\n' "$pid" "$(ps -p "$pid" -o args= 2>/dev/null || printf 'processo indisponivel')"
    done
  else
    printf '      PID nao identificado pelas ferramentas disponiveis.\n'
  fi
}

check_dependencies() {
  local missing=0 command_name
  info "Verificando dependencias do sistema..."
  for command_name in python3 pip psql curl cloudflared systemctl; do
    if command -v "$command_name" >/dev/null 2>&1; then
      ok "$command_name encontrado: $(command -v "$command_name")"
    else
      err "$command_name nao encontrado. Instale a dependencia do sistema antes de iniciar."
      if [[ "$command_name" == "psql" ]]; then
        info "Instale o cliente PostgreSQL. O script nao instala pacotes do sistema automaticamente."
      elif [[ "$command_name" == "cloudflared" ]]; then
        err "cloudflared não está instalado ou não está disponível no PATH."
      fi
      missing=1
    fi
  done
  if command -v python3 >/dev/null 2>&1; then
    info "$(python3 --version 2>&1)"
  fi
  if [[ -r /etc/os-release ]]; then
    info "Sistema operacional: $(sed -nE 's/^PRETTY_NAME="?([^"#]+)"?$/\1/p' /etc/os-release | sed -n '1p')"
  fi
  if command -v pip >/dev/null 2>&1; then
    info "$(pip --version 2>&1)"
  fi
  if command -v psql >/dev/null 2>&1; then
    info "$(psql --version 2>&1)"
  fi
  if command -v curl >/dev/null 2>&1; then
    info "$(curl --version | sed -n '1p')"
  fi
  if command -v cloudflared >/dev/null 2>&1; then
    info "$(cloudflared --version 2>&1 | sed -n '1p')"
  fi
  if (( missing )); then
    return 1
  fi

  if [[ ! -x "$BACKEND_DIR/.venv/bin/python" ]]; then
    err "Ambiente virtual nao encontrado em $BACKEND_DIR/.venv."
    info "Crie o ambiente e instale as dependencias conforme backend/README.md."
    return 1
  fi
  ok "Python no ambiente virtual: $("$BACKEND_DIR/.venv/bin/python" --version 2>&1)"
  ok "pip no ambiente virtual: $("$BACKEND_DIR/.venv/bin/pip" --version 2>&1)"
  if [[ ! -f "$BACKEND_DIR/requirements.txt" || ! -f "$BACKEND_DIR/app/main.py" ]]; then
    err "Backend FastAPI ou requirements.txt nao encontrado na estrutura esperada."
    return 1
  fi
  if [[ ! -f "$FRONTEND_DIR/code.html" ]]; then
    err "Frontend nao encontrado: $FRONTEND_DIR/code.html"
    return 1
  fi
  if ! (cd "$BACKEND_DIR" && .venv/bin/python -c 'import fastapi, uvicorn, sqlalchemy, psycopg, dotenv' 2>&1); then
    err "Dependencias Python ausentes no ambiente virtual."
    info "Execute: $BACKEND_DIR/.venv/bin/pip install -r $BACKEND_DIR/requirements.txt"
    return 1
  fi
  ok "Ambiente virtual e dependencias da API encontrados."
  ok "Frontend encontrado: $FRONTEND_DIR"
  return 0
}

check_postgresql() {
  local state
  section "POSTGRESQL / BANCO DE DADOS"
  info "Verificando servico PostgreSQL..."
  state="$(systemctl is-active postgresql 2>&1 || true)"
  if [[ "$state" != "active" ]]; then
    warn "PostgreSQL esta $state. Tentando iniciar sem prompt interativo..."
    if command -v sudo >/dev/null 2>&1 && sudo -n systemctl start postgresql; then
      ok "Comando de inicio enviado ao PostgreSQL."
    else
      err "Nao foi possivel iniciar PostgreSQL sem autenticacao interativa."
      info "Inicie o servico com permissao administrativa e execute novamente."
      return 1
    fi
    state="$(systemctl is-active postgresql 2>&1 || true)"
  fi
  if [[ "$state" != "active" ]]; then
    err "PostgreSQL nao ficou ativo (estado: $state)."
    return 1
  fi
  ok "Servico PostgreSQL ativo."

  info "Testando consulta SELECT 1 usando DATABASE_URL..."
  if ! (cd "$BACKEND_DIR" && .venv/bin/python - <<'PY'
from sqlalchemy import create_engine, text
from app.config import get_settings

url = get_settings().database_url
if not url:
    raise SystemExit("DATABASE_URL ausente no ambiente e em backend/.env")
if url.startswith("postgresql://"):
    url = url.replace("postgresql://", "postgresql+psycopg://", 1)
elif url.startswith("postgres://"):
    url = url.replace("postgres://", "postgresql+psycopg://", 1)
engine = create_engine(url, pool_pre_ping=True)
with engine.connect() as connection:
    assert connection.execute(text("SELECT 1")).scalar_one() == 1
engine.dispose()
PY
  ); then
    err "PostgreSQL esta ativo, mas DATABASE_URL/SELECT 1 falhou."
    info "Confira backend/.env e confirme que o banco e o usuario ja foram criados."
    return 1
  fi
  ok "Conexao PostgreSQL e SELECT 1 confirmados."
}

check_api() {
  curl --silent --show-error --fail --max-time 2 "$API_URL/health" >/dev/null 2>&1
}

check_frontend() {
  curl --silent --show-error --fail --max-time 2 "$FRONTEND_URL" >/dev/null 2>&1
}

check_frontend_api_config() {
  local expected_origin="http://localhost:${API_PORT}"
  if [[ ! -f "$FRONTEND_DIR/js/api.js" ]]; then
    warn "Arquivo frontend/js/api.js nao encontrado; confira configuracao da API no frontend."
    return 0
  fi
  if grep -Fq "apiBaseUrl: \"${expected_origin}\"" "$FRONTEND_DIR/js/api.js" \
    || { [[ "$API_PORT" == "8080" ]] && grep -Fq 'apiBaseUrl: window.API_BASE_URL || `${window.location.protocol}//${window.location.hostname}:8080`' "$FRONTEND_DIR/js/api.js"; }; then
    ok "Frontend configurado para consumir ${expected_origin}."
  else
    warn "A porta/URL da API no frontend/js/api.js nao corresponde a ${expected_origin}; nao alterei o JavaScript."
  fi

  if ! (cd "$BACKEND_DIR" && .venv/bin/python - <<PY
from app.config import get_settings
origins = get_settings().allowed_origins
expected = {"http://localhost:${FRONTEND_PORT}", "http://127.0.0.1:${FRONTEND_PORT}"}
raise SystemExit(0 if expected.intersection(origins) else 1)
PY
  ); then
    warn "CORS_ORIGINS nao parece permitir o frontend na porta ${FRONTEND_PORT}; ajuste backend/.env se necessario."
  else
    ok "CORS inclui a origem local do frontend."
  fi
}

wait_for_url() {
  local url="$1" label="$2" attempt
  info "Aguardando $label..."
  for ((attempt=1; attempt<=HEALTH_ATTEMPTS; attempt++)); do
    info "Tentativa ${attempt}/${HEALTH_ATTEMPTS}: $url"
    if curl --silent --show-error --fail --max-time 2 "$url" >/dev/null; then
      ok "$label respondeu HTTP."
      return 0
    fi
    if (( attempt < HEALTH_ATTEMPTS )); then sleep "$HEALTH_DELAY"; fi
  done
  return 1
}

start_api() {
  local existing_pid
  section "FASTAPI"
  if check_api; then
    warn "FastAPI ja responde em $API_URL/health; usando instancia existente."
    return 0
  fi
  if port_is_used "$API_PORT"; then
    err "Porta $API_PORT ja esta ocupada por processo desconhecido para esta API."
    show_port_owner "$API_PORT"
    return 1
  fi

  info "Iniciando FastAPI em ${API_HOST}:${API_PORT}..."
  mkdir -p "$LOG_DIR" "$RUN_DIR"
  (cd "$BACKEND_DIR" && exec .venv/bin/python -m uvicorn app.main:app --host "$API_HOST" --port "$API_PORT") >>"$LOG_DIR/api.log" 2>&1 &
  API_PID=$!
  printf '%s\n' "$API_PID" > "$API_PID_FILE"
  API_STARTED_BY_SCRIPT=1
  ok "FastAPI iniciada; PID $API_PID."

  if ! wait_for_url "$API_URL/health" "FastAPI /health"; then
    err "FastAPI nao iniciou corretamente. Log: $LOG_DIR/api.log"
    return 1
  fi
  if ! curl --silent --show-error --fail --max-time 3 "$API_URL/docs" >/dev/null; then
    err "FastAPI respondeu health, mas /docs nao esta acessivel."
    return 1
  fi
  ok "API Docs disponivel em ${API_URL}/docs"
}

start_frontend() {
  section "FRONTEND"
  if check_frontend; then
    warn "Frontend ja responde em $FRONTEND_URL; usando instancia existente."
    return 0
  fi
  if port_is_used "$FRONTEND_PORT"; then
    err "Porta $FRONTEND_PORT ja esta ocupada por processo desconhecido."
    show_port_owner "$FRONTEND_PORT"
    return 1
  fi

  info "Iniciando servidor HTTP do frontend em ${FRONTEND_HOST}:${FRONTEND_PORT}..."
  mkdir -p "$LOG_DIR" "$RUN_DIR"
  python3 -m http.server "$FRONTEND_PORT" --bind "$FRONTEND_HOST" --directory "$FRONTEND_DIR" >>"$LOG_DIR/frontend.log" 2>&1 &
  FRONTEND_PID=$!
  printf '%s\n' "$FRONTEND_PID" > "$FRONTEND_PID_FILE"
  FRONTEND_STARTED_BY_SCRIPT=1
  ok "Servidor frontend iniciado; PID $FRONTEND_PID."
  if ! wait_for_url "$FRONTEND_URL" "frontend code.html"; then
    err "Frontend nao respondeu. Log: $LOG_DIR/frontend.log"
    return 1
  fi
}

cloudflare_tunnel_url() {
  local log_file="$LOG_DIR/cloudflare.log"
  [[ -f "$log_file" ]] || return 1
  awk '/^--- project script quick tunnel start ---$/ { active=1; next }
       active { print }' "$log_file" \
    | grep -Eo 'https://[[:alnum:]-]+\.trycloudflare\.com' \
    | tail -n 1
}

cloudflare_connection_registered() {
  local log_file="$LOG_DIR/cloudflare.log"
  [[ -f "$log_file" ]] && awk '
    /^--- project script quick tunnel start ---$/ { active=1; registered=0; next }
    active && /Registered tunnel connection|Connection .* registered/ { registered=1 }
    END { exit !(active && registered) }
  ' "$log_file"
}

cloudflare_url_captured() {
  TUNNEL_URL="$(cloudflare_tunnel_url || true)"
  [[ -n "$TUNNEL_URL" ]]
}

stop_cloudflare_pid() {
  local pid="$1" attempt
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  pid_is_expected_process "$pid" cloudflared || return 0
  kill -0 "$pid" 2>/dev/null || return 0
  kill -TERM "$pid" 2>/dev/null || true
  for ((attempt=1; attempt<=5; attempt++)); do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 1
  done
  # The PID was created by this invocation, so force only that child if needed.
  if pid_is_expected_process "$pid" cloudflared; then
    kill -KILL "$pid" 2>/dev/null || true
  fi
  wait "$pid" 2>/dev/null || true
}

public_url_status() {
  local url="$1" body_file="$RUN_DIR/cloudflare-response.html" status
  status="$(curl --silent --show-error --location --max-time 8 \
    --output "$body_file" --write-out '%{http_code}' "${url}/code.html" 2>/dev/null || true)"
  if grep -Eqi 'Error 1033|Cloudflare Tunnel error' "$body_file" 2>/dev/null; then
    return 2
  fi
  [[ "$status" =~ ^2[0-9][0-9]$ ]]
}

start_cloudflare() {
  section "CLOUDFLARE TUNNEL"
  if ! command -v cloudflared >/dev/null 2>&1; then
    err "cloudflared não encontrado no PATH."
    return 1
  fi
  if [[ -f "$CLOUDFLARE_PID_FILE" ]]; then
    local pid
    pid="$(cat "$CLOUDFLARE_PID_FILE")"
    if pid_is_expected_process "$pid" "cloudflared"; then
      if cloudflare_url_captured && cloudflare_connection_registered; then
        ok "Cloudflare Quick Tunnel ja esta ativo; PID $pid."
        if public_url_status "$TUNNEL_URL"; then
          PUBLIC_URL="$TUNNEL_URL"
          printf '\nURL publica ONLINE: %s\n' "$PUBLIC_URL"
          return 0
        fi
        warn "A URL existente nao respondeu corretamente; reiniciando o tunnel."
      else
        warn "O processo registrado nao confirmou conexao ativa; reiniciando o tunnel."
      fi
      stop_cloudflare_pid "$pid"
    fi
    rm -f "$CLOUDFLARE_PID_FILE"
  fi

  PUBLIC_URL=""
  TUNNEL_URL=""

  if ! curl --silent --show-error --fail --max-time 3 "$FRONTEND_URL" >/dev/null; then
    err "Frontend indisponivel em $FRONTEND_URL; o tunnel nao sera iniciado."
    return 1
  fi

  mkdir -p "$LOG_DIR" "$RUN_DIR"
  local tunnel_attempt attempt public_status
  for ((tunnel_attempt=1; tunnel_attempt<=2; tunnel_attempt++)); do
    info "Iniciando Cloudflare Quick Tunnel (tentativa ${tunnel_attempt}/2) via HTTP/2 para evitar bloqueio QUIC..."
    printf '\n--- project script quick tunnel start ---\n' >>"$LOG_DIR/cloudflare.log"
    cloudflared tunnel --protocol http2 --url "http://localhost:${FRONTEND_PORT}" >>"$LOG_DIR/cloudflare.log" 2>&1 &
    CLOUDFLARE_PID=$!
    printf '%s\n' "$CLOUDFLARE_PID" > "$CLOUDFLARE_PID_FILE"
    CLOUDFLARE_STARTED_BY_SCRIPT=1

    for ((attempt=1; attempt<=HEALTH_ATTEMPTS; attempt++)); do
      if ! kill -0 "$CLOUDFLARE_PID" 2>/dev/null; then
        err "Cloudflare Tunnel encerrou antes de estabelecer conexao. Logs recentes:"
        tail -n 20 "$LOG_DIR/cloudflare.log" >&2
        rm -f "$CLOUDFLARE_PID_FILE"
        CLOUDFLARE_STARTED_BY_SCRIPT=0
        break
      fi
      if cloudflare_url_captured && cloudflare_connection_registered; then
        ok "Conexao HTTP/2 com Cloudflare registrada; PID $CLOUDFLARE_PID."
        break
      fi
      info "Aguardando URL e registro da conexao (${attempt}/${HEALTH_ATTEMPTS})..."
      sleep "$HEALTH_DELAY"
    done

    if ! kill -0 "$CLOUDFLARE_PID" 2>/dev/null; then
      (( tunnel_attempt < 2 )) && continue
      return 1
    fi
    if ! cloudflare_url_captured || ! cloudflare_connection_registered; then
      warn "Tunnel nao confirmou conexao ativa. Logs recentes:"
      tail -n 20 "$LOG_DIR/cloudflare.log" >&2
      stop_cloudflare_pid "$CLOUDFLARE_PID"
      rm -f "$CLOUDFLARE_PID_FILE"
      CLOUDFLARE_STARTED_BY_SCRIPT=0
      (( tunnel_attempt < 2 )) && continue
      err "Nao foi possivel registrar o tunnel apos duas tentativas."
      return 1
    fi

    TUNNEL_URL="$(cloudflare_tunnel_url)"
    for ((attempt=1; attempt<=HEALTH_ATTEMPTS; attempt++)); do
      if ! kill -0 "$CLOUDFLARE_PID" 2>/dev/null || ! cloudflare_connection_registered; then
        break
      fi
      if public_url_status "$TUNNEL_URL"; then
        PUBLIC_URL="$TUNNEL_URL"
        ok "URL publica respondeu HTTP com tunnel ativo."
        break
      else
        public_status=$?
        if (( public_status == 2 )); then
          warn "Cloudflare retornou Error 1033; PID e registro serao verificados antes de tentar novamente."
        else
          info "URL publica ainda propagando (${attempt}/${HEALTH_ATTEMPTS}); aguardando..."
        fi
      fi
      sleep "$HEALTH_DELAY"
    done

    if [[ -n "$PUBLIC_URL" ]] && kill -0 "$CLOUDFLARE_PID" 2>/dev/null && cloudflare_connection_registered; then
      break
    fi

    err "A URL publica nao ficou acessivel com conexao ativa. Logs recentes:"
    tail -n 20 "$LOG_DIR/cloudflare.log" >&2
    stop_cloudflare_pid "$CLOUDFLARE_PID"
    rm -f "$CLOUDFLARE_PID_FILE"
    CLOUDFLARE_STARTED_BY_SCRIPT=0
    PUBLIC_URL=""
    (( tunnel_attempt < 2 )) && continue
    err "Quick Tunnel falhou duas vezes; verifique a saida TCP 7844/rede."
    return 1
  done

  if [[ -z "$PUBLIC_URL" ]] || ! kill -0 "$CLOUDFLARE_PID" 2>/dev/null || ! cloudflare_connection_registered; then
    err "Tunnel nao esta conectado; URL nao sera apresentada como funcional."
    return 1
  fi

  printf '\n============================================================\n'
  printf '              GRALHA - FRONTEND HMI\n'
  printf '============================================================\n'
  printf 'Servidor local:\nhttp://localhost:%s/code.html\n\n' "$FRONTEND_PORT"
  printf 'Cloudflare Tunnel:\n%s\n' "$PUBLIC_URL"
  printf '============================================================\n'
  printf 'Acesse o sistema pelo link acima.\n'
  printf '============================================================\n\n'
  ok "Tunnel ONLINE. O processo cloudflared permanece ativo ate CTRL+C."
}

stop_one() {
  local label="$1" file="$2" expected="$3" pid attempt
  [[ -f "$file" ]] || return 0
  pid="$(cat "$file")"
  if ! pid_is_expected_process "$pid" "$expected"; then
    warn "$label nao esta ativo pelo PID registrado; removendo PID obsoleto."
    rm -f "$file"
    return 0
  fi
  if [[ "$expected" == "cloudflared" ]]; then
    info "Encerrando Cloudflare Tunnel (PID $pid)..."
    stop_cloudflare_pid "$pid"
    rm -f "$file"
    ok "Cloudflare Tunnel encerrado."
    return 0
  fi
  info "Encerrando $label (PID $pid)..."
  kill -TERM "$pid" 2>/dev/null || true
  for ((attempt=1; attempt<=5; attempt++)); do
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$file"
      ok "$label encerrado."
      return 0
    fi
    sleep 1
  done
  if pid_is_expected_process "$pid" "$expected"; then
    warn "$label ainda responde a SIGTERM; nao enviarei SIGKILL automaticamente."
    return 1
  fi
  rm -f "$file"
  ok "$label encerrado."
}

stop_services() {
  section "ENCERRANDO SERVICOS DO PROJETO"
  stop_one "Cloudflare Tunnel" "$CLOUDFLARE_PID_FILE" "cloudflared" || true
  stop_one "Frontend" "$FRONTEND_PID_FILE" "http.server" || true
  stop_one "FastAPI" "$API_PID_FILE" "uvicorn app.main:app" || true
  info "PostgreSQL nao sera encerrado; permanece como servico do sistema."
}

cleanup() {
  local exit_code=$?
  trap - INT TERM EXIT
  printf '\n============================================================\n'
  printf '              ENCERRANDO SISTEMA\n'
  printf '============================================================\n'
  stop_services
  rm -f "$RUN_DIR/cloudflare-response.html"
  printf '============================================================\n'
  printf '             SISTEMA ENCERRADO COM SEGURANCA\n'
  printf '============================================================\n'
  exit "$exit_code"
}

detect_status() {
  local pg_state db_state api_state frontend_state cf_state pid
  printf '\n============================================================\nSTATUS DO SISTEMA\n============================================================\n'
  pg_state="$(systemctl is-active postgresql 2>&1 || true)"
  if [[ "$pg_state" == "active" ]]; then ok "PostgreSQL       : ONLINE (systemd)"; else warn "PostgreSQL       : OFFLINE ($pg_state)"; fi

  db_state="OFFLINE"
  if [[ -x "$BACKEND_DIR/.venv/bin/python" && -f "$BACKEND_DIR/app/main.py" ]]; then
    if (cd "$BACKEND_DIR" && .venv/bin/python - <<'PY'
from sqlalchemy import create_engine, text
from app.config import get_settings
url = get_settings().database_url
if not url:
    raise SystemExit(1)
if url.startswith(("postgresql://", "postgres://")):
    url = url.replace("postgres://", "postgresql+psycopg://", 1).replace("postgresql://", "postgresql+psycopg://", 1)
engine = create_engine(url, pool_pre_ping=True)
with engine.connect() as connection:
    connection.execute(text("SELECT 1"))
engine.dispose()
PY
    ); then db_state="ONLINE"; fi
  fi
  if [[ "$db_state" == "ONLINE" ]]; then ok "Banco de dados  : ONLINE"; else warn "Banco de dados  : OFFLINE (sem conexao/configuracao)"; fi

  api_state="OFFLINE"
  if check_api; then api_state="ONLINE"; fi
  if [[ "$api_state" == "ONLINE" ]]; then ok "FastAPI          : ONLINE ($API_URL)"; else warn "FastAPI          : OFFLINE"; fi

  frontend_state="OFFLINE"
  if check_frontend; then frontend_state="ONLINE"; fi
  if [[ "$frontend_state" == "ONLINE" ]]; then ok "Frontend         : ONLINE ($FRONTEND_URL)"; else warn "Frontend         : OFFLINE"; fi

  cf_state="OFFLINE"
  if [[ -f "$CLOUDFLARE_PID_FILE" ]]; then
    pid="$(cat "$CLOUDFLARE_PID_FILE")"
    if pid_is_expected_process "$pid" cloudflared && cloudflare_url_captured && cloudflare_connection_registered; then PUBLIC_URL="$TUNNEL_URL"; cf_state="ONLINE"; fi
  fi
  if [[ "$cf_state" == "ONLINE" ]]; then
    ok "Cloudflare       : ONLINE${PUBLIC_URL:+ ($PUBLIC_URL)}"
  elif command -v cloudflared >/dev/null 2>&1; then
    warn "Cloudflare       : OFFLINE / sem URL ativa"
  else
    err "Cloudflare       : OFFLINE (cloudflared ausente)"
  fi

  printf '\nLogs: %s\n' "$LOG_DIR"
}

start_all() {
  local next_tunnel_probe
  mkdir -p "$LOG_DIR" "$RUN_DIR"
  printf '============================================================\n'
  printf '       SISTEMA DE CONTROLE E SUPERVISAO ESP32\n'
  printf '============================================================\n'
  info "Projeto: $PROJECT_DIR"
  if ! check_dependencies; then return 1; fi
  check_frontend_api_config
  if ! check_postgresql; then return 1; fi
  trap cleanup INT TERM EXIT
  if ! start_api; then return 1; fi
  if ! start_frontend; then return 1; fi
  start_cloudflare

  section "STATUS FINAL"
  ok "PostgreSQL e banco: ONLINE"
  ok "FastAPI: ONLINE — ${API_URL}"
  ok "API Docs: ${API_URL}/docs"
  ok "Frontend: ONLINE — http://localhost:${FRONTEND_PORT}/code.html"
  if [[ -n "$PUBLIC_URL" ]] && cloudflare_url_captured; then
    printf '\n============================================================\n'
    printf '              GRALHA - FRONTEND HMI\n'
    printf '============================================================\n'
    printf 'Servidor local:\nhttp://localhost:%s/code.html\n\n' "$FRONTEND_PORT"
    printf 'Cloudflare Tunnel:\n%s\n' "$PUBLIC_URL"
    printf '============================================================\n'
    printf 'Acesse o sistema pelo link acima.\n'
    printf '============================================================\n'
    warn "O link publica o frontend. A API ainda precisa de um endereco publico para funcionar fora deste computador."
  else
    warn "Frontend publico: nao configurado/verificado."
  fi
  printf '\nLogs:\n  API        -> %s/api.log\n  Frontend   -> %s/frontend.log\n  Cloudflare -> %s/cloudflare.log\n' "$LOG_DIR" "$LOG_DIR" "$LOG_DIR"
  printf '\nPressione CTRL+C para encerrar somente os processos iniciados pelo script.\n'

  next_tunnel_probe=$((SECONDS + 30))
  while :; do
    if (( API_STARTED_BY_SCRIPT )) && ! kill -0 "$API_PID" 2>/dev/null; then
      err "FastAPI encerrou inesperadamente. Consulte $LOG_DIR/api.log"
      return 1
    fi
    if (( FRONTEND_STARTED_BY_SCRIPT )) && ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
      err "Frontend encerrou inesperadamente. Consulte $LOG_DIR/frontend.log"
      return 1
    fi
    if (( CLOUDFLARE_STARTED_BY_SCRIPT )) && ! kill -0 "$CLOUDFLARE_PID" 2>/dev/null; then
      err "Cloudflare Tunnel encerrou inesperadamente. Consulte $LOG_DIR/cloudflare.log"
      return 1
    fi
    if (( CLOUDFLARE_STARTED_BY_SCRIPT )) && (( SECONDS >= next_tunnel_probe )); then
      local probe_status=0
      public_url_status "$PUBLIC_URL" || probe_status=$?
      if (( probe_status != 0 )); then
        if (( probe_status == 2 )); then
          warn "A URL retornou Error 1033; verificando e recriando o tunnel."
          start_cloudflare || return 1
        else
          warn "Falha temporaria ao consultar a URL publica; o tunnel segue ativo e sera verificado novamente."
        fi
      fi
      next_tunnel_probe=$((SECONDS + 30))
    fi
    sleep 1
  done
}

main() {
  local action="${1:-start}"
  case "$action" in
    start) start_all ;;
    status) detect_status ;;
    stop) stop_services ;;
    restart) stop_services; start_all ;;
    help|-h|--help) usage ;;
    *) err "Comando desconhecido: $action"; usage >&2; return 2 ;;
  esac
}

main "$@"
