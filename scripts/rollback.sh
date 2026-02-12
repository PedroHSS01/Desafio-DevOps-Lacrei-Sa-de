#!/bin/bash

# Rollback Script for Docker Containers
# This script provides manual rollback capabilities for the Lacrei Saúde application
# Usage: ./rollback.sh [staging|production]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-staging}
CONTAINER_NAME="lacrei-app-${ENVIRONMENT}"
IMAGE_NAME="lacrei-app"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Rollback Script - Lacrei Saúde${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}\n"

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    echo -e "${RED}❌ Error: Invalid environment. Use 'staging' or 'production'${NC}"
    exit 1
fi

# Function to check if container exists
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${1}$"
}

# Function to list available images
list_images() {
    echo -e "${BLUE}📦 Available Docker images:${NC}"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep "$IMAGE_NAME"
}

# Function to get image SHA
get_image_sha() {
    local IMAGE=$1
    docker inspect "$IMAGE" --format='{{.ID}}' | cut -d':' -f2 | cut -c1-12
}

# Step 1: Show current status
echo -e "${BLUE}📊 Current Container Status:${NC}"
if container_exists "$CONTAINER_NAME"; then
    RUNNING_IMAGE=$(docker inspect --format='{{.Image}}' "$CONTAINER_NAME")
    RUNNING_SHA=$(get_image_sha "$RUNNING_IMAGE")
    echo -e "  Container: ${GREEN}${CONTAINER_NAME}${NC} (Running)"
    echo -e "  Image: ${YELLOW}${RUNNING_IMAGE}${NC}"
    echo -e "  SHA: ${YELLOW}${RUNNING_SHA}${NC}"
else
    echo -e "  Container: ${RED}Not running${NC}"
fi

# Step 2: Show available images
echo -e "\n${BLUE}📦 Available images for rollback:${NC}"
list_images

# Step 3: Check for backup image
echo -e "\n${BLUE}🔍 Checking for backup image:${NC}"
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}:backup$"; then
    BACKUP_SHA=$(get_image_sha "${IMAGE_NAME}:backup")
    echo -e "  Backup found: ${GREEN}${IMAGE_NAME}:backup${NC} (SHA: ${YELLOW}${BACKUP_SHA}${NC})"
    ROLLBACK_IMAGE="${IMAGE_NAME}:backup"
    ROLLBACK_METHOD="docker"
else
    echo -e "  Backup not found. Listing latest images for manual selection..."
    echo ""
    LATEST_IMAGE=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "$IMAGE_NAME" | grep -v "backup" | head -n1)
    
    if [ -z "$LATEST_IMAGE" ]; then
        echo -e "${RED}❌ No Docker images found for rollback!${NC}"
        exit 1
    fi
    
    ROLLBACK_IMAGE="$LATEST_IMAGE"
    ROLLBACK_METHOD="latest"
fi

# Step 4: Confirm rollback
echo -e "\n${YELLOW}⚠️  Rollback Confirmation:${NC}"
echo -e "  Target Image: ${BLUE}${ROLLBACK_IMAGE}${NC}"
echo -e "  Target SHA: ${BLUE}$(get_image_sha "$ROLLBACK_IMAGE")${NC}"
echo -e "  This will:"
echo -e "    1. Stop the current container"
echo -e "    2. Start a new container with the previous image"
echo -e "    3. Run health checks"
echo ""
read -p "Are you sure you want to rollback to ${ROLLBACK_IMAGE}? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Rollback cancelled${NC}"
    exit 0
fi

# Step 5: Perform rollback
echo -e "\n${BLUE}🔄 Starting rollback process...${NC}"

# Stop current container
echo -e "${BLUE}Stopping container: ${CONTAINER_NAME}${NC}"
if container_exists "$CONTAINER_NAME"; then
    docker stop "$CONTAINER_NAME"
    docker rm "$CONTAINER_NAME"
    echo -e "  ${GREEN}✓ Container stopped${NC}"
else
    echo -e "  ${YELLOW}⚠ Container not running${NC}"
fi

# Start container with rollback image
echo -e "${BLUE}Starting container with rollback image...${NC}"
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p 3000:3000 \
    -e NODE_ENV="$ENVIRONMENT" \
    "$ROLLBACK_IMAGE"

CONTAINER_ID=$(docker ps -q -f name="$CONTAINER_NAME")
if [ -n "$CONTAINER_ID" ]; then
    echo -e "  ${GREEN}✓ Container started (ID: ${CONTAINER_ID:0:12})${NC}"
else
    echo -e "  ${RED}✗ Failed to start container${NC}"
    exit 1
fi

# Step 6: Wait for container to be ready
echo -e "${BLUE}Waiting for container to become healthy...${NC}"
sleep 5

# Step 7: Health checks
echo -e "${BLUE}Running health checks:${NC}"

# Check 1: Container is running
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "  ${GREEN}✓ Container is running${NC}"
else
    echo -e "  ${RED}✗ Container is not running${NC}"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Check 2: Application responds to /status
HEALTH_CHECK_RETRIES=5
HEALTH_CHECK_COUNT=0
HEALTH_OK=false

while [ $HEALTH_CHECK_COUNT -lt $HEALTH_CHECK_RETRIES ]; do
    echo -e "  Checking /status endpoint (attempt $((HEALTH_CHECK_COUNT + 1))/$HEALTH_CHECK_RETRIES)..."
    
    if curl -s http://localhost:3000/status | jq -e '.status == "ok"' > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Health check passed${NC}"
        HEALTH_OK=true
        break
    fi
    
    HEALTH_CHECK_COUNT=$((HEALTH_CHECK_COUNT + 1))
    if [ $HEALTH_CHECK_COUNT -lt $HEALTH_CHECK_RETRIES ]; then
        sleep 3
    fi
done

if [ "$HEALTH_OK" = false ]; then
    echo -e "  ${RED}✗ Health check failed${NC}"
    echo -e "${BLUE}Container logs:${NC}"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Check 3: Verify environment
RESPONSE=$(curl -s http://localhost:3000/status)
ENV_MATCH=$(echo "$RESPONSE" | jq -r '.environment')
if [ "$ENV_MATCH" == "$ENVIRONMENT" ]; then
    echo -e "  ${GREEN}✓ Environment is correct: ${ENV_MATCH}${NC}"
else
    echo -e "  ${YELLOW}⚠ Environment mismatch: ${ENV_MATCH} (expected: ${ENVIRONMENT})${NC}"
fi

# Step 8: Show rollback summary
echo -e "\n${GREEN}✅ Rollback completed successfully!${NC}"
echo -e "${BLUE}Summary:${NC}"
echo -e "  Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "  Container: ${YELLOW}${CONTAINER_NAME}${NC}"
echo -e "  Image: ${YELLOW}${ROLLBACK_IMAGE}${NC}"
echo -e "  Status: ${GREEN}Running and healthy${NC}"

# Step 9: Cleanup old images (optional)
echo -e "\n${BLUE}🧹 Cleaning up old Docker images...${NC}"
docker image prune -af
echo -e "  ${GREEN}✓ Cleanup completed${NC}"

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Rollback process finished!${NC}"
echo -e "${GREEN}================================${NC}"
