from fastapi import FastAPI
from app.core.config import settings
from app.routers import auth, tracks, runs

app = FastAPI(title=settings.PROJECT_NAME, openapi_url=f"{settings.API_V1_STR}/openapi.json")

app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(tracks.router, prefix=f"{settings.API_V1_STR}/tracks", tags=["tracks"])
app.include_router(runs.router, prefix=f"{settings.API_V1_STR}/runs", tags=["runs"])

@app.get("/")
def read_root():
    return {"message": "Welcome to PulseTempo API"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}
