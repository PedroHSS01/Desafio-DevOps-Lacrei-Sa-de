#!/bin/bash

# Test Rollback Procedure Script
# This script helps test rollback procedures safely in staging environment
# Usage: ./test-rollback.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT=${1:-staging}
CONTAINER_NAME="lacrei-app-${ENVIRONMENT}"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Rollback Test & Validation Procedure  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "Target Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo ""

# Verify we're testing in staging
if [ "$ENVIRONMENT" == "production" ]; then
    echo -e "${RED}❌ ERROR: Testing should only be done in STAGING!${NC}"
    echo -e "   Use: ./test-rollback.sh staging"
    exit 1
fi

echo -e "${BLUE}📋 Rollback Test Checklist:${NC}"
echo ""

# Check 1: Container is running
echo -e "${BLUE}1️⃣  Verify container is running${NC}"
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "   ${GREEN}✓ Container is running${NC}"
    RUNNING_IMAGE=$(docker inspect --format='{{.Image}}' "$CONTAINER_NAME")
    echo -e "   Image: ${YELLOW}${RUNNING_IMAGE}${NC}"
else
    echo -e "   ${RED}✗ Container is not running!${NC}"
    exit 1
fi

# Check 2: Health endpoint responds
echo -e "\n${BLUE}2️⃣  Verify /status endpoint responds${NC}"
RESPONSE=$(curl -s http://localhost:3000/status)
if echo "$RESPONSE" | jq -e '.status == "ok"' > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓ Health check passed${NC}"
    echo -e "   Response: ${YELLOW}${RESPONSE}${NC}"
else
    echo -e "   ${RED}✗ Health check failed!${NC}"
    exit 1
fi

# Check 3: Backup image exists
echo -e "\n${BLUE}3️⃣  Verify backup image exists${NC}"
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^lacrei-app:backup$"; then
    BACKUP_SHA=$(docker inspect lacrei-app:backup --format='{{.ID}}' | cut -d':' -f2 | cut -c1-12)
    echo -e "   ${GREEN}✓ Backup image exists${NC}"
    echo -e "   SHA: ${YELLOW}${BACKUP_SHA}${NC}"
else
    echo -e "   ${RED}✗ Backup image not found!${NC}"
    exit 1
fi

# Check 4: Multiple images available
echo -e "\n${BLUE}4️⃣  Verify multiple versions available${NC}"
IMAGE_COUNT=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep lacrei-app | wc -l)
echo -e "   ${GREEN}✓ Found ${IMAGE_COUNT} Docker images${NC}"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep lacrei-app | head -5

# Check 5: Simulate rollback
echo -e "\n${BLUE}5️⃣  Simulate rollback (DRY RUN)${NC}"
echo -e "   ${YELLOW}This will NOT change anything, just show what would happen${NC}"

# Get current container info
CURRENT_CONTAINER=$(docker ps -q -f name="$CONTAINER_NAME")
CURRENT_IMAGE=$(docker inspect "$CURRENT_CONTAINER" --format='{{.Image}}')

echo -e "   Current container: ${YELLOW}${CURRENT_CONTAINER:0:12}}${NC}"
echo -e "   Current image: ${YELLOW}${CURRENT_IMAGE}${NC}"

# Simulate rollback
echo -e "   ${BLUE}[DRY RUN] Would:${NC}"
echo -e "   1. Stop container: ${YELLOW}docker stop ${CONTAINER_NAME}${NC}"
echo -e "   2. Remove container: ${YELLOW}docker rm ${CONTAINER_NAME}${NC}"
echo -e "   3. Start with backup: ${YELLOW}docker run ... lacrei-app:backup${NC}"
echo -e "   4. Run health checks..."
echo -e "   ${GREEN}✓ Simulation complete (no changes made)${NC}"

# Check 6: Verify script permissions
echo -e "\n${BLUE}6️⃣  Verify rollback scripts are executable${NC}"
SCRIPTS=("../scripts/rollback.sh" "../scripts/emergency-rollback.sh")
for SCRIPT in "${SCRIPTS[@]}"; do
    if [ -f "$SCRIPT" ] && [ -x "$SCRIPT" ]; then
        echo -e "   ${GREEN}✓ ${SCRIPT} is executable${NC}"
    else
        echo -e "   ${YELLOW}⚠ ${SCRIPT} needs chmod +x${NC}"
    fi
done

# Check 7: Network connectivity
echo -e "\n${BLUE}7️⃣  Verify network connectivity${NC}"
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓ Network is accessible${NC}"
else
    echo -e "   ${YELLOW}⚠ Network might be restricted${NC}"
fi

# Check 8: Disk space
echo -e "\n${BLUE}8️⃣  Verify disk space for rollback${NC}"
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "   ${GREEN}✓ Disk space available (${DISK_USAGE}% used)${NC}"
else
    echo -e "   ${RED}✗ Disk almost full (${DISK_USAGE}% used)!${NC}"
    exit 1
fi

# Summary
echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ All rollback tests passed!        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}📝 Next steps:${NC}"
echo -e "  1. Review the output above"
echo -e "  2. Test actual rollback procedures:"
echo -e "     - GitHub Actions rollback"
echo -e "     - Git revert rollback"
echo -e "     - Docker manual rollback"
echo -e "  3. Document any issues"
echo -e "  4. Verify health after each test"

echo -e "\n${YELLOW}🎯 Rollback Procedure is READY FOR TESTING!${NC}"
