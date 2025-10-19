#!/bin/bash

echo "================================================"
echo "  ServerBond Agent - Docker Build & Test"
echo "================================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${BLUE}[1/4] Cleaning up old containers...${NC}"
docker-compose down 2>/dev/null || true

echo -e "\n${BLUE}[2/4] Building Docker image...${NC}"
if docker-compose build; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo -e "\n${BLUE}[3/4] Starting containers...${NC}"
if docker-compose up -d; then
    echo -e "${GREEN}✓ Containers started${NC}"
else
    echo -e "${RED}✗ Failed to start containers${NC}"
    exit 1
fi

echo -e "\n${BLUE}[4/4] Waiting for API to be ready...${NC}"
sleep 5

# Test health endpoint
echo -e "\n${BLUE}Testing health endpoint...${NC}"
if curl -f -s http://localhost:8000/system/health > /dev/null; then
    echo -e "${GREEN}✓ API is running${NC}"
    
    # Show response
    echo -e "\n${YELLOW}API Response:${NC}"
    curl -s http://localhost:8000/system/health | python3 -m json.tool
    
    echo -e "\n${GREEN}=========================================="
    echo "  Successfully deployed!"
    echo "==========================================${NC}"
    echo ""
    echo "API Documentation:"
    echo "  • Swagger UI: http://localhost:8000/docs"
    echo "  • ReDoc:      http://localhost:8000/redoc"
    echo "  • Health:     http://localhost:8000/system/health"
    echo ""
    echo "View logs:"
    echo "  docker-compose logs -f"
    echo ""
    echo "Stop:"
    echo "  docker-compose down"
else
    echo -e "${RED}✗ API is not responding${NC}"
    echo -e "\n${YELLOW}Container logs:${NC}"
    docker-compose logs
    exit 1
fi

