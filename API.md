# API Documentation

## Base URL

```
http://your-server:8000
```

## Authentication

All endpoints except `/ping` require authentication via `x-token` header:

```bash
curl -H "x-token: your-token-here" http://localhost:8000/info
```

## Endpoints

### Agent Management

#### `GET /ping`
Health check endpoint (no authentication required)

**Response:**
```json
{
  "status": "healthy",
  "message": "ServerBond Agent is running",
  "version": "1.0.0"
}
```

**Example:**
```bash
curl http://localhost:8000/ping
```

---

#### `GET /info`
Get system information

**Headers:**
- `x-token`: Authentication token

**Response:**
```json
{
  "status": "success",
  "agent": {
    "name": "ServerBond Agent",
    "version": "1.0.0",
    "host": "0.0.0.0",
    "port": 8000
  },
  "system": {
    "cpu": {...},
    "memory": {...},
    "disk": {...}
  }
}
```

**Example:**
```bash
curl -H "x-token: your-token" http://localhost:8000/info
```

---

#### `POST /register`
Register agent to cloud panel

**Headers:**
- `x-token`: Authentication token
- `Content-Type`: application/json

**Request Body:**
```json
{
  "server_id": "server-123",
  "server_name": "Production Server",
  "cloud_url": "https://cloud.serverbond.dev"
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/register \
  -H "x-token: your-token" \
  -H "Content-Type: application/json" \
  -d '{
    "server_id": "server-123",
    "server_name": "My Server",
    "cloud_url": "https://cloud.example.com"
  }'
```

---

#### `GET /metrics`
Get resource metrics

**Headers:**
- `x-token`: Authentication token

**Response:**
```json
{
  "status": "success",
  "metrics": {
    "cpu": {"percent": 25.5, "count": 4},
    "memory": {"percent": 45.2, "used_gb": 3.2},
    "disk": {"percent": 60.1, "used_gb": 120.5}
  }
}
```

**Example:**
```bash
curl -H "x-token: your-token" http://localhost:8000/metrics
```

---

#### `POST /update`
Update agent (placeholder for future)

**Headers:**
- `x-token`: Authentication token

**Example:**
```bash
curl -X POST -H "x-token: your-token" http://localhost:8000/update
```

---

#### `POST /shutdown`
Shutdown agent

**Headers:**
- `x-token`: Authentication token

**Example:**
```bash
curl -X POST -H "x-token: your-token" http://localhost:8000/shutdown
```

---

### Container Management

#### `GET /containers`
List all containers

**Headers:**
- `x-token`: Authentication token

**Query Parameters:**
- `all` (boolean, default: true): Include stopped containers

**Response:**
```json
{
  "status": "success",
  "count": 5,
  "containers": [
    {
      "id": "abc123...",
      "short_id": "abc123",
      "name": "mysite",
      "status": "running",
      "image": "nginx:alpine"
    }
  ]
}
```

**Example:**
```bash
curl -H "x-token: your-token" http://localhost:8000/containers
curl -H "x-token: your-token" http://localhost:8000/containers?all=false
```

---

#### `GET /images`
List all Docker images

**Headers:**
- `x-token`: Authentication token

**Response:**
```json
{
  "status": "success",
  "count": 10,
  "images": [
    {
      "id": "sha256:abc...",
      "short_id": "sha256:abc",
      "tags": ["nginx:alpine"],
      "size": 23456789,
      "created": "2024-01-01T00:00:00"
    }
  ]
}
```

**Example:**
```bash
curl -H "x-token: your-token" http://localhost:8000/images
```

---

#### `GET /logs/{project}`
Get container logs

**Headers:**
- `x-token`: Authentication token

**Path Parameters:**
- `project`: Container name or ID

**Query Parameters:**
- `tail` (integer, default: 100): Number of lines
- `timestamps` (boolean, default: false): Include timestamps

**Response:**
```json
{
  "status": "success",
  "project": "mysite",
  "logs": "2024-01-01 12:00:00 Starting server...\n..."
}
```

**Example:**
```bash
curl -H "x-token: your-token" http://localhost:8000/logs/mysite
curl -H "x-token: your-token" "http://localhost:8000/logs/mysite?tail=50&timestamps=true"
```

---

#### `POST /exec`
Execute command inside container

**Headers:**
- `x-token`: Authentication token
- `Content-Type`: application/json

**Request Body:**
```json
{
  "container": "mysite",
  "command": "ls -la",
  "workdir": "/app",
  "user": "www-data"
}
```

**Response:**
```json
{
  "status": "success",
  "container": "mysite",
  "command": "ls -la",
  "result": {
    "exit_code": 0,
    "output": "total 48\ndrwxr-xr-x...",
    "success": true
  }
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/exec \
  -H "x-token: your-token" \
  -H "Content-Type: application/json" \
  -d '{
    "container": "mysite",
    "command": "php artisan migrate"
  }'
```

---

#### `POST /restart`
Restart a container

**Headers:**
- `x-token`: Authentication token
- `Content-Type`: application/json

**Request Body:**
```json
{
  "container": "mysite",
  "timeout": 10
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/restart \
  -H "x-token: your-token" \
  -H "Content-Type: application/json" \
  -d '{"container": "mysite"}'
```

---

#### `DELETE /remove`
Remove a site/container

**Headers:**
- `x-token`: Authentication token

**Query Parameters:**
- `container` (required): Container name or ID
- `force` (boolean, default: false): Force remove

**Example:**
```bash
curl -X DELETE "http://localhost:8000/remove?container=mysite" \
  -H "x-token: your-token"
  
curl -X DELETE "http://localhost:8000/remove?container=mysite&force=true" \
  -H "x-token: your-token"
```

---

### Deployment

#### `POST /deploy`
Deploy a new site

**Headers:**
- `x-token`: Authentication token
- `Content-Type`: application/json

**Request Body:**
```json
{
  "site_name": "mysite",
  "image": "nginx:alpine",
  "domain": "mysite.com",
  "port": 8080,
  "command": null,
  "environment": {
    "APP_ENV": "production"
  },
  "volumes": {
    "/var/www/mysite": {
      "bind": "/usr/share/nginx/html",
      "mode": "ro"
    }
  },
  "labels": {
    "type": "static"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Site deployed: mysite",
  "site": {
    "name": "mysite",
    "domain": "mysite.com",
    "port": 8080,
    "container_id": "abc123...",
    "container_status": "running"
  }
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/deploy \
  -H "x-token: your-token" \
  -H "Content-Type: application/json" \
  -d '{
    "site_name": "mysite",
    "image": "nginx:alpine",
    "domain": "mysite.com",
    "port": 8080
  }'
```

---

#### `GET /deploy/status`
Get deployment status

**Headers:**
- `x-token`: Authentication token

**Query Parameters:**
- `site_name` (required): Site name

**Response:**
```json
{
  "status": "success",
  "site": "mysite",
  "container": {
    "id": "abc123...",
    "status": "running",
    "state": {...},
    "created": "2024-01-01T00:00:00"
  }
}
```

**Example:**
```bash
curl -H "x-token: your-token" "http://localhost:8000/deploy/status?site_name=mysite"
```

---

## Error Responses

### 401 Unauthorized
```json
{
  "detail": "Invalid or missing token"
}
```

### 404 Not Found
```json
{
  "detail": "Container not found: mysite"
}
```

### 500 Internal Server Error
```json
{
  "status": "error",
  "message": "Server error",
  "detail": "Error details..."
}
```

## Complete Example Workflow

### 1. Health Check
```bash
curl http://localhost:8000/ping
```

### 2. Get System Info
```bash
curl -H "x-token: your-token" http://localhost:8000/info
```

### 3. Deploy a Site
```bash
curl -X POST http://localhost:8000/deploy \
  -H "x-token: your-token" \
  -H "Content-Type: application/json" \
  -d '{
    "site_name": "myapp",
    "image": "nginx:alpine",
    "domain": "myapp.com",
    "port": 8080
  }'
```

### 4. Check Status
```bash
curl -H "x-token: your-token" "http://localhost:8000/deploy/status?site_name=myapp"
```

### 5. View Logs
```bash
curl -H "x-token: your-token" http://localhost:8000/logs/myapp
```

### 6. Execute Command
```bash
curl -X POST http://localhost:8000/exec \
  -H "x-token: your-token" \
  -H "Content-Type: application/json" \
  -d '{
    "container": "myapp",
    "command": "ls -la"
  }'
```

### 7. Restart Container
```bash
curl -X POST http://localhost:8000/restart \
  -H "x-token: your-token" \
  -H "Content-Type: application/json" \
  -d '{"container": "myapp"}'
```

### 8. Remove Site
```bash
curl -X DELETE "http://localhost:8000/remove?container=myapp&force=true" \
  -H "x-token: your-token"
```

