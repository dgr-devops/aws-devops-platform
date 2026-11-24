from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="APP_")

    database_url: str = "sqlite:///./local.db"


def get_settings() -> Settings:
    return Settings()
