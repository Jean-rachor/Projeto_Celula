/* API FastAPI: ajuste apiBaseUrl quando frontend e backend forem hospedados
   em enderecos diferentes. */
const API_CONFIG = Object.freeze({
  apiBaseUrl: window.API_BASE_URL || `${window.location.protocol}//${window.location.hostname}:8080`,
  supervisionUrl: "/api/supervisao",
  pollingIntervalMs: 1500,
  timeoutMs: 5000
});

async function fetchSupervision() {
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), API_CONFIG.timeoutMs);

  try {
    const response = await fetch(`${API_CONFIG.apiBaseUrl}${API_CONFIG.supervisionUrl}`, {
      method: "GET",
      headers: { Accept: "application/json" },
      cache: "no-store",
      signal: controller.signal
    });

    if (!response.ok) {
      const error = new Error(`Resposta HTTP ${response.status}`);
      error.status = response.status;
      throw error;
    }
    if (response.status === 204) return null;

    try {
      const payload = await response.json();
      validateSupervision(payload);
      return payload;
    } catch (cause) {
      const error = new Error("Resposta JSON inválida");
      error.cause = cause;
      throw error;
    }
  } finally {
    window.clearTimeout(timeout);
  }
}

function validateSupervision(payload) {
  if (payload === null) return;
  if (typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("Resposta de supervisão inválida");
  }

  for (const key of ["rfid", "peca", "ordem_producao", "motor", "processo", "execucao", "dispositivo"]) {
    const value = payload[key];
    if (value !== undefined && value !== null && (typeof value !== "object" || Array.isArray(value))) {
      throw new Error(`Campo inválido na resposta: ${key}`);
    }
  }
}
