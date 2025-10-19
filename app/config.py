from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    AGENT_TOKEN: str = "change-me-in-production"
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    DOCKER_SOCKET: str = "unix://var/run/docker.sock"
    LOG_LEVEL: str = "INFO"
    PROJECT_NAME: str = "ServerBond Agent"
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


settings = Settings()

