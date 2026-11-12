from datetime import datetime

from pydantic import BaseModel, ConfigDict


class PartSummary(BaseModel):
    model_config = ConfigDict(extra="forbid")
    codigo: str
    nome: str
    tamanho: str | None
    cor: str | None
    material: str | None = None
    peso: float | None = None


class QuantitySummary(BaseModel):
    model_config = ConfigDict(extra="forbid")
    planejada: int
    produzida: int


class OrderResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")
    numero: str
    status: str
    data_previsao: datetime | None = None
    peca: PartSummary
    quantidade: QuantitySummary
