(() => {
  "use strict";

  const STORAGE_KEY = "esp32-hmi-production-order-drafts-v1";
  const DEMO_PARTS = [
    { id: 1, codigo: "PEC-001", nome: "Carcaca W22", material: "Aluminio", tamanho: "Medio", cor: "Azul" },
    { id: 2, codigo: "PEC-002", nome: "Suporte S10", material: "Aco", tamanho: "Pequeno", cor: "Preto" }
  ];
  const STATUS_LABELS = {
    PENDENTE: "Pendente",
    EM_EXECUCAO: "Em execução",
    CONCLUIDA: "Concluída",
    CANCELADA: "Cancelada"
  };
  const PRIORITY_LABELS = {
    1: "1 · Mais alta", 2: "2 · Alta", 3: "3 · Normal", 4: "4 · Baixa", 5: "5 · Mais baixa"
  };
  const $ = (id) => document.getElementById(id);
  const form = $("order-form");
  const parts = Array.isArray(window.ORDER_FORM_PARTS) ? window.ORDER_FORM_PARTS : DEMO_PARTS;
  let rfids = [];

  function readDrafts() {
    try {
      const data = JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "[]");
      return Array.isArray(data) ? data : [];
    } catch (error) {
      console.warn("Não foi possível ler os rascunhos locais:", error);
      return [];
    }
  }

  function writeDrafts(drafts) {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(drafts));
      return true;
    } catch (error) {
      console.error("Não foi possível salvar o rascunho local:", error);
      return false;
    }
  }

  function selectedPart() {
    const selectedId = Number($("peca_id").value);
    return parts.find((part) => Number(part.id) === selectedId) || null;
  }

  function canonicalUid(value) {
    return value.replaceAll(":", "").trim().toUpperCase();
  }

  function initParts() {
    const select = $("peca_id");
    for (const part of parts.filter((item) => item && item.ativo !== false)) {
      const option = document.createElement("option");
      option.value = String(part.id);
      option.textContent = `${part.codigo} — ${part.nome}`;
      select.append(option);
    }

    if (window.ORDER_FORM_PARTS) {
      $("parts-notice").textContent = parts.length
        ? "Catálogo fornecido pela aplicação. Confirme que ele corresponde às peças ativas no banco antes de integrar o envio."
        : "Nenhuma peça foi fornecida à página. O formulário não pode preparar uma ordem sem selecionar uma peça existente.";
      $("part-help").textContent = "Selecione uma peça da fonte fornecida pela aplicação.";
    } else {
      $("parts-notice").textContent = "O backend atual não oferece listagem de peças. Para permitir a montagem visual do formulário, estão disponíveis apenas as duas peças de demonstração declaradas em data/schema.sql; elas não confirmam o conteúdo atual do banco.";
    }
    updatePartDetails();
  }

  function updatePartDetails() {
    const part = selectedPart();
    const details = $("part-details");
    details.hidden = !part;
    $("part-code").textContent = part?.codigo || "—";
    $("part-name").textContent = part?.nome || "—";
    $("part-material").textContent = part?.material || "—";
    $("part-size").textContent = part?.tamanho || "—";
    $("summary-part").textContent = part ? `${part.codigo} — ${part.nome}` : "Selecione uma peça";
  }

  function renderRfids() {
    const target = $("rfid-list");
    target.replaceChildren();
    if (!rfids.length) {
      const empty = document.createElement("p");
      empty.className = "rfid-empty";
      empty.textContent = "Nenhuma tag vinculada a esta ordem.";
      target.append(empty);
      $("summary-rfids").textContent = "Nenhuma tag";
      return;
    }

    rfids.forEach((uid, index) => {
      const chip = document.createElement("span");
      chip.className = "rfid-chip";
      const label = document.createElement("span");
      label.textContent = uid;
      const remove = document.createElement("button");
      remove.type = "button";
      remove.setAttribute("aria-label", `Remover RFID ${uid}`);
      remove.title = "Remover esta tag";
      remove.textContent = "×";
      remove.addEventListener("click", () => {
        rfids.splice(index, 1);
        renderRfids();
        updateSummary();
      });
      chip.append(label, remove);
      target.append(chip);
    });
    $("summary-rfids").textContent = `${rfids.length} ${rfids.length === 1 ? "tag" : "tags"}: ${rfids.join(", ")}`;
  }

  function showRfidError(message = "") {
    const error = $("rfid-error");
    error.textContent = message;
    error.hidden = !message;
    $("rfid-uid").setAttribute("aria-invalid", message ? "true" : "false");
  }

  function addRfid() {
    const input = $("rfid-uid");
    const entered = input.value.trim().toUpperCase();
    if (!/^[0-9A-F]{2}(?::?[0-9A-F]{2})*$/.test(entered) || entered.length > 32) {
      showRfidError("Informe um UID hexadecimal válido, em pares de dígitos. Os dois-pontos são opcionais.");
      input.focus();
      return;
    }
    const uid = canonicalUid(entered);
    const currentOrder = $("numero_ordem").value.trim().toLocaleUpperCase("pt-BR");
    const collision = readDrafts().some((draft) => {
      if (draft.payload?.ordem_producao?.numero_ordem?.toLocaleUpperCase("pt-BR") === currentOrder && currentOrder) return false;
      return (draft.payload?.rfid_tags || []).some((item) => canonicalUid(item.uid_hex) === uid);
    });
    if (rfids.some((item) => canonicalUid(item) === uid) || collision) {
      showRfidError("Este UID já está associado a esta ordem ou a outro rascunho salvo neste navegador.");
      input.focus();
      return;
    }
    rfids.push(uid);
    rfids.sort();
    input.value = "";
    showRfidError();
    renderRfids();
    updateSummary();
    input.focus();
  }

  function movementType() {
    return form.querySelector('input[name="tipo_movimento"]:checked')?.value || "passos";
  }

  function updateMovementFields() {
    const bySteps = movementType() === "passos";
    $("steps-field").hidden = !bySteps;
    $("angle-field").hidden = bySteps;
    $("passos").disabled = !bySteps;
    $("passos").required = bySteps;
    $("angulo").disabled = bySteps;
    $("angulo").required = !bySteps;
    updateSummary();
  }

  function displayNumber(value) {
    if (value === null || value === undefined || value === "") return "—";
    return new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 3 }).format(Number(value));
  }

  function updateSummary() {
    const part = selectedPart();
    const type = movementType();
    const movement = type === "passos"
      ? `${displayNumber($("passos").value)} passos`
      : `${displayNumber($("angulo").value)}°`;
    const direction = $("direcao").value === "HORARIO" ? "Horário" : "Anti-horário";
    const acceleration = $("aceleracao").value ? ` · ${displayNumber($("aceleracao").value)} passos/s²` : " · aceleração não definida";
    $("summary-order").textContent = $("numero_ordem").value.trim() || "—";
    $("summary-part").textContent = part ? `${part.codigo} — ${part.nome}` : "Selecione uma peça";
    $("summary-quantity").textContent = `${$("quantidade_produzida").value || 0} / ${$("quantidade_planejada").value || 0}`;
    $("summary-priority").textContent = PRIORITY_LABELS[$("prioridade").value] || "—";
    $("summary-status").textContent = STATUS_LABELS[$("status").value] || "—";
    $("summary-motor").textContent = `${movement} · ${direction} · ${displayNumber($("velocidade").value)} passos/s${acceleration} · ${displayNumber($("tempo_espera_ms").value)} ms · ${displayNumber($("quantidade_movimentos").value)} movimento(s)`;
  }

  function timestampWithoutTimezone(value) {
    return value ? `${value.replace("T", " ")}:00` : null;
  }

  function makePayload() {
    const type = movementType();
    const part = selectedPart();
    return {
      ordem_producao: {
        numero_ordem: $("numero_ordem").value.trim(),
        peca_id: Number(part.id),
        quantidade_planejada: Number($("quantidade_planejada").value),
        quantidade_produzida: Number($("quantidade_produzida").value),
        status: $("status").value,
        prioridade: Number($("prioridade").value),
        data_inicio: timestampWithoutTimezone($("data_inicio").value),
        data_previsao: timestampWithoutTimezone($("data_previsao").value),
        observacao: $("observacao").value.trim() || null
      },
      parametros_motor: {
        passos: type === "passos" ? Number($("passos").value) : null,
        direcao: $("direcao").value,
        velocidade: Number($("velocidade").value),
        aceleracao: $("aceleracao").value === "" ? null : Number($("aceleracao").value),
        angulo: type === "angulo" ? Number($("angulo").value) : null,
        tempo_espera_ms: Number($("tempo_espera_ms").value),
        quantidade_movimentos: Number($("quantidade_movimentos").value),
        ativo: $("motor-ativo").checked
      },
      // Mapeamento de rascunho: o backend atual não oferece gravação RFID por ordem.
      rfid_tags: rfids.map((uid_hex) => ({ uid_hex }))
    };
  }

  function validateBusinessRules() {
    const planned = Number($("quantidade_planejada").value);
    const produced = Number($("quantidade_produzida").value);
    const start = $("data_inicio").value;
    const due = $("data_previsao").value;
    const orderNumber = $("numero_ordem").value.trim().toLocaleUpperCase("pt-BR");
    const drafts = readDrafts();
    if (!orderNumber) return "Informe o número da ordem.";
    if (!selectedPart()) return "Selecione uma peça existente.";
    if (!Number.isInteger(planned) || planned <= 0) return "A quantidade planejada deve ser um inteiro positivo.";
    if (!Number.isInteger(produced) || produced < 0 || produced > planned) return "A quantidade produzida deve ser um inteiro entre zero e a quantidade planejada.";
    if (!Object.hasOwn(STATUS_LABELS, $("status").value)) return "Selecione um status válido.";
    if (!Number.isInteger(Number($("prioridade").value)) || Number($("prioridade").value) < 1 || Number($("prioridade").value) > 5) return "A prioridade deve ficar entre 1 e 5.";
    if (drafts.some((draft) => draft.payload?.ordem_producao?.numero_ordem?.toLocaleUpperCase("pt-BR") === orderNumber)) return "Já existe um rascunho com esse número de ordem neste navegador.";
    if (start && due && new Date(due) < new Date(start)) return "A previsão não pode ser anterior à data de início.";
    if (!rfids.length) return "Adicione pelo menos um UID RFID para vincular à ordem.";
    if (!["HORARIO", "ANTIHORARIO"].includes($("direcao").value)) return "Selecione uma direção válida.";
    if (movementType() === "passos" && (!Number.isInteger(Number($("passos").value)) || Number($("passos").value) <= 0)) return "A quantidade de passos deve ser um inteiro positivo.";
    if (movementType() === "angulo" && (!Number.isFinite(Number($("angulo").value)) || Number($("angulo").value) <= 0)) return "O ângulo deve ser positivo.";
    if (!Number.isFinite(Number($("velocidade").value)) || Number($("velocidade").value) <= 0) return "A velocidade deve ser positiva.";
    if ($("aceleracao").value && (!Number.isFinite(Number($("aceleracao").value)) || Number($("aceleracao").value) <= 0)) return "A aceleração deve ser positiva ou ficar vazia.";
    if (!Number.isInteger(Number($("tempo_espera_ms").value)) || Number($("tempo_espera_ms").value) < 0) return "O tempo de espera deve ser um inteiro igual ou maior que zero.";
    if (!Number.isInteger(Number($("quantidade_movimentos").value)) || Number($("quantidade_movimentos").value) <= 0) return "A quantidade de movimentos deve ser um inteiro positivo.";
    return "";
  }

  function showFeedback(message, kind = "success") {
    const feedback = $("form-feedback");
    feedback.hidden = false;
    feedback.dataset.kind = kind === "error" ? "error" : "success";
    feedback.textContent = message;
  }

  function renderDrafts() {
    const drafts = readDrafts();
    const target = $("draft-list");
    target.replaceChildren();
    if (!drafts.length) {
      const empty = document.createElement("div");
      empty.className = "draft-empty";
      empty.textContent = "Nenhum rascunho preparado neste navegador.";
      target.append(empty);
      $("export-drafts").disabled = true;
      return;
    }

    $("export-drafts").disabled = false;
    const table = document.createElement("table");
    table.className = "draft-table";
    table.innerHTML = "<thead><tr><th>Ordem</th><th>Peça</th><th>RFID</th><th>Preparado em</th><th>Estado</th><th></th></tr></thead>";
    const body = document.createElement("tbody");
    drafts.forEach((draft) => {
      const row = document.createElement("tr");
      const order = draft.payload?.ordem_producao || {};
      const part = parts.find((item) => Number(item.id) === Number(order.peca_id));
      const cells = [
        order.numero_ordem || "—",
        part ? `${part.codigo} — ${part.nome}` : `ID ${order.peca_id ?? "—"}`,
        String(draft.payload?.rfid_tags?.length || 0),
        draft.preparado_em ? new Date(draft.preparado_em).toLocaleString("pt-BR") : "—"
      ];
      for (const [index, text] of cells.entries()) {
        const cell = document.createElement("td");
        if (index === 0) cell.className = "draft-code";
        cell.textContent = text;
        row.append(cell);
      }
      const stateCell = document.createElement("td");
      const state = document.createElement("span");
      state.className = "draft-state";
      state.textContent = "LOCAL · NÃO ENVIADO";
      stateCell.append(state);
      row.append(stateCell);

      const actionCell = document.createElement("td");
      const remove = document.createElement("button");
      remove.className = "draft-remove";
      remove.type = "button";
      remove.textContent = "Excluir";
      remove.setAttribute("aria-label", `Excluir rascunho ${order.numero_ordem || "sem número"}`);
      remove.addEventListener("click", () => {
        writeDrafts(readDrafts().filter((item) => item.id !== draft.id));
        renderDrafts();
      });
      actionCell.append(remove);
      row.append(actionCell);
      body.append(row);
    });
    table.append(body);
    target.append(table);
  }

  function prepareDraft(event) {
    event.preventDefault();
    if (!form.reportValidity()) return;
    const problem = validateBusinessRules();
    if (problem) {
      showFeedback(problem, "error");
      return;
    }
    const payload = makePayload();
    const drafts = readDrafts();
    drafts.unshift({
      id: window.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`,
      preparado_em: new Date().toISOString(),
      payload
    });
    if (!writeDrafts(drafts)) {
      showFeedback("Não foi possível salvar o rascunho neste navegador. Os dados não foram enviados ao banco.", "error");
      return;
    }
    renderDrafts();
    showFeedback(`Rascunho preparado neste navegador: ${payload.ordem_producao.numero_ordem} · ${selectedPart().nome}. Não foi persistido no banco.`);
  }

  function downloadDrafts() {
    const drafts = readDrafts();
    if (!drafts.length) return;
    const file = new Blob([JSON.stringify(drafts.map((item) => item.payload), null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(file);
    const link = document.createElement("a");
    link.href = url;
    link.download = "rascunhos-ordens-producao.json";
    document.body.append(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  }

  function resetFormState() {
    window.setTimeout(() => {
      rfids = [];
      showRfidError();
      renderRfids();
      updatePartDetails();
      updateMovementFields();
      $("form-feedback").hidden = true;
    }, 0);
  }

  window.addEventListener("DOMContentLoaded", () => {
    initParts();
    renderRfids();
    renderDrafts();
    updateMovementFields();

    form.addEventListener("input", updateSummary);
    form.addEventListener("change", (event) => {
      if (event.target.name === "tipo_movimento") updateMovementFields();
      if (event.target.id === "peca_id") updatePartDetails();
      updateSummary();
    });
    form.addEventListener("submit", prepareDraft);
    form.addEventListener("reset", resetFormState);
    $("add-rfid").addEventListener("click", addRfid);
    $("rfid-uid").addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        addRfid();
      }
    });
    $("rfid-uid").addEventListener("input", () => showRfidError());
    $("export-drafts").addEventListener("click", downloadDrafts);
    updateSummary();
  });
})();
