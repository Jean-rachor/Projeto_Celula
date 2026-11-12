from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import get_db
from app.models import Device
from app.schemas.device import DeviceStatus

router = APIRouter(prefix="/api/dispositivos", tags=["ESP32"])


@router.get("/{device_id}", response_model=DeviceStatus, summary="Consulta o status de um ESP32")
def get_device(device_id: str, db: Session = Depends(get_db)) -> DeviceStatus:
    device = db.scalar(select(Device).where(Device.device_id == device_id))
    if device is None:
        raise HTTPException(status_code=404, detail="Dispositivo nao cadastrado")
    online = bool(
        device.ultimo_contato
        and device.ultimo_status == "ONLINE"
        and datetime.now() - device.ultimo_contato <= timedelta(seconds=get_settings().device_online_timeout_seconds)
    )
    return DeviceStatus(
        device_id=device.device_id,
        status="ONLINE" if online else (device.ultimo_status or "OFFLINE"),
        ultimo_contato=device.ultimo_contato,
        ip_address=str(device.ip_address) if device.ip_address else None,
        mac_address=device.mac_address,
        localizacao=device.localizacao,
    )
