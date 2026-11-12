(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);
  const value = (input, suffix = "") => input === null || input === undefined || input === "" ? "—" : `${input}${suffix}`;
  const number = (input) => input === null || input === undefined || input === "" ? null : Number.isFinite(Number(input)) ? Number(input) : null;
  const statusLabels = {
    PENDENTE: "Pendente", AGUARDANDO: "Aguardando", AGUARDANDO_RFID: "Aguardando RFID",
    EM_EXECUCAO: "Em execução", EXECUTANDO: "Em execução", CONCLUIDA: "Concluída",
    CONCLUIDO: "Concluído", CANCELADA: "Cancelada", ERRO: "Erro", OFFLINE: "Offline",
    ONLINE: "Online", PARADO: "Parado", PRONTO: "Pronto", HORARIO: "Horário",
    ANTIHORARIO: "Anti-horário"
  };
  const translate = (status) => status ? (statusLabels[String(status).toUpperCase()] || String(status).replaceAll("_", " ")) : "—";

  function set(id, text) {
    const node = $(id);
    if (node) node.textContent = text;
  }

  function setState(node, state) {
    if (node) node.dataset.state = state || "unknown";
  }

  function render(data) {
    if (!data) data = {};
    const device = data.dispositivo || data.device || null;
    const rfid = data.rfid || null;
    const part = data.peca || null;
    const order = data.ordem_producao || null;
    const motor = data.motor || data.parametros_motor || null;
    const process = data.processo || null;
    const execution = data.execucao || null;

    set("device-id-val", value(device?.device_id));
    const deviceMeta = [device?.ip_address, device?.mac_address, device?.localizacao].filter(Boolean).join(" · ");
    set("device-meta-val", deviceMeta || "");
    const deviceStatus = device?.ultimo_status || null;
    set("device-status-val", translate(deviceStatus));
    setState($("device-status-val"), deviceStatus?.toLowerCase());
    const dot = $("device-status-dot");
    if (dot) dot.innerHTML = deviceStatus?.toUpperCase() === "ONLINE"
      ? '<span class="pulse-ring-active absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span><span class="relative inline-flex rounded-full h-3 w-3 bg-emerald-500"></span>'
      : '<span class="relative inline-flex rounded-full h-3 w-3 bg-slate-500"></span>';

    set("rfid-uid-val", value(rfid?.uid_hex));
    setState($("rfid-status-badge"), rfid?.uid_hex ? "identified" : "waiting");
    set("part-name-val", value(part?.nome));
    set("part-code-val", value(part?.codigo));
    const details = [part?.tamanho, part?.cor, part?.material, part?.peso != null ? `Peso ${part.peso}` : null]
      .filter(Boolean).join(" · ");
    set("part-detail-val", details || "—");

    set("op-number-val", value(order?.numero));
    const dueDate = order?.data_previsao ? new Date(order.data_previsao) : null;
    set("op-due-date", dueDate && !Number.isNaN(dueDate.getTime()) ? dueDate.toLocaleString("pt-BR") : "—");
    set("op-produced-val", value(order?.quantidade_produzida));
    set("op-planned-val", value(order?.quantidade_planejada));
    const planned = number(order?.quantidade_planejada);
    const produced = number(order?.quantidade_produzida);
    const progress = $("op-progress-bar");
    if (progress) progress.style.width = planned > 0 && produced !== null
      ? `${Math.max(0, Math.min(100, produced / planned * 100))}%` : "0%";

    const processStatus = process?.status || execution?.status || process?.motor_status || null;
    set("process-status-text", translate(processStatus));
    const stateName = processStatus?.toLowerCase();
    const processBadge = $("process-status-container");
    const processDot = $("process-status-dot");
    setState(processBadge, stateName);
    setState(processDot, stateName);
    const badgeColors = {
      em_execucao: ["#dcfce7", "#86efac", "#166534", "#16a34a"],
      executando: ["#dcfce7", "#86efac", "#166534", "#16a34a"],
      concluida: ["#e0f2fe", "#7dd3fc", "#075985", "#0284c7"],
      concluido: ["#e0f2fe", "#7dd3fc", "#075985", "#0284c7"],
      erro: ["#fef2f2", "#fca5a5", "#991b1b", "#dc2626"]
    };
    const badgeColor = badgeColors[stateName] || ["#f1f5f9", "#cbd5e1", "#475569", "#64748b"];
    if (processBadge) {
      processBadge.style.backgroundColor = badgeColor[0];
      processBadge.style.borderColor = badgeColor[1];
      processBadge.style.color = badgeColor[2];
    }
    if (processDot) processDot.style.backgroundColor = badgeColor[3];
    const orderStatus = order?.status ? `Ordem: ${translate(order.status)}` : "Ordem indisponível";
    const prompt = `${orderStatus} · ${processStatus ? `Processo: ${translate(processStatus)}` : "Telemetria do processo indisponível"}`;
    set("process-substatus-text", prompt);
    set("operator-prompt-text", deviceStatus?.toUpperCase() === "OFFLINE" ? "ESP32 offline; aguardando nova telemetria."
      : data.rfid_status === "NAO_CADASTRADO" ? "RFID não cadastrado."
      : !rfid?.uid_hex ? "Aguardando identificação RFID fornecida pela API."
      : !order ? "Nenhuma ordem de produção disponível."
      : !motor ? "Ordem carregada; configuração do Motor de Passo indisponível."
      : "Dados carregados da API. Comandos de execução não estão disponíveis.");

    const motorStatus = process?.motor_status || execution?.status || null;
    set("motor-state-badge", translate(motorStatus));
    setState($("motor-state-badge"), motorStatus?.toLowerCase());
    const primary = $("motor-position-primary");
    const unit = $("motor-position-unit");
    const degree = $("motor-position-degree");
    if (primary) primary.textContent = value(motor?.passos ?? motor?.angulo);
    if (unit) unit.textContent = motor?.passos != null ? "passos" : motor?.angulo != null ? "graus" : "";
    if (degree) degree.textContent = "";
    set("motor-dir-label", translate(motor?.direcao));
    set("motor-speed-val", value(motor?.velocidade));
    set("motor-accel-val", value(motor?.aceleracao));
    set("motor-mov-planned-val", value(motor?.quantidade_movimentos));
    set("motor-wait-val", value(motor?.tempo_espera_ms));
    set("motor-total-steps-val", value(motor?.angulo));
    const rotor = $("motor-rotor-visual");
    const motorIndicator = $("motor-running-indicator");
    const running = ["EXECUTANDO", "EM_EXECUCAO"].includes(String(motorStatus).toUpperCase());
    if (rotor) {
      rotor.classList.remove("motor-rot-cw", "motor-rot-ccw");
      rotor.classList.add("motor-rot-paused");
      const direction = String(motor?.direcao || "").toUpperCase();
      if (running && ["HORARIO", "ANTIHORARIO"].includes(direction)) {
        rotor.classList.remove("motor-rot-paused");
        rotor.classList.add(direction === "ANTIHORARIO" ? "motor-rot-ccw" : "motor-rot-cw");
      }
    }
    if (motorIndicator) motorIndicator.classList.toggle("bg-emerald-400", running);
    if (motorIndicator) motorIndicator.classList.toggle("bg-slate-400", !running);

    const currentMoves = number(execution?.movimentos_executados ?? process?.movimento_atual);
    const totalMoves = number(execution?.total_movimentos ?? process?.total_movimentos);
    set("exec-device-id", value(device?.device_id));
    set("exec-status-badge", execution || process?.status ? translate(execution?.status || process?.status) : "Execução indisponível");
    set("exec-mov-current", value(execution?.movimentos_executados ?? process?.movimento_atual));
    set("exec-mov-total", value(execution?.total_movimentos ?? process?.total_movimentos));
    set("exec-steps-current", value(execution?.passos_executados));
    set("exec-steps-total", value(execution?.total_passos));
    const executionPercent = currentMoves !== null && totalMoves > 0
      ? `${Math.max(0, Math.min(100, Math.round(currentMoves / totalMoves * 100)))}%` : "—";
    set("exec-pct-val", executionPercent);

    set("sensor-temp-val", value(process?.temperatura));
    set("sensor-voltage-val", "—");
    set("last-ping-val", value(device?.ultimo_contato));
    set("motor-actual-position", value(process?.posicao));
  }

  function setApiStatus(connected) {
    const node = $("comm-status-val");
    if (node) {
      node.innerHTML = `<span class="w-2 h-2 rounded-full ${connected ? "bg-emerald-500" : "bg-red-500"}"></span><span>${connected ? "API CONECTADA" : "API INDISPONÍVEL"}</span>`;
      setState(node, connected ? "online" : "offline");
    }
    set("api-status-val", connected ? "CONECTADA" : "INDISPONÍVEL");
    setState($("api-status-val"), connected ? "online" : "offline");
  }

  let requestInProgress = false;
  async function refresh() {
    if (requestInProgress) return;
    requestInProgress = true;
    try {
      const data = await fetchSupervision();
      render(data);
      setApiStatus(true);
    } catch (error) {
      setApiStatus(false);
      set("operator-prompt-text", error.status >= 500 || !error.status
        ? "API indisponível; os últimos dados exibidos podem estar desatualizados."
        : "Erro ao carregar dados da supervisão.");
      console.error("Falha ao atualizar supervisão:", error);
    } finally {
      requestInProgress = false;
    }
  }

  window.addEventListener("DOMContentLoaded", () => {
    render(null);
    setApiStatus(false);
    refresh();
    window.setInterval(refresh, API_CONFIG.pollingIntervalMs);
  });
})();
