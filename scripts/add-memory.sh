#!/bin/bash
# Helper script for adding memories to OpenMemory
# Usage: ./add-memory.sh "text content" [category] [tags] [agent] [source]

set -e

TEXT="$1"
CATEGORY="${2:-pattern}"
TAGS="${3:-general}"
AGENT="${4:-main-session}"
SOURCE="${5:-claude-code}"
USER_ID="administrator"

if [ -z "$TEXT" ]; then
    echo "Error: Text content required"
    echo "Usage: $0 \"text content\" [category] [tags] [agent] [source]"
    echo ""
    echo "Categories: preference, pattern, decision, workaround, lesson-learned, integration"
    echo "Tags: comma-separated (e.g., \"docker,networking,best-practice\")"
    echo "Agent: architect, developer, security, pm, main-session"
    echo ""
    echo "Example: $0 \"Use 3-network pattern for OAuth2\" \"pattern\" \"docker,oauth2,networking\" \"developer\""
    exit 1
fi

# Convert comma-separated tags to JSON array
IFS=',' read -ra TAG_ARRAY <<< "$TAGS"
TAG_JSON=$(printf '%s\n' "${TAG_ARRAY[@]}" | jq -R . | jq -s .)

echo "Adding memory..."
echo "  Category: $CATEGORY"
echo "  Tags: $TAGS"
echo "  Agent: $AGENT"
echo "  Source: $SOURCE"
echo ""

curl -s -X POST 'http://localhost:8765/api/v1/memories/' \
  -H 'Content-Type: application/json' \
  -d "{
    \"text\": \"$TEXT\",
    \"user_id\": \"$USER_ID\",
    \"metadata\": {
      \"source\": \"$SOURCE\",
      \"agent\": \"$AGENT\",
      \"category\": \"$CATEGORY\",
      \"tags\": $TAG_JSON,
      \"embedding_model\": \"text-embedding-004\",
      \"embedding_dim\": 768
    }
  }" | jq '.'

echo ""
echo "✅ Memory added successfully"
