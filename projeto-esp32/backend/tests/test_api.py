from datetime import datetime, timedelta
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.database import get_db
from app.main import app
from app.schemas.device import DeviceCommand
from app.schemas.process import DeviceTelemetry
from app.services.esp32_service import record_telemetry


class EmptyQuery:
    def filter(self, *_args, **_kwargs):
        return self

    def order_by(self, *_args, **_kwargs):
        return self

    def first(self):
        return None


class EmptySession:
    def query(self, *_args, **_kwargs):
        return EmptyQuery()


def override_db():
    yield EmptySession()


app.dependency_overrides[get_db] = override_db


def test_health_connected(monkeypatch):
    monkeypatch.setattr("app.routers.health.probe_database", lambda: True)
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "connected"}


def test_health_database_unavailable(monkeypatch):
    monkeypatch.setattr("app.routers.health.probe_database", lambda: False)
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.status_code == 503


def test_cors_allows_local_hmi_origin():
    with TestClient(app) as client:
        response = client.options(
            "/api/supervisao",
            headers={
                "Origin": "http://localhost:5500",
                "Access-Control-Request-Method": "GET",
            },
        )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5500"


def test_rfid_not_found(monkeypatch):
    monkeypatch.setattr("app.routers.rfid.get_rfid_bundle", lambda *_args: None)
    with TestClient(app) as client:
        response = client.get("/api/rfid/DEADBEEF")
    assert response.status_code == 404
    assert response.json()["detail"] == "RFID nao cadastrado ou sem peca ativa"


def test_rfid_response_uses_postgres_model_fields(monkeypatch):
    tag = SimpleNamespace(uid_hex="A1B2C3D4")
    part = SimpleNamespace(codigo="PEC-001", nome="Carcaca", tamanho="Medio", cor="Azul", material="Aluminio", peso=2.5)
    order = SimpleNamespace(numero_ordem="OP-1", status="PENDENTE", quantidade_planejada=10, quantidade_produzida=0, data_previsao=None)
    motor = SimpleNamespace(
        passos=200, direcao="HORARIO", velocidade=500, aceleracao=100,
        angulo=None, tempo_espera_ms=500, quantidade_movimentos=2,
    )
    monkeypatch.setattr("app.routers.rfid.get_rfid_bundle", lambda *_args: (tag, part, order, motor))
    with TestClient(app) as client:
        response = client.get("/api/rfid/A1B2C3D4")
    assert response.status_code == 200
    payload = response.json()
    assert payload["rfid"]["uid_hex"] == "A1B2C3D4"
    assert payload["ordem_producao"]["numero"] == "OP-1"
    assert payload["motor"]["passos"] == 200


def test_order_not_found(monkeypatch):
    monkeypatch.setattr("app.routers.orders.get_order_bundle", lambda *_args: None)
    with TestClient(app) as client:
        response = client.get("/api/ordens/OP-NAO-EXISTE")
    assert response.status_code == 404


def test_order_response(monkeypatch):
    order = SimpleNamespace(numero_ordem="OP-1", status="PENDENTE", quantidade_planejada=10, quantidade_produzida=2, data_previsao=None)
    part = SimpleNamespace(codigo="PEC-1", nome="Suporte", tamanho="Pequeno", cor="Preto", material=None, peso=None)
    monkeypatch.setattr("app.routers.orders.get_order_bundle", lambda *_args: (order, part))
    with TestClient(app) as client:
        response = client.get("/api/ordens/OP-1")
    assert response.status_code == 200
    assert response.json()["quantidade"] == {"planejada": 10, "produzida": 2}


def test_supervision_empty_payload(monkeypatch):
    monkeypatch.setattr("app.routers.process.latest_telemetry", lambda: None)
    with TestClient(app) as client:
        response = client.get("/api/supervisao")
    assert response.status_code == 200
    assert response.json()["rfid"] is None
    assert response.json()["ordem_producao"] is None


def test_supervision_combines_telemetry_database_order_motor_and_execution(monkeypatch):
    tag = SimpleNamespace(uid_hex="A1B2C3D4")
    part = SimpleNamespace(codigo="PEC-001", nome="Carcaca W22", tamanho="Medio", cor="Azul", material="Aluminio", peso=2.5)
    order = SimpleNamespace(
        id=21, numero_ordem="OP-2026-00125", status="EM_EXECUCAO",
        quantidade_planejada=100, quantidade_produzida=45,
        data_previsao=datetime(2026, 10, 7),
    )
    motor = SimpleNamespace(
        passos=200, direcao="HORARIO", velocidade=500, aceleracao=100,
        angulo=None, tempo_espera_ms=500, quantidade_movimentos=2,
    )
    device = SimpleNamespace(
        id=31, device_id="ESP32-001", ultimo_status="ONLINE",
        ultimo_contato=datetime.now(), ip_address=None, mac_address=None, localizacao="Bancada",
    )
    execution = SimpleNamespace(
        status="EXECUTANDO", passos_executados=200, movimentos_executados=1,
        inicio=datetime.now() - timedelta(minutes=1), fim=None,
    )

    class DeviceQuery:
        def filter(self, *_args, **_kwargs):
            return self

        def order_by(self, *_args, **_kwargs):
            return self

        def first(self):
            return device

    class Session:
        def query(self, *_args, **_kwargs):
            return DeviceQuery()

    def override_test_db():
        yield Session()

    monkeypatch.setattr(
        "app.routers.process.latest_telemetry",
        lambda: {
            "device_id": "ESP32-001", "rfid_uid_hex": "A1B2C3D4",
            "processo": {"status": "EM_EXECUCAO", "motor_status": "EXECUTANDO", "passos_executados": 200},
        },
    )
    monkeypatch.setattr("app.routers.process.get_rfid_bundle", lambda *_args: (tag, part, order, motor))
    monkeypatch.setattr("app.routers.process.get_latest_execution", lambda *_args: execution)
    app.dependency_overrides[get_db] = override_test_db
    try:
        with TestClient(app) as client:
            response = client.get("/api/supervisao")
    finally:
        app.dependency_overrides[get_db] = override_db

    assert response.status_code == 200
    payload = response.json()
    assert payload["rfid_status"] == "IDENTIFICADO"
    assert payload["peca"]["material"] == "Aluminio"
    assert payload["peca"]["peso"] == 2.5
    assert payload["ordem_producao"]["data_previsao"] == "2026-10-07T00:00:00"
    assert payload["motor"]["passos"] == 200
    assert payload["execucao"]["passos_executados"] == 200
    assert payload["dispositivo"]["localizacao"] == "Bancada"


def test_telemetry_validation_rejects_invalid_uid_and_position():
    with TestClient(app) as client:
        bad_uid = client.post("/api/esp32/telemetria", json={"device_id": "ESP32-001", "rfid_uid_hex": "not-hex"})
        bad_position = client.post("/api/esp32/telemetria", json={"device_id": "ESP32-001", "posicao": 181})
    assert bad_uid.status_code == 422
    assert bad_position.status_code == 422


def test_telemetry_rejects_unknown_device(monkeypatch):
    def unknown_device(*_args):
        raise LookupError("Dispositivo nao cadastrado")

    monkeypatch.setattr("app.routers.process.record_telemetry", unknown_device)
    with TestClient(app) as client:
        response = client.post("/api/esp32/telemetria", json={"device_id": "ESP32-404"})
    assert response.status_code == 404


def test_motor_command_validation():
    valid = DeviceCommand(passos=200, direcao="HORARIO", velocidade=500, quantidade_movimentos=2)
    assert valid.passos == 200
    try:
        DeviceCommand(passos=0, direcao="LATERAL", velocidade=-1)
    except Exception:
        pass
    else:
        raise AssertionError("Os parametros invalidos deveriam ser rejeitados")


def test_telemetry_persists_execution_counters(monkeypatch):
    device = SimpleNamespace(id=7, device_id="ESP32-TEST", ativo=True, ultimo_status=None, ultimo_contato=None)
    order = SimpleNamespace(id=12)
    added = []

    class Session:
        calls = 0

        def scalar(self, _statement):
            self.calls += 1
            return device if self.calls == 1 else None

        def add(self, instance):
            added.append(instance)

        def commit(self):
            pass

    monkeypatch.setattr(
        "app.services.esp32_service.get_rfid_bundle",
        lambda *_args: (SimpleNamespace(uid_hex="A1B2C3D4"), None, order, None),
    )
    report = record_telemetry(
        Session(),
        DeviceTelemetry(
            device_id="ESP32-TEST",
            rfid_uid_hex="A1B2C3D4",
            process_status="EM_EXECUCAO",
            movimento_atual=1,
            total_movimentos=2,
            passos_executados=200,
        ),
    )
    assert device.ultimo_status == "ONLINE"
    assert report["processo"]["passos_executados"] == 200
    assert len(added) == 1
    assert added[0].status == "EXECUTANDO"
    assert added[0].passos_executados == 200
    assert added[0].movimentos_executados == 1


def test_telemetry_without_counters_does_not_create_fake_execution(monkeypatch):
    device = SimpleNamespace(id=8, device_id="ESP32-TEST-2", ativo=True, ultimo_status=None, ultimo_contato=None)
    order = SimpleNamespace(id=13)
    added = []

    class Session:
        calls = 0

        def scalar(self, _statement):
            self.calls += 1
            return device if self.calls == 1 else None

        def add(self, instance):
            added.append(instance)

        def commit(self):
            pass

    monkeypatch.setattr(
        "app.services.esp32_service.get_rfid_bundle",
        lambda *_args: (SimpleNamespace(uid_hex="A1B2C3D4"), None, order, None),
    )
    record_telemetry(
        Session(),
        DeviceTelemetry(device_id="ESP32-TEST-2", rfid_uid_hex="A1B2C3D4", process_status="EM_EXECUCAO"),
    )
    assert added == []
