from datetime import datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Identity, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class MotorParameters(Base):
    __tablename__ = "parametros_motor"
    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    ordem_producao_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("ordens_producao.id"), nullable=False)
    passos: Mapped[int | None] = mapped_column(Integer)
    direcao: Mapped[str] = mapped_column(String(15), nullable=False)
    velocidade: Mapped[Decimal] = mapped_column(Numeric(10, 3), nullable=False)
    aceleracao: Mapped[Decimal | None] = mapped_column(Numeric(10, 3))
    angulo: Mapped[Decimal | None] = mapped_column(Numeric(9, 3))
    tempo_espera_ms: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    quantidade_movimentos: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    ativo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now(), onupdate=func.now())
