from sqlalchemy import case, select
from sqlalchemy.orm import Session

from app.models import Execution, MotorParameters, Part, ProductionOrder, RFIDTag


def get_rfid_bundle(db: Session, uid_hex: str) -> tuple[RFIDTag, Part, ProductionOrder | None, MotorParameters | None] | None:
    statement = (
        select(RFIDTag, Part, ProductionOrder, MotorParameters)
        .join(Part, Part.id == RFIDTag.peca_id)
        .outerjoin(
            ProductionOrder,
            (ProductionOrder.peca_id == Part.id)
            & ProductionOrder.status.in_(("EM_EXECUCAO", "PENDENTE")),
        )
        .outerjoin(MotorParameters, (MotorParameters.ordem_producao_id == ProductionOrder.id) & MotorParameters.ativo.is_(True))
        .where(RFIDTag.uid_hex == uid_hex, RFIDTag.ativo.is_(True), Part.ativo.is_(True))
        .order_by(
            case((ProductionOrder.status == "EM_EXECUCAO", 0), (ProductionOrder.status == "PENDENTE", 1), else_=2),
            ProductionOrder.prioridade,
            ProductionOrder.created_at.desc(),
        )
        .limit(1)
    )
    row = db.execute(statement).first()
    return tuple(row) if row else None


def get_order_bundle(db: Session, numero_ordem: str) -> tuple[ProductionOrder, Part] | None:
    row = db.execute(
        select(ProductionOrder, Part)
        .join(Part, Part.id == ProductionOrder.peca_id)
        .where(ProductionOrder.numero_ordem == numero_ordem)
    ).first()
    return tuple(row) if row else None


def get_latest_execution(db: Session, order_id: int, device_id: int) -> Execution | None:
    statement = (
        select(Execution)
        .where(Execution.ordem_producao_id == order_id, Execution.dispositivo_id == device_id)
        .order_by(Execution.inicio.desc(), Execution.id.desc())
        .limit(1)
    )
    return db.scalar(statement)


def part_payload(part: Part) -> dict:
    return {
        "codigo": part.codigo,
        "nome": part.nome,
        "tamanho": part.tamanho,
        "cor": part.cor,
        "material": part.material,
        "peso": float(part.peso) if part.peso is not None else None,
    }


def motor_payload(motor: MotorParameters | None) -> dict | None:
    if motor is None:
        return None
    return {
        "passos": motor.passos,
        "direcao": motor.direcao,
        "velocidade": float(motor.velocidade),
        "aceleracao": float(motor.aceleracao) if motor.aceleracao is not None else None,
        "angulo": float(motor.angulo) if motor.angulo is not None else None,
        "tempo_espera_ms": motor.tempo_espera_ms,
        "quantidade_movimentos": motor.quantidade_movimentos,
    }
