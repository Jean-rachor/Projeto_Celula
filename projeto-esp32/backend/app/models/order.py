from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Identity, Integer, SmallInteger, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class ProductionOrder(Base):
    __tablename__ = "ordens_producao"
    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    numero_ordem: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    peca_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("pecas.id"), nullable=False)
    quantidade_planejada: Mapped[int] = mapped_column(Integer, nullable=False)
    quantidade_produzida: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="PENDENTE")
    prioridade: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=3)
    data_inicio: Mapped[datetime | None] = mapped_column(DateTime)
    data_previsao: Mapped[datetime | None] = mapped_column(DateTime)
    observacao: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now(), onupdate=func.now())
