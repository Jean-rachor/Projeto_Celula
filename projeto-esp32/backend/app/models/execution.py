from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Identity, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Execution(Base):
    __tablename__ = "execucoes_producao"
    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    ordem_producao_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("ordens_producao.id"), nullable=False)
    dispositivo_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("dispositivos.id"), nullable=False)
    inicio: Mapped[datetime] = mapped_column(DateTime, nullable=False, server_default=func.now())
    fim: Mapped[datetime | None] = mapped_column(DateTime)
    status: Mapped[str] = mapped_column(String(15), nullable=False, default="AGUARDANDO")
    passos_executados: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    movimentos_executados: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    observacao: Mapped[str | None] = mapped_column(Text)
