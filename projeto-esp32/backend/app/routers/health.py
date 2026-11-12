from fastapi import APIRouter, HTTPException

from app.database import probe_database

router = APIRouter(tags=["Health"])


@router.get("/health", summary="Verifica a API e a conexao PostgreSQL")
def health() -> dict[str, str]:
    if not probe_database():
        raise HTTPException(status_code=503, detail="Banco de dados indisponivel")
    return {"status": "ok", "database": "connected"}
