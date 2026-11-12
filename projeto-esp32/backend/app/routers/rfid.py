import logging

from fastapi import APIRouter, Depends, HTTPException, Path
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.rfid import RFIDIdentity, RFIDResponse
from app.services.processo_service import get_rfid_bundle, motor_payload, part_payload

router = APIRouter(prefix="/api/rfid", tags=["RFID"])
logger = logging.getLogger(__name__)


@router.get("/{uid_hex}", response_model=RFIDResponse, summary="Consulta uma tag e seus dados de producao")
def identify_rfid(
    uid_hex: str = Path(min_length=2, max_length=32),
    db: Session = Depends(get_db),
) -> dict:
    identity = RFIDIdentity(uid_hex=uid_hex)
    bundle = get_rfid_bundle(db, identity.uid_hex)
    if bundle is None:
        logger.info("RFID nao localizado ou sem peca ativa: %s", identity.uid_hex)
        raise HTTPException(status_code=404, detail="RFID nao cadastrado ou sem peca ativa")
    tag, part, order, motor = bundle
    order_data = None
    if order:
        logger.info("RFID %s associado a ordem %s", tag.uid_hex, order.numero_ordem)
        order_data = {
            "numero": order.numero_ordem,
            "status": order.status,
            "quantidade_planejada": order.quantidade_planejada,
            "quantidade_produzida": order.quantidade_produzida,
            "data_previsao": order.data_previsao,
        }
    return {
        "rfid": {"uid_hex": tag.uid_hex},
        "peca": part_payload(part),
        "ordem_producao": order_data,
        "motor": motor_payload(motor),
    }
import logging
