import re

from pydantic import BaseModel, ConfigDict, field_validator


class RFIDIdentity(BaseModel):
    uid_hex: str

    @field_validator("uid_hex")
    @classmethod
    def validate_uid(cls, value: str) -> str:
        if not re.fullmatch(r"[0-9A-Fa-f]{2}(?::?[0-9A-Fa-f]{2})*", value):
            raise ValueError("UID deve conter bytes hexadecimais, opcionalmente separados por ':'")
        return value


class RFIDResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")
    rfid: dict
    peca: dict
    ordem_producao: dict | None
    motor: dict | None
