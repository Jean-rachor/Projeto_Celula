from collections.abc import Generator
from functools import lru_cache
import logging

from fastapi import HTTPException
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker

from app.config import get_settings

logger = logging.getLogger(__name__)


@lru_cache
def get_engine() -> Engine:
    url = get_settings().database_url
    if not url:
        raise RuntimeError("DATABASE_URL nao configurada")
    return create_engine(url, pool_pre_ping=True, pool_size=5, max_overflow=10)


@lru_cache
def get_session_factory() -> sessionmaker[Session]:
    return sessionmaker(bind=get_engine(), autoflush=False, expire_on_commit=False)


def get_db() -> Generator[Session, None, None]:
    try:
        session = get_session_factory()()
    except Exception as exc:
        logger.exception("Falha ao criar sessao PostgreSQL")
        raise HTTPException(status_code=503, detail="Banco de dados indisponivel") from exc
    try:
        yield session
    except SQLAlchemyError as exc:
        session.rollback()
        logger.exception("Erro de banco durante requisicao")
        raise HTTPException(status_code=503, detail="Banco de dados indisponivel") from exc
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def probe_database() -> bool:
    try:
        with get_engine().connect() as connection:
            connection.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
