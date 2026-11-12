from datetime import datetime

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class DeviceStatus(BaseModel):
    model_config = ConfigDict(extra="forbid")
    device_id: str
    status: str
    ultimo_contato: datetime | None = None
    ip_address: str | None = None
    mac_address: str | None = None
    localizacao: str | None = None


class DeviceCommand(BaseModel):
    """Validacao dos parametros cadastrados; nao representa transporte ao firmware atual."""
    model_config = ConfigDict(extra="forbid")
    passos: int | None = Field(default=None, gt=0)
    direcao: Literal["HORARIO", "ANTIHORARIO"]
    velocidade: float = Field(gt=0)
    aceleracao: float | None = Field(default=None, gt=0)
    angulo: float | None = Field(default=None, gt=0)
    tempo_espera_ms: int = Field(default=0, ge=0)
    quantidade_movimentos: int = Field(default=1, gt=0)

    @model_validator(mode="after")
    def require_motion(self):
        if self.passos is None and self.angulo is None:
            raise ValueError("Informe passos ou angulo")
        return self
