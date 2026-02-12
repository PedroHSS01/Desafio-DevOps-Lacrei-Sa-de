#!/bin/bash

# Post-Rollback Health Check & Validation
# Run this after any rollback to ensure system is healthy
# Usage: ./post-rollback-check.sh [staging|production]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT=${1:-staging}

# Determine URLs and names based on environment
if [ "$ENVIRONMENT" == "production" ]; then
    PUBLIC_URL="https://54.159.81.199"
    CONTAINER_NAME="lacrei-app-production"
else
    PUBLIC_URL="https://54.226.194.208"
    CONTAINER_NAME="lacrei-app-staging"
fi

CHECKS_PASSED=0
CHECKS_FAILED=0

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Post-Rollback Health Check         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Container: ${YELLOW}${CONTAINER_NAME}${NC}"
echo -e "URL: ${YELLOW}${PUBLIC_URL}${NC}"
echo ""

# Function to pass/fail
pass_check() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

fail_check() {
    echo -e "  ${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

# Check 1: Container running
echo -e "${BLUE}1️⃣  Container Status${NC}"
if docker ps | grep -q "$CONTAINER_NAME"; then
    CONTAINER_ID=$(docker ps -q -f name="$CONTAINER_NAME")
    UPTIME=$(docker stats --no-stream "$CONTAINER_NAME" 2>/dev/null | tail -1 | awk '{print $NF}' || echo "N/A")
    pass_check "Container is running (ID: ${CONTAINER_ID:0:12})"
else
    fail_check "Container is not running"
fi

# Check 2: Docker resource usage
echo -e "\n${BLUE}2️⃣  Resource Usage${NC}"
if docker stats --no-stream "$CONTAINER_NAME" > /dev/null 2>&1; then
    STATS=$(docker stats --no-stream "$CONTAINER_NAME" | tail -1)
    CPU=$(echo "$STATS" | awk '{print $2}')
    MEM=$(echo "$STATS" | awk '{print $4}')
    
    # Check if resources are reasonable
    CPU_NUM=${CPU%\%}
    MEM_NUM=${MEM%\%}
    
    if (( $(echo "$CPU_NUM < 100" | bc -l) )); then
        pass_check "CPU usage nominal: ${CPU}"
    else
        fail_check "CPU usage high: ${CPU}"
    fi
    
    if (( $(echo "$MEM_NUM < 80" | bc -l) )); then
        pass_check "Memory usage nominal: ${MEM}"
    else
        fail_check "Memory usage high: ${MEM}"
    fi
else
    fail_check "Could not retrieve resource stats"
fi

# Check 3: Local health endpoint
echo -e "\n${BLUE}3️⃣  Local Health Check (Docker)${NC}"
if curl -s http://localhost:3000/status | jq -e '.status == "ok"' > /dev/null 2>&1; then
    pass_check "Local /status endpoint responds correctly"
    STATUS_RESPONSE=$(curl -s http://localhost:3000/status)
    echo -e "     Response: ${YELLOW}$(echo $STATUS_RESPONSE | jq -c .)${NC}"
else
    fail_check "Local /status endpoint failed"
fi

# Check 4: Public health endpoint (HTTPS)
echo -e "\n${BLUE}4️⃣  Public Health Check (HTTPS)${NC}"
if curl -s -k "${PUBLIC_URL}/status" | jq -e '.status == "ok"' > /dev/null 2>&1; then
    pass_check "Public /status endpoint responds correctly"
    PUBLIC_RESPONSE=$(curl -s -k "${PUBLIC_URL}/status")
    echo -e "     Response: ${YELLOW}$(echo $PUBLIC_RESPONSE | jq -c .)${NC}"
else
    fail_check "Public /status endpoint failed or SSL issue"
fi

# Check 5: HTTP to HTTPS redirect
echo -e "\n${BLUE}5️⃣  HTTP Redirect Configuration${NC}"
if curl -s -I "http://${PUBLIC_URL#https://}" 2>/dev/null | grep -q "301\|302"; then
    pass_check "HTTP → HTTPS redirect is configured"
else
    fail_check "HTTP redirect not working"
fi

# Check 6: Root endpoint
echo -e "\n${BLUE}6️⃣  API Root Endpoint${NC}"
if curl -s -k "${PUBLIC_URL}/" | jq -e '.endpoints' > /dev/null 2>&1; then
    pass_check "Root endpoint responds with API info"
else
    fail_check "Root endpoint failed"
fi

# Check 7: Container logs - check for errors
echo -e "\n${BLUE}7️⃣  Container Logs (Last 5 lines)${NC}"
LATEST_LOGS=$(docker logs "$CONTAINER_NAME" --tail 5 2>&1)
if echo "$LATEST_LOGS" | grep -qi "error\|exception\|crash"; then
    fail_check "Container logs contain errors:"
    echo "$LATEST_LOGS" | sed 's/^/     /'
else
    pass_check "No critical errors in recent logs"
    echo -e "     ${YELLOW}Latest logs:${NC}"
    echo "$LATEST_LOGS" | sed 's/^/     /'
fi

# Check 8: Environment verification
echo -e "\n${BLUE}8️⃣  Environment Configuration${NC}"
ENV_RESPONSE=$(curl -s -k "${PUBLIC_URL}/status" | jq -r '.environment')
if [ "$ENV_RESPONSE" == "$ENVIRONMENT" ]; then
    pass_check "Environment is correctly set to: ${ENV_RESPONSE}"
else
    fail_check "Environment mismatch: got ${ENV_RESPONSE}, expected ${ENVIRONMENT}"
fi

# Check 9: Response time
echo -e "\n${BLUE}9️⃣  Response Time${NC}"
RESPONSE_TIME=$(curl -s -k -o /dev/null -w '%{time_total}' "${PUBLIC_URL}/status")
RESPONSE_TIME_MS=$(echo "$RESPONSE_TIME * 1000" | bc | cut -d'.' -f1)

if (( $RESPONSE_TIME_MS < 1000 )); then
    pass_check "Response time is good: ${RESPONSE_TIME_MS}ms"
elif (( $RESPONSE_TIME_MS < 2000 )); then
    pass_check "Response time acceptable: ${RESPONSE_TIME_MS}ms"
else
    fail_check "Response time is slow: ${RESPONSE_TIME_MS}ms"
fi

# Check 10: Network connectivity
echo -e "\n${BLUE}🔟 Network Status${NC}"
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    pass_check "Network connectivity operational"
else
    fail_check "Network connectivity issues detected"
fi

# Summary
echo -e "\n${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Health Check Summary          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

echo -e "\n${GREEN}Passed: ${CHECKS_PASSED}${NC}"
echo -e "${RED}Failed: ${CHECKS_FAILED}${NC}"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✅ All health checks passed!${NC}"
    echo -e "${GREEN}Rollback completed successfully and system is healthy.${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Some health checks failed!${NC}"
    echo -e "${YELLOW}Please investigate the issues above before declaring rollback successful.${NC}"
    exit 1
fi
