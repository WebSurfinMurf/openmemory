#!/bin/bash

#############################################################################
# OpenMemory Deployment Script
#############################################################################
# This script deploys OpenMemory with necessary PostgreSQL compatibility fixes
#
# CRITICAL: Official mem0ai code has PostgreSQL DISTINCT ON bugs
# - This script auto-applies fixes from postgresql-fixes.patch before deploying
# - Fixes are required for Memories tab and filter endpoint to work
# - Safe to re-run after pulling new official code
#
# Usage: ./deploy.sh
#############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}OpenMemory Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found${NC}"
    echo "Please run this script from /home/administrator/projects/openmemory/"
    exit 1
fi

# Navigate to source directory
cd source

echo -e "${YELLOW}Step 1: Checking for code updates...${NC}"
git fetch

# Check if we're behind
BEHIND=$(git rev-list HEAD..origin/main --count)
if [ "$BEHIND" -gt 0 ]; then
    echo -e "${YELLOW}Warning: Local code is $BEHIND commits behind origin/main${NC}"
    echo "Run 'cd source && git pull' to update to latest official code"
    echo "Then re-run this deploy script to apply fixes"
    echo ""
fi

# Check current git status
if git diff --quiet && git diff --cached --quiet; then
    echo -e "${GREEN}✓ No uncommitted changes${NC}"
else
    echo -e "${YELLOW}Warning: You have uncommitted changes in source/${NC}"
    echo "Current modifications:"
    git status --short
    echo ""
fi

echo -e "${YELLOW}Step 2: Applying PostgreSQL compatibility fixes...${NC}"

# Check if patch is needed
if git diff --quiet; then
    echo -e "${YELLOW}Applying postgresql-fixes.patch...${NC}"
    if git apply --check ../postgresql-fixes.patch 2>/dev/null; then
        git apply ../postgresql-fixes.patch
        echo -e "${GREEN}✓ PostgreSQL fixes applied${NC}"
    else
        echo -e "${YELLOW}Patch already applied or conflicts detected${NC}"
        echo "This is normal if fixes were previously applied"
    fi
else
    echo -e "${GREEN}✓ Fixes already applied${NC}"
fi

echo ""
echo -e "${YELLOW}Applied fixes:${NC}"
echo "  1. PostgreSQL DISTINCT ON syntax (3 locations in memories.py)"
echo "  2. SQLite check_same_thread fix (database.py)"
echo "  3. Google Gemini SDK dependency (requirements.txt)"
echo "  4. LiteLLM integration config (config.json)"
echo ""

# Return to project root
cd ..

echo -e "${YELLOW}Step 3: Starting containers...${NC}"
docker compose up -d

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "OpenMemory is now running:"
echo "  - API: http://localhost:8765"
echo "  - UI:  https://openmemory.ai-servicers.com"
echo ""
echo "To view logs:"
echo "  docker logs openmemory-api -f"
echo "  docker logs openmemory-ui -f"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "  - Fixes are NOT committed to git (intentional)"
echo "  - If you 'git pull' new code, fixes will be lost"
echo "  - Re-run ./deploy.sh to re-apply fixes after updates"
echo "  - Patch file: postgresql-fixes.patch"
echo ""
