# ServerBond Agent 🚀

Python agent for Docker container management and site deployment.

## Features

✅ **Deploy Management**
- Create and deploy sites with Docker containers
- Support for any Docker image
- Custom environment variables and volumes
- Port mapping and container labels

✅ **Container Operations**
- Full Docker container lifecycle management
- Container creation, start, stop, restart, remove
- Execute commands inside containers (docker exec)
- Container logs and real-time statistics

✅ **System Monitoring**
- CPU, RAM, Disk usage
- Network statistics
- Real-time system information
- Health check endpoint

✅ **Security**
- Token-based authentication
- Secure API endpoints

## Installation

### Automatic Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/serverbond/agent/main/install.sh | sudo bash
```

### Manual Installation

#### 1. Install Requirements

```bash
# Docker
curl -fsSL https://get.docker.com | sh

# Python 3.11+
sudo apt-get update
sudo apt-get install python3.11 python3-pip
```

#### 2. Clone Project

```bash
git clone https://github.com/serverbond/agent.git
cd serverbond-agent
```

#### 3. Install Python Dependencies

```bash
pip install -r requirements.txt
```

#### 4. Configuration

Copy `.env.example` to `.env` and edit:

```bash
cp .env.example .env
nano .env
```

Set required values:
```env
AGENT_TOKEN=your-secure-token-here
API_HOST=0.0.0.0
API_PORT=8000
LOG_LEVEL=INFO
```

#### 5. Run

```bash
# Direct Python execution
python3.11 -m uvicorn app.main:app --host 0.0.0.0 --port 8000

# Or with Docker Compose
docker-compose up -d
```

## API Documentation

After starting the agent, you can access:

- **Swagger UI**: `http://your-server:8000/docs`
- **ReDoc**: `http://your-server:8000/redoc`
- **OpenAPI JSON**: `http://your-server:8000/openapi.json`
- **Health Check**: `http://your-server:8000/system/health`

### Export OpenAPI Specification

```bash
# Export to JSON and YAML files
python3 export_openapi.py

# Files will be created:
# - openapi.json
# - openapi.yaml
```

You can import these files to:
- Postman
- Insomnia
- Swagger Editor
- Any OpenAPI-compatible tool

## Usage Examples

### 1. Deploy a Site

```bash
curl -X POST "http://your-server:8000/deploy/create" \
  -H "x-token: your-token-here" \
  -H "Content-Type: application/json" \
  -d '{
    "site_name": "mysite",
    "image": "nginx:alpine",
    "domain": "mysite.com",
    "port": 8080,
    "volumes": {
      "/var/www/mysite": {
        "bind": "/usr/share/nginx/html",
        "mode": "ro"
      }
    }
  }'
```

### 2. List Containers

```bash
curl -X GET "http://your-server:8000/containers/" \
  -H "x-token: your-token-here"
```

### 3. Execute Command in Container

```bash
curl -X POST "http://your-server:8000/containers/mysite/exec" \
  -H "x-token: your-token-here" \
  -H "Content-Type: application/json" \
  -d '{
    "command": "ls -la",
    "workdir": "/usr/share/nginx/html"
  }'
```

### 4. Get System Info

```bash
curl -X GET "http://your-server:8000/system/" \
  -H "x-token: your-token-here"
```

### 5. Get Container Logs

```bash
curl -X GET "http://your-server:8000/containers/mysite/logs?tail=100" \
  -H "x-token: your-token-here"
```

## Project Structure

```
serverbond-agent/
├── app/
│   ├── main.py                 # FastAPI application
│   ├── config.py              # Configuration settings
│   ├── core/
│   │   ├── logger.py          # Logging system
│   │   └── security.py        # Token validation
│   ├── services/
│   │   ├── docker_service.py  # Docker operations
│   │   ├── site_service.py    # Site deployment
│   │   └── system_service.py  # System information
│   └── api/
│       └── routes/
│           ├── deploy.py      # Deploy endpoints
│           ├── containers.py  # Container management
│           └── system.py      # System endpoints
├── requirements.txt           # Python dependencies
├── Dockerfile                # Docker image definition
├── docker-compose.yml        # Docker Compose config
├── install.sh                # Auto-installation script
├── export_openapi.py         # OpenAPI spec exporter
└── README.md                 # This file
```

## API Endpoints

### Deploy Endpoints (`/deploy`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/deploy/create` | Create new site |
| POST | `/deploy/deploy` | Deploy site (alias) |

### Container Endpoints (`/containers`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/containers/` | List all containers |
| GET | `/containers/{id}` | Get container details |
| POST | `/containers/` | Create new container |
| POST | `/containers/{id}/start` | Start container |
| POST | `/containers/{id}/stop` | Stop container |
| POST | `/containers/{id}/restart` | Restart container |
| DELETE | `/containers/{id}` | Remove container |
| POST | `/containers/{id}/exec` | Execute command |
| GET | `/containers/{id}/logs` | Get container logs |
| GET | `/containers/{id}/stats` | Get container stats |

### System Endpoints (`/system`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/system/` | General system info |
| GET | `/system/cpu` | CPU information |
| GET | `/system/memory` | Memory information |
| GET | `/system/disk` | Disk information |
| GET | `/system/network` | Network information |
| GET | `/system/health` | Health check |

## Authentication

All endpoints (except `/system/health`) require authentication via `x-token` header:

```bash
curl -H "x-token: your-token-here" https://api.example.com/endpoint
```

## Security

- All endpoints are protected with token authentication
- Token must be sent in request header as `x-token`
- Use strong tokens in production
- HTTPS is recommended for production use

## Development

```bash
# Run in development mode (auto-reload)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# View logs (if using systemd service)
journalctl -u serverbond-agent -f
```

## Systemd Service

The agent can run as a systemd service for automatic startup:

```bash
# Start service
sudo systemctl start serverbond-agent

# Stop service
sudo systemctl stop serverbond-agent

# Restart service
sudo systemctl restart serverbond-agent

# Check status
sudo systemctl status serverbond-agent

# Enable auto-start
sudo systemctl enable serverbond-agent

# View logs
sudo journalctl -u serverbond-agent -f
```

## Docker Deployment

```bash
# Build image
docker build -t serverbond-agent .

# Run with Docker Compose
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AGENT_TOKEN` | change-me-in-production | Authentication token |
| `API_HOST` | 0.0.0.0 | API host address |
| `API_PORT` | 8000 | API port |
| `DOCKER_SOCKET` | unix:///var/run/docker.sock | Docker socket path |
| `LOG_LEVEL` | INFO | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `PROJECT_NAME` | ServerBond Agent | Project name |

## Requirements

- Python 3.11+
- Docker Engine
- Linux server (Ubuntu 20.04+, Debian 11+, CentOS 8+)

## License

MIT

## Support

For questions or issues, please open an issue on GitHub.
