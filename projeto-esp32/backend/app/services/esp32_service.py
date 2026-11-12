import logging
from datetime import datetime
from threading import Lock

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Device, Execution
from app.schemas.process import DeviceTelemetry
from app.services.processo_service import get_rfid_bundle

_lock = Lock()
_latest_by_device: dict[str, dict] = {}
logger = logging.getLogger(__name__)
_EXECUTION_STATUS = {
    "AGUARDANDO": "AGUARDANDO",
    "PENDENTE": "AGUARDANDO",
    "EM_EXECUCAO": "EXECUTANDO",
    "EXECUTANDO": "EXECUTANDO",
    "CONCLUIDA": "CONCLUIDA",
    "CONCLUIDO": "CONCLUIDA",
    "ERRO": "ERRO",
    "CANCELADA": "CANCELADA",
}


def record_telemetry(db: Session, telemetry: DeviceTelemetry) -> dict:
    device = db.scalar(select(Device).where(Device.device_id == telemetry.device_id, Device.ativo.is_(True)))
    if device is None:
        raise LookupError("Dispositivo nao cadastrado")

    now = datetime.now()
    device.ultimo_status = telemetry.status
    device.ultimo_contato = now

    bundle = get_rfid_bundle(db, telemetry.rfid_uid_hex) if telemetry.rfid_uid_hex else None
    if bundle:
        _, _, order, _ = bundle
        incoming_status = telemetry.process_status or telemetry.motor_status or telemetry.servo_status
        execution_status = _EXECUTION_STATUS.get((incoming_status or "").upper())
        if order is not None and execution_status is not None:
            latest_execution = db.scalar(
                select(Execution)
                .where(
                    Execution.ordem_producao_id == order.id,
                    Execution.dispositivo_id == device.id,
                )
                .order_by(Execution.inicio.desc(), Execution.id.desc())
                .limit(1)
                .with_for_update()
            )
            terminal_statuses = {"CONCLUIDA", "ERRO", "CANCELADA"}
            starts_new_cycle = (
                latest_execution is not None
                and latest_execution.status in terminal_statuses
                and execution_status not in terminal_statuses
            )
            if latest_execution is None or starts_new_cycle:
                # Só criamos um ciclo quando o ESP enviou contadores reais.
                if telemetry.passos_executados is not None and telemetry.movimento_atual is not None:
                    db.add(Execution(
                        ordem_producao_id=order.id,
                        dispositivo_id=device.id,
                        status=execution_status,
                        passos_executados=telemetry.passos_executados,
                        movimentos_executados=telemetry.movimento_atual,
                        fim=now if execution_status in terminal_statuses else None,
                    ))
            else:
                latest_execution.status = execution_status
                if telemetry.passos_executados is not None:
                    latest_execution.passos_executados = telemetry.passos_executados
                if telemetry.movimento_atual is not None:
                    latest_execution.movimentos_executados = telemetry.movimento_atual
                latest_execution.fim = now if execution_status in terminal_statuses else None

    db.commit()

    snapshot = {
        "device_id": telemetry.device_id,
        "status": telemetry.status,
        "processo": telemetry.process_snapshot().model_dump(),
        "rfid_uid_hex": telemetry.rfid_uid_hex,
        "updated_at": now,
    }
    with _lock:
        _latest_by_device[telemetry.device_id] = snapshot
    logger.info("Telemetria recebida do dispositivo %s", telemetry.device_id)
    return snapshot


def latest_telemetry() -> dict | None:
    with _lock:
        if not _latest_by_device:
            return None
        return max(_latest_by_device.values(), key=lambda report: report["updated_at"])


def telemetry_for(device_id: str) -> dict | None:
    with _lock:
        return _latest_by_device.get(device_id)
import logging
