from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, Identity, String, func
from sqlalchemy.dialects.postgresql import INET
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Device(Base):
    __tablename__ = "dispositivos"
    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    device_id: Mapped[str] = mapped_column(String(80), unique=True, nullable=False)
    nome: Mapped[str] = mapped_column(String(120), nullable=False)
    mac_address: Mapped[str | None] = mapped_column(String(17))
    ip_address: Mapped[str | None] = mapped_column(INET)
    localizacao: Mapped[str | None] = mapped_column(String(150))
    ativo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    ultimo_status: Mapped[str | None] = mapped_column(String(20))
    ultimo_contato: Mapped[datetime | None] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())
