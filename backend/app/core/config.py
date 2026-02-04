import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "PulseTempo Backend"
    API_V1_STR: str = "/api"

    # Database
    POSTGRES_SERVER: str = os.getenv("POSTGRES_SERVER", "localhost")
    POSTGRES_USER: str = os.getenv("POSTGRES_USER", "postgres")
    POSTGRES_PASSWORD: str = os.getenv("POSTGRES_PASSWORD", "postgres")
    POSTGRES_DB: str = os.getenv("POSTGRES_DB", "pulsetempo")
    POSTGRES_PORT: str = os.getenv("POSTGRES_PORT", "5432")

    # Security
    SECRET_KEY: str = os.getenv(
        "SECRET_KEY", "dev_secret_key_change_in_production")

    # Direct DATABASE_URL (Railway provides this)
    DATABASE_URL: str = os.getenv("DATABASE_URL", "")

    # Construct DATABASE_URL
    # Prefer DATABASE_URL if set, otherwise build from components
    @property
    def SQLALCHEMY_DATABASE_URI(self) -> str:
        if self.DATABASE_URL:
            return self.DATABASE_URL
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    class Config:
        case_sensitive = True


settings = Settings()
