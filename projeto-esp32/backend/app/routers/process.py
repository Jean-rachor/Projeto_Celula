from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import get_db
from app.models import Device
from app.schemas.process import DeviceTelemetry
from app.services.esp32_service import latest_telemetry, record_telemetry
from app.services.processo_service import get_latest_execution, get_rfid_bundle, motor_payload, part_payload

router = APIRouter(prefix="/api", tags=["Processo", "Supervisao"])


@router.get("/supervisao", summary="Dados consolidados para a tela operacional")
def supervision(db: Session = Depends(get_db)) -> dict:
    report = latest_telemetry()
    uid_hex = report.get("rfid_uid_hex") if report else None
    device_id = report.get("device_id") if report else None
    process = report.get("processo") if report else None
    bundle = get_rfid_bundle(db, uid_hex) if uid_hex else None

    tag = part = order = motor = None
    if bundle:
        tag, part, order, motor = bundle

    device = db.query(Device).filter(Device.device_id == device_id).first() if device_id else None
    if device is None:
        device = db.query(Device).order_by(Device.ultimo_contato.desc().nullslast()).first()
    online = bool(
        device
        and device.ultimo_status == "ONLINE"
        and device.ultimo_contato
        and datetime.now() - device.ultimo_contato
        <= timedelta(seconds=get_settings().device_online_timeout_seconds)
    )
    device_status = ("ONLINE" if online else "OFFLINE") if device else None
    execution = get_latest_execution(db, order.id, device.id) if order and device else None

    order_data = None
    if order:
        order_data = {
            "numero": order.numero_ordem,
            "status": order.status,
            "quantidade_planejada": order.quantidade_planejada,
            "quantidade_produzida": order.quantidade_produzida,
            "data_previsao": order.data_previsao,
        }

    return {
        "rfid": {"uid_hex": tag.uid_hex if tag else uid_hex} if (tag or uid_hex) else None,
        "rfid_status": "IDENTIFICADO" if tag else ("NAO_CADASTRADO" if uid_hex else "AGUARDANDO"),
        "peca": part_payload(part) if part else None,
        "ordem_producao": order_data,
        "processo": process,
        "dispositivo": {
            "device_id": device.device_id,
            "ultimo_status": device_status,
            "ultimo_contato": device.ultimo_contato,
            "ip_address": str(device.ip_address) if device.ip_address else None,
            "mac_address": device.mac_address,
            "localizacao": device.localizacao,
        } if device else None,
        "execucao": {
            "status": execution.status,
            "passos_executados": execution.passos_executados,
            "movimentos_executados": execution.movimentos_executados,
            "inicio": execution.inicio,
            "fim": execution.fim,
        } if execution else None,
        # Mantem os parametros sob esta chave para futuras chamadas HTTP do ESP32.
        "motor": motor_payload(motor),
    }


@router.get("/esp32/{device_id}/config", summary="Le parametros da ordem para um dispositivo")
def get_device_config(
    device_id: str,
    uid_hex: str = Query(min_length=2, max_length=32),
    db: Session = Depends(get_db),
) -> dict:
    device = db.query(Device).filter(Device.device_id == device_id, Device.ativo.is_(True)).first()
    if device is None:
        raise HTTPException(status_code=404, detail="Dispositivo nao cadastrado")
    bundle = get_rfid_bundle(db, uid_hex)
    if bundle is None:
        raise HTTPException(status_code=404, detail="RFID nao cadastrado ou sem peca ativa")
    tag, part, order, motor = bundle
    if order is None or motor is None:
        raise HTTPException(status_code=404, detail="Ordem ativa ou parametros do motor nao encontrados")
    return {
        "device_id": device.device_id,
        "rfid": {"uid_hex": tag.uid_hex},
        "numero_ordem": order.numero_ordem,
        "parametros_motor": motor_payload(motor),
    }


@router.post("/esp32/telemetria", status_code=202, summary="Recebe telemetria HTTP de um ESP32")
def receive_telemetry(telemetry: DeviceTelemetry, db: Session = Depends(get_db)) -> dict:
    try:
        report = record_telemetry(db, telemetry)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return {"accepted": True, "device_id": report["device_id"], "received_at": report["updated_at"]}
