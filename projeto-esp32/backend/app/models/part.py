from datetime import datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Boolean, DateTime, Identity, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Part(Base):
    __tablename__ = "pecas"
    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    codigo: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    nome: Mapped[str] = mapped_column(String(150), nullable=False)
    descricao: Mapped[str | None] = mapped_column(Text)
    tamanho: Mapped[str | None] = mapped_column(String(80))
    cor: Mapped[str | None] = mapped_column(String(80))
    material: Mapped[str | None] = mapped_column(String(100))
    peso: Mapped[Decimal | None] = mapped_column(Numeric(10, 3))
    ativo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())
