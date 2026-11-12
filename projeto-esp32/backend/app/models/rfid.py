from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Identity, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class RFIDTag(Base):
    __tablename__ = "rfid_tags"
    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    uid_hex: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    descricao: Mapped[str | None] = mapped_column(Text)
    ativo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    peca_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("pecas.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())
