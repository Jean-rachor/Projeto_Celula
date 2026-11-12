# Integração FastAPI, PostgreSQL e HMI ESP32

O fluxo HTTP implementado é:

```text
ESP32 --POST telemetria--> FastAPI --SQLAlchemy--> PostgreSQL
                                  ↑                  ↓
Frontend --GET supervisão-------+------------------+
```

O navegador só conhece a URL da API; credenciais PostgreSQL ficam no backend. A HMI atualiza a cada 1,5 s por polling, sem MQTT, WebSocket ou SSE.

## Estado real do firmware

`framework/main.cpp` atualmente controla um servo no GPIO 18 por comandos seriais (`servo`, `home`, `status`, `help`). Não implementa leitor RFID, Wi-Fi, HTTP nem MQTT. O esquema de banco descreve parâmetros de motor de passo, portanto o firmware e o modelo de produção ainda não são equivalentes. A API abaixo aceita telemetria HTTP de um dispositivo que implemente esse contrato; não há tópico MQTT definido no projeto, e nenhum foi inventado. Não envie parâmetros de passo ao servo atual.

## PostgreSQL e configuração

Requer PostgreSQL, Python 3.10+ e um banco com `data/schema.sql` aplicado. Crie/seleciona um usuário e banco conforme a instalação e configure `backend/.env`:

```bash
cd /home/adriel/projeto-esp32/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Preencha `DATABASE_URL` com a conexão privada do ambiente. Para preparar um banco novo, um administrador pode executar:

```bash
createdb controle_esp32
psql -d controle_esp32 -f /home/adriel/projeto-esp32/data/schema.sql
```

O `schema.sql` cria as seis tabelas de produção e registros fictícios de desenvolvimento. Execute-o uma vez por banco vazio.

## Iniciar

Na pasta `backend`, com `.venv` e `.env` configurados, inicie a API com um worker:

```bash
uvicorn app.main:app --host 127.0.0.1 --port 8080
```

Um worker mantém o último snapshot de telemetria em memória. Para vários workers, será necessário armazenar também o snapshot completo no PostgreSQL ou usar um transporte compartilhado.

Em outro terminal:

```bash
cd /home/adriel/projeto-esp32/frontend
python3 -m http.server 5500
```

Abra `http://localhost:5500/code.html`. A URL padrão da API é `http://<host-do-frontend>:8080`, configurada em `frontend/js/api.js`. Para outra porta ou host, defina `window.API_BASE_URL` antes de carregar `js/api.js`. `CORS_ORIGINS` em `backend/.env` deve listar exatamente a origem usada pelo navegador; os padrões incluem as portas locais 5500 e 8080.

## Endpoints

| Método | Endpoint | Uso |
|---|---|---|
| GET | `/health` | Confirma API e conexão PostgreSQL; retorna 503 se o banco não responder. |
| GET | `/api/rfid/{uid_hex}` | Resolve tag, peça, ordem ativa/prioritária e parâmetros do motor. Retorna 404 para tag ausente/inativa. |
| GET | `/api/ordens/{numero_ordem}` | Consulta ordem, peça, previsão e quantidades. |
| GET | `/api/supervisao` | Payload consolidado que a HMI consulta por polling. |
| GET | `/api/dispositivos/{device_id}` | Status e metadados do dispositivo. |
| GET | `/api/esp32/{device_id}/config?uid_hex=...` | Devolve configuração cadastrada ao dispositivo; não inicia movimento. |
| POST | `/api/esp32/telemetria` | Atualiza estado do dispositivo, snapshot de supervisão e execução quando há RFID, ordem e contadores reais. |

A resposta de supervisão combina RFID/peça/ordem/parâmetros consultados no PostgreSQL, telemetria mais recente recebida pelo processo da API, status/metadados do dispositivo e a última execução persistida para ordem/dispositivo. `rfid_status` diferencia `AGUARDANDO`, `IDENTIFICADO` e `NAO_CADASTRADO`. A previsão da ordem, material, peso e metadados do dispositivo são nulos quando não cadastrados.

## Contrato de telemetria HTTP

Um firmware que implemente Wi-Fi/RFID poderá enviar ao endpoint existente, por exemplo:

```json
{
  "device_id": "ESP32-001",
  "status": "ONLINE",
  "process_status": "EM_EXECUCAO",
  "motor_status": "EXECUTANDO",
  "posicao": 90,
  "movimento_atual": 1,
  "total_movimentos": 2,
  "passos_executados": 200,
  "rfid_uid_hex": "A1B2C3D4"
}
```

`device_id` precisa existir e estar ativo em `dispositivos`; o UID é validado sem normalizar seu conteúdo e precisa corresponder ao formato já cadastrado. Execução é gravada em `execucoes_producao` somente quando a ordem foi resolvida e o ESP enviou ambos os contadores `passos_executados` e `movimento_atual`; se os contadores forem omitidos, nenhum progresso fictício é criado. Estados de execução aceitos são `AGUARDANDO`, `EM_EXECUCAO`/`EXECUTANDO`, `CONCLUIDA`, `ERRO` e `CANCELADA`. Telemetria atualiza presença do dispositivo no banco.

O payload não altera `quantidade_produzida`; contar peças requer um evento de conclusão/contagem confiável do hardware, ainda inexistente. `temperatura` é opcional e só deve ser enviada se vier de um sensor real. O endpoint não implementa comandos de INICIAR/STOP.

## Testes

```bash
cd /home/adriel/projeto-esp32/backend
.venv/bin/pytest -q
```

Os testes automatizados exercitam os contratos HTTP e persistência usando dublês de sessão; eles não substituem a validação com credenciais e um PostgreSQL real. Com o banco configurado, verifique `/health`, `/api/rfid/A1B2C3D4`, `/api/rfid/FFFFFFFF`, `/api/ordens/OP-2026-00125` e `/api/supervisao`.
