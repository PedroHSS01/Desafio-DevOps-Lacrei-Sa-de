#!/bin/bash

# Emergency Rollback Script - Instant container rollback to previous version
# This is a quick rollback for critical situations
# Usage: ./emergency-rollback.sh [staging|production]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT=${1:-staging}
CONTAINER_NAME="lacrei-app-${ENVIRONMENT}"
BACKUP_IMAGE="lacrei-app:backup"

echo -e "${RED}🚨 EMERGENCY ROLLBACK MODE 🚨${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}\n"

# Verify backup exists
if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${BACKUP_IMAGE}$"; then
    echo -e "${RED}❌ ERROR: No backup image found!${NC}"
    echo -e "Available images:"
    docker images --format '{{.Repository}}:{{.Tag}}' | grep lacrei-app
    exit 1
fi

echo -e "${YELLOW}⚠️  This will immediately rollback to the previous backup version!${NC}"
read -p "Type 'ROLLBACK' to confirm emergency rollback: " CONFIRM

if [ "$CONFIRM" != "ROLLBACK" ]; then
    echo -e "${YELLOW}Emergency rollback cancelled${NC}"
    exit 0
fi

echo -e "\n${BLUE}🔄 Performing emergency rollback...${NC}"

# Stop and remove current container
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Start backup container
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p 3000:3000 \
    -e NODE_ENV="$ENVIRONMENT" \
    "$BACKUP_IMAGE"

# Wait and verify
sleep 5

if curl -s http://localhost:3000/status | jq -e '.status == "ok"' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Emergency rollback completed successfully!${NC}"
    echo -e "Container is healthy and accepting requests"
else
    echo -e "${RED}❌ Emergency rollback completed but health check failed!${NC}"
    docker logs "$CONTAINER_NAME"
    exit 1
fi
