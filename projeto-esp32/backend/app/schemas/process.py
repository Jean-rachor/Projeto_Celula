from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.rfid import RFIDIdentity


class ProcessSnapshot(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: str | None = None
    motor_status: str | None = None
    posicao: float | None = None
    movimento_atual: int | None = Field(default=None, ge=0)
    total_movimentos: int | None = Field(default=None, ge=0)
    passos_executados: int | None = Field(default=None, ge=0)
    temperatura: float | None = None


class DeviceTelemetry(BaseModel):
    """Contrato HTTP de telemetria proposto para uma futura versao do firmware."""
    model_config = ConfigDict(extra="forbid")
    device_id: str = Field(min_length=1, max_length=80)
    status: Literal["ONLINE", "OFFLINE", "ERRO"] = "ONLINE"
    process_status: str | None = Field(default=None, max_length=30)
    motor_status: str | None = Field(default=None, max_length=40)
    servo_status: str | None = Field(default=None, max_length=40)
    posicao: float | None = Field(default=None, ge=0, le=180)
    movimento_atual: int | None = Field(default=None, ge=0)
    total_movimentos: int | None = Field(default=None, ge=0)
    temperatura: float | None = None
    passos_executados: int | None = Field(default=None, ge=0)
    rfid_uid_hex: str | None = None

    @field_validator("rfid_uid_hex")
    @classmethod
    def validate_rfid_uid(cls, value: str | None) -> str | None:
        return RFIDIdentity(uid_hex=value).uid_hex if value is not None else None

    def process_snapshot(self) -> ProcessSnapshot:
        return ProcessSnapshot(
            status=self.process_status,
            motor_status=self.motor_status or self.servo_status,
            posicao=self.posicao,
            movimento_atual=self.movimento_atual,
            total_movimentos=self.total_movimentos,
            passos_executados=self.passos_executados,
            temperatura=self.temperatura,
        )

    def rfid_identity(self) -> RFIDIdentity | None:
        return RFIDIdentity(uid_hex=self.rfid_uid_hex) if self.rfid_uid_hex else None
