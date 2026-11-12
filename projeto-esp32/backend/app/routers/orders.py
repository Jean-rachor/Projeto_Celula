from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.order import OrderResponse, PartSummary, QuantitySummary
from app.services.processo_service import get_order_bundle, part_payload

router = APIRouter(prefix="/api/ordens", tags=["Ordens"])


@router.get("/{numero_ordem}", response_model=OrderResponse, summary="Consulta uma ordem de producao")
def get_order(numero_ordem: str, db: Session = Depends(get_db)) -> dict:
    bundle = get_order_bundle(db, numero_ordem)
    if bundle is None:
        raise HTTPException(status_code=404, detail="Ordem de producao nao encontrada")
    order, part = bundle
    return {
        "numero": order.numero_ordem,
        "status": order.status,
        "data_previsao": order.data_previsao,
        "peca": part_payload(part),
        "quantidade": {
            "planejada": order.quantidade_planejada,
            "produzida": order.quantidade_produzida,
        },
    }
