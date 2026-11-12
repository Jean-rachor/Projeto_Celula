from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import probe_database
from app.routers import devices, health, orders, process, rfid

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("esp32_api")


@asynccontextmanager
async def lifespan(_: FastAPI):
    if probe_database():
        logger.info("Conexao com PostgreSQL validada")
    else:
        logger.warning("PostgreSQL indisponivel ou DATABASE_URL ausente; endpoints de banco retornarao 503")
    yield


app = FastAPI(
    title="API de Controle e Supervisao ESP32",
    description="API entre PostgreSQL, dispositivos ESP32 e interface de supervisao.",
    version="1.0.0",
    lifespan=lifespan,
)
settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Accept"],
)

for router in (health.router, rfid.router, orders.router, process.router, devices.router):
    app.include_router(router)
