# OpenMemory - AI Memory Service

## Project Overview
OpenMemory is the official mem0.ai memory service providing persistent AI memory across Claude Code sessions. Uses mem0 v1.0.0 with Gemini Flash LLM and Gemini embeddings for cost-effective operation.

## 🚨 CRITICAL DEPLOYMENT INFORMATION

**Always use `./deploy.sh` to deploy this service!**

### Why?
The official mem0ai code has PostgreSQL DISTINCT ON syntax bugs that prevent the Memories tab from working. We maintain a patch file (`postgresql-fixes.patch`) that automatically fixes these issues during deployment.

### Deployment Workflow
```bash
# Standard deployment
cd /home/administrator/projects/openmemory
./deploy.sh

# After pulling new official code
cd source
git pull
cd ..
./deploy.sh  # Re-applies fixes automatically
```

### What Gets Fixed
1. **PostgreSQL DISTINCT ON syntax** (3 locations in `memories.py`)
   - GET `/api/v1/memories/` endpoint
   - POST `/api/v1/memories/filter` endpoint (Memories tab)
   - GET `/api/v1/memories/{id}/related` endpoint

2. **Database connection args** (`database.py`)
   - Removes SQLite-specific `check_same_thread` for PostgreSQL

3. **Google Gemini SDK** (`requirements.txt`)
   - Adds `google-genai>=0.3` for mem0 v1.0.0 compatibility

4. **LiteLLM integration** (`config.json`)
   - Configures Gemini Flash via LiteLLM
   - Qdrant vector store configuration

**IMPORTANT**: These fixes are NOT committed to git. They're applied at deployment time from the patch file.

## Current Status
- **Status**: ✅ RUNNING
- **Code Version**: Official mem0ai/mem0 (commit 978babd3) + PostgreSQL fixes
- **Container**: openmemory-api, openmemory-ui
- **Port**: 8765 (API)
- **Version**: mem0 v1.0.0
- **Last Updated**: 2025-11-03
- **Networks**: postgres-net, litellm-net, qdrant-net, traefik-net

## Architecture

```
OpenMemory API (openmemory-api:8765)
    ↓
    ├─→ LLM: Gemini Flash 2.5 (via LiteLLM) ✅
    ├─→ Embeddings: Gemini text-embedding-004 ✅
    ├─→ Vector Store: Qdrant (768-dim vectors) ✅
    └─→ Database: PostgreSQL (openmemory_db) ✅
```

## Access Methods
- **API**: http://localhost:8765
- **UI**: http://localhost:3000 (planned)
- **Database**: PostgreSQL openmemory_db
- **Vector Store**: Qdrant on port 6333

## Configuration

### Current Working Config
**Location**: PostgreSQL `openmemory_db.configs` table (key='main')

```json
{
  "mem0": {
    "llm": {
      "provider": "openai",
      "config": {
        "model": "gemini-2.5-flash",
        "temperature": 0.1,
        "max_tokens": 2000,
        "api_key": "env:OPENAI_API_KEY",
        "base_url": "http://litellm:4000/v1"
      }
    },
    "embedder": {
      "provider": "gemini",
      "config": {
        "model": "models/text-embedding-004",
        "api_key": "env:GEMINI_API_KEY"
      }
    },
    "vector_store": {
      "provider": "qdrant",
      "config": {
        "url": "http://qdrant:6333",
        "collection_name": "openmemory",
        "embedding_model_dims": 768
      }
    }
  }
}
```

### Environment Variables
**Location**: `/home/administrator/secrets/openmemory.env`

```bash
# User Configuration
USER=administrator
API_KEY=openmemory-dev-key-a1b2c3d4e5f6g7h8

# Database Configuration
DATABASE_URL=postgresql://admin:Pass123qp@postgres:5432/openmemory_db

# LiteLLM Configuration (for LLM routing)
OPENAI_BASE_URL=http://litellm:4000/v1
OPENAI_API_KEY=sk-litellm-cecca390f610603ff5180ba0ba2674afc8f7689716daf25343de027d10c32404
OPENAI_MODEL=gemini-2.5-flash

# Qdrant Configuration
QDRANT_HOST=qdrant
QDRANT_PORT=6333
QDRANT_URL=http://qdrant:6333

# Gemini Configuration (for embeddings)
GEMINI_API_KEY=AIzaSyAyBy6fwzb61faPgL77gTq-ZiTvHzrV7Rc

# MCP Server Configuration
MCP_SERVER_PORT=8765
MCP_SERVER_HOST=0.0.0.0
```

## 🔴 CRITICAL ISSUES & SOLUTIONS

### Issue 1: mem0 v1.0.0 Requires NEW Google SDK

**Problem**: mem0 v1.0.0 changed to use Google's NEW Python SDK
- ❌ OLD SDK: `google-generativeai` (imports as `import google.generativeai as genai`)
- ✅ NEW SDK: `google-genai` (imports as `from google import genai`)

**Symptoms**:
```
Warning: Failed to initialize memory client: cannot import name 'genai' from 'google' (unknown location)
```

**Solution**:
```bash
# Uninstall old SDK
pip uninstall -y google-generativeai

# Install new SDK
pip install -U google-genai
```

**Permanent Fix**:
Update `source/openmemory/api/requirements.txt`:
```
# OLD (causes error):
google-generativeai>=0.8.0

# NEW (correct):
google-genai>=0.3
```

**File Location**: `/home/administrator/projects/openmemory/source/openmemory/api/requirements.txt:11`

### Issue 2: Gemini Embedding Dimensions Mismatch

**Problem**: Gemini text-embedding-004 produces 768-dimensional vectors, but Qdrant was configured for 1536 (OpenAI default)

**Symptoms**:
```
Vector dimension error: expected dim: 1536, got 768
```

**Root Cause**:
- Gemini text-embedding-004: 768 dimensions
- OpenAI text-embedding-3-small: 1536 dimensions
- Initial config had wrong field name: `embedding_dims` instead of `embedding_model_dims`

**Solution**:
1. Use correct Pydantic field name: `embedding_model_dims` (NOT `embedding_dims`)
2. Set correct dimension value: `768` for Gemini
3. Delete existing Qdrant collections to recreate with correct dimensions

```bash
# Delete old collections
curl -X DELETE http://localhost:6333/collections/openmemory
curl -X DELETE http://localhost:6333/collections/mem0migrations

# Restart service to reinitialize
docker restart openmemory-api
```

**Correct Config Field**:
```json
{
  "vector_store": {
    "provider": "qdrant",
    "config": {
      "url": "http://qdrant:6333",
      "collection_name": "openmemory",
      "embedding_model_dims": 768  // CORRECT field name
    }
  }
}
```

### Issue 3: Invalid Config Field Causing Pydantic Validation Error

**Problem**: Configuration had both `embedding_dims` (invalid) and `embedding_model_dims` (valid)

**Symptoms**:
```
Extra fields not allowed: embedding_dims. Please input only the following fields: embedding_model_dims
```

**Solution**: Remove invalid field from database
```sql
UPDATE configs
SET value = jsonb_set(
  value::jsonb,
  '{mem0,vector_store,config}',
  (value::jsonb->'mem0'->'vector_store'->'config') - 'embedding_dims'
)::json
WHERE key = 'main';
```

**Database**: `openmemory_db.configs` table

### Issue 4: Memory Client Caching After Config Changes

**Problem**: Memory client caches configuration and doesn't reload after database updates

**Solution**: Reset memory client after config changes
```python
# In container
from app.utils.memory import reset_memory_client
reset_memory_client()
```

Or restart the container:
```bash
docker restart openmemory-api
```

## Files & Paths

### Deployment
- **Docker Compose**: `/home/administrator/projects/openmemory/docker-compose.yml`
- **Source Code**: `/home/administrator/projects/openmemory/source/`
- **Data Directory**: `/home/administrator/projects/data/openmemory/` (centralized data storage)
- **Requirements**: `/home/administrator/projects/openmemory/source/openmemory/api/requirements.txt`
- **Secrets**: `/home/administrator/secrets/openmemory.env`

### Key Source Files
- **Memory Client**: `source/openmemory/api/app/utils/memory.py`
  - Lines 136-261: `get_default_memory_config()` - auto-detects vector store
  - Lines 289-388: `get_memory_client()` - initializes mem0 Memory()
  - Lines 264-286: `_parse_environment_variables()` - resolves env: references

- **Config Router**: `source/openmemory/api/app/routers/config.py`
  - API endpoints for config management
  - Lines 159-177: PATCH endpoint with deep merge
  - Lines 120-133: Database save/load functions

### Database
- **Name**: openmemory_db
- **Host**: postgres:5432
- **Tables**:
  - `configs` - mem0 configuration (key='main')
  - `memories` - stored memories (schema enhanced 2025-11-02)
  - `users` - user records

**Memory Schema Enhancement (2025-11-02)**:
Added 3 provenance tracking fields for multi-client support:
```sql
ALTER TABLE memories
  ADD COLUMN source VARCHAR(50) DEFAULT 'claude-code',
  ADD COLUMN embedding_model VARCHAR(100) DEFAULT 'text-embedding-004',
  ADD COLUMN embedding_dim INTEGER DEFAULT 768;
CREATE INDEX idx_memories_source ON memories(source);
```

**Field Descriptions**:
- `source`: Origin of memory (claude-code, chatgpt-web, gemini-api, manual, file)
- `embedding_model`: Model used for vectorization (text-embedding-004)
- `embedding_dim`: Vector dimensions (768 for Gemini, 1536 for OpenAI)

## Claude Code Skill Integration

**Skill Location**: `~/.claude/skills/openmemory/skill.md`

The OpenMemory skill provides zero-boot-token memory operations for Claude Code sessions:
- **Boot Cost**: 0 tokens (skill approach vs 900-1000 for MCP)
- **Usage Cost**: ~400-500 tokens when invoked
- **Commands**: store-memory, search-memory, list-memories

**Quick Usage**:
```bash
# Helper script
/home/administrator/projects/openmemory/scripts/add-memory.sh \
  "administrator" \
  "User prefers Gemini models for cost efficiency" \
  "claude-code"

# Direct API call
curl -X POST 'http://localhost:8765/api/v1/memories/' \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "Important fact to remember",
    "user_id": "administrator",
    "metadata": {
      "source": "claude-code",
      "embedding_model": "text-embedding-004",
      "embedding_dim": 768
    }
  }'
```

## Multi-Client Integration

OpenMemory supports memory sharing across multiple AI clients with provenance tracking.

### Claude Code (Primary)
```bash
# Via skill or direct API
curl -X POST 'http://localhost:8765/api/v1/memories/' \
  -d '{
    "text": "Memory content",
    "user_id": "administrator",
    "metadata": {"source": "claude-code"}
  }'
```

### ChatGPT Integration (Planned)
```markdown
**Setup**: Create Custom GPT with OpenMemory API access
1. Add Action: http://linuxserver.lan:8765/api/v1/memories/
2. Configure POST/GET methods
3. Set metadata.source = "chatgpt-web"
4. Enable for memory storage/retrieval
```

### Gemini Integration (Planned)
```python
# Via Gemini function calling
gemini_function = {
  "name": "store_memory",
  "description": "Store facts for future sessions",
  "parameters": {
    "type": "object",
    "properties": {
      "text": {"type": "string"},
      "user_id": {"type": "string"},
      "source": {"type": "string", "default": "gemini-api"}
    }
  }
}
```

**Memory Filtering by Source**:
```sql
-- Query memories by AI client
SELECT content, created_at FROM memories
WHERE user_id = (SELECT id FROM users WHERE id = 'user-uuid')
  AND source = 'claude-code'
ORDER BY created_at DESC;
```

## Common Commands

### Check Status
```bash
# Container status
docker ps | grep openmemory

# View logs
docker logs openmemory-api --tail 50

# Check configuration
curl -s http://localhost:8765/api/v1/config/ | jq .

# Check Qdrant collection
curl -s http://localhost:6333/collections/openmemory | jq .
```

### Restart Service
```bash
cd /home/administrator/projects/openmemory
docker compose restart openmemory-api
```

### Rebuild Container
```bash
cd /home/administrator/projects/openmemory
docker compose build openmemory-api
docker compose up -d openmemory-api
```

### Test Memory Creation
```bash
# With provenance metadata
curl -X POST 'http://localhost:8765/api/v1/memories/' \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "Test memory content here",
    "user_id": "administrator",
    "metadata": {
      "source": "claude-code",
      "embedding_model": "text-embedding-004",
      "embedding_dim": 768
    }
  }' | jq .

# Using helper script
/home/administrator/projects/openmemory/scripts/add-memory.sh \
  "administrator" \
  "Test memory content" \
  "claude-code"
```

### Update Configuration
```bash
# Get current config
curl -s http://localhost:8765/api/v1/config/ | jq .

# Update config (PATCH - merges with existing)
curl -X PATCH http://localhost:8765/api/v1/config/ \
  -H 'Content-Type: application/json' \
  -d '{
    "mem0": {
      "vector_store": {
        "provider": "qdrant",
        "config": {
          "embedding_model_dims": 768
        }
      }
    }
  }'
```

### Database Operations
```bash
# Connect to database
PGPASSWORD='Pass123qp' psql -h localhost -p 5432 -U admin -d openmemory_db

# View configuration
PGPASSWORD='Pass123qp' psql -h localhost -p 5432 -U admin -d openmemory_db \
  -c "SELECT value->'mem0' FROM configs WHERE key = 'main';"

# List memories with provenance
PGPASSWORD='Pass123qp' psql -h localhost -p 5432 -U admin -d openmemory_db \
  -c "SELECT content, source, embedding_model, embedding_dim, created_at FROM memories ORDER BY created_at DESC LIMIT 10;"

# Filter by source
PGPASSWORD='Pass123qp' psql -h localhost -p 5432 -U admin -d openmemory_db \
  -c "SELECT content, source, created_at FROM memories WHERE source = 'claude-code' ORDER BY created_at DESC LIMIT 10;"
```

## Integration Points

### LiteLLM
- **Purpose**: Routes LLM requests to Gemini Flash
- **Endpoint**: http://litellm:4000/v1
- **Model**: gemini-2.5-flash
- **Network**: litellm-net
- **Status**: ✅ Working

### Qdrant
- **Purpose**: Vector database for embeddings
- **Endpoint**: http://qdrant:6333
- **Collection**: openmemory
- **Dimensions**: 768 (Gemini text-embedding-004)
- **Network**: qdrant-net
- **Status**: ✅ Working

### PostgreSQL
- **Purpose**: Persistent storage for memories and config
- **Database**: openmemory_db
- **User**: admin
- **Network**: postgres-net
- **Status**: ✅ Working

## Cost Analysis

### Gemini vs OpenAI Pricing
**Gemini Flash 2.5** (via LiteLLM):
- Input: ~$0.10 per 1M tokens
- Output: ~$0.30 per 1M tokens

**Gemini text-embedding-004**:
- FREE for up to 1,500 requests/day
- Paid tier: ~$0.00001 per 1K tokens

**OpenAI text-embedding-3-small**:
- ~$0.02 per 1M tokens

**Result**: Using Gemini for both LLM and embeddings is significantly more cost-effective.

## Troubleshooting

### Memory Client Not Initializing
1. Check logs: `docker logs openmemory-api --tail 50 | grep -i "memory\|error"`
2. Verify SDK installed: `docker exec openmemory-api pip list | grep google`
3. Check import: `docker exec openmemory-api python3 -c "from google import genai; print('OK')"`
4. Verify config: `curl -s http://localhost:8765/api/v1/config/ | jq .mem0`
5. Reset client: Restart container

### Vector Dimension Errors
1. Check Qdrant collection: `curl -s http://localhost:6333/collections/openmemory | jq .result.config.params.vectors.size`
2. Should be: 768 for Gemini, 1536 for OpenAI
3. If wrong: Delete collection and restart service
4. Verify config has `embedding_model_dims: 768`

### SDK Import Errors
- Error: `cannot import name 'genai' from 'google'`
- Cause: Old `google-generativeai` SDK installed
- Fix: Uninstall old SDK, install `google-genai>=0.3`
- Rebuild container for permanent fix

### Configuration Not Updating
1. Check database: `PGPASSWORD='Pass123qp' psql -h localhost -p 5432 -U admin -d openmemory_db -c "SELECT value FROM configs WHERE key = 'main';"`
2. Use PATCH endpoint (not PUT) to merge configs
3. Restart container after database changes
4. Check for invalid field names (must match Pydantic schema)

## Security Notes
- GEMINI_API_KEY stored in secrets directory
- LiteLLM master key used for routing
- PostgreSQL credentials in secrets
- No public access (internal networks only)

## Performance Notes
- Gemini Flash: Very fast response times
- Gemini embeddings: FREE tier sufficient for development
- Qdrant: Fast vector search with 768-dim vectors
- PostgreSQL: Standard OLTP performance

## Known Limitations
- mem0 v1.0.0 requires specific SDK versions
- Gemini embeddings are 768-dim (incompatible with 1536-dim collections)
- Configuration caching requires service restart after DB changes
- Pydantic validation strict on field names

## OpenMemory UI Deployment

### Status
- **Deployment**: ✅ DEPLOYED
- **URL**: https://openmemory.ai-servicers.com/
- **Container**: openmemory-ui (skpassegna/openmemory-ui:latest)
- **Authentication**: Keycloak SSO via OAuth2 Proxy ForwardAuth
- **Network**: traefik-net (HTTPS), mcp-net (API access), loki-net (logging)

### Architecture

```
Browser → Traefik (HTTPS) → ForwardAuth (OAuth2 Proxy) → OpenMemory UI (port 3000)
                                     ↓
                              Keycloak (OIDC)

OpenMemory UI → API (http://linuxserver.lan:8765)
```

### Configuration Files

**docker-compose.yml** (`/home/administrator/projects/openmemory/docker-compose.yml`):
```yaml
  openmemory-ui:
    image: skpassegna/openmemory-ui:latest
    container_name: openmemory-ui
    environment:
      NEXT_PUBLIC_API_URL: "http://linuxserver.lan:8765"
      NEXT_PUBLIC_USER_ID: "*"
    networks:
      - traefik-net
      - mcp-net
      - loki-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.openmemory-ui.rule=Host(`openmemory.ai-servicers.com`)"
      - "traefik.http.routers.openmemory-ui.middlewares=openmemory-ui-auth"
      - "traefik.http.services.openmemory-ui.loadbalancer.server.port=3000"
      # ForwardAuth middleware
      - "traefik.http.middlewares.openmemory-ui-auth.forwardauth.address=http://openmemory-ui-auth-proxy:4180/oauth2/auth"

  openmemory-ui-auth-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy:v7.6.0
    container_name: openmemory-ui-auth-proxy
    networks:
      - traefik-net
      - keycloak-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.openmemory-auth.rule=Host(`openmemory.ai-servicers.com`) && PathPrefix(`/oauth2`)"
      - "traefik.http.routers.openmemory-auth.priority=100"
```

**OAuth2 Proxy Config** (`$HOME/secrets/openmemory-oauth2.env`):
```bash
OAUTH2_PROXY_PROVIDER=keycloak-oidc
OAUTH2_PROXY_OIDC_ISSUER_URL=http://keycloak:8080/realms/master
OAUTH2_PROXY_REDIRECT_URL=https://openmemory.ai-servicers.com/oauth2/callback
OAUTH2_PROXY_CLIENT_ID=openmemory
OAUTH2_PROXY_REVERSE_PROXY=true  # ForwardAuth mode
```

### Keycloak Client Configuration

**Client ID**: `openmemory`
**Client Authentication**: ON
**Valid Redirect URIs**: `https://openmemory.ai-servicers.com/*`

**Critical Mapper - Audience Claim**:
- **Mapper Type**: Audience
- **Name**: aud
- **Included Client Audience**: openmemory
- **Add to ID token**: ON ✅ (required for OAuth2 proxy)
- **Add to access token**: ON

**Why this is needed**: OAuth2 proxy validates the ID token during OIDC callback and requires the `aud` claim to match the client ID. Keycloak's master realm doesn't include this by default.

### Deployment Issues Resolved

#### Issue 1: Traefik Not Discovering Container
**Problem**: Container had labels but Traefik wasn't creating router

**Root Cause**: Naming conflict - using `openmemory` for both router and service while Traefik was trying to route to `openmemory-ui-auth-proxy` container

**Solution**:
1. Renamed router to `openmemory-ui` to match container naming pattern
2. Changed router naming from `openmemory` to `openmemory-ui`
3. Traefik error in logs: `service "openmemory-ui" error: unable to find the IP address for the container "/openmemory-ui-auth-proxy"`

**Fixed in**: `docker-compose.yml:71-76` (2025-11-03)

#### Issue 2: OAuth2 Endpoints Not Accessible
**Problem**: ForwardAuth middleware checking auth but no route to OAuth2 proxy's login flow

**Solution**: Added Traefik router for OAuth2 proxy endpoints:
```yaml
- "traefik.http.routers.openmemory-auth.rule=Host(`openmemory.ai-servicers.com`) && PathPrefix(`/oauth2`)"
- "traefik.http.routers.openmemory-auth.priority=100"  # Higher priority than main app
```

This routes `/oauth2/start`, `/oauth2/callback`, `/oauth2/sign_in` to the OAuth2 proxy.

**Fixed in**: `docker-compose.yml:109-114` (2025-11-03)

#### Issue 3: Keycloak Audience Claim Missing
**Problem**: OAuth2 callback failing with "audience claims [aud] do not exist"

**Solution**: Added audience mapper in Keycloak:
- Keycloak Admin → Clients → openmemory → Client scopes → openmemory-dedicated → Add mapper
- Mapper Type: Audience
- Included Client Audience: openmemory
- Add to ID token: ON

**Fixed in**: Keycloak configuration (2025-11-03)

### Current Status (2025-11-03) - ✅ FULLY OPERATIONAL

**Working**:
- ✅ Traefik routing to openmemory-ui container
- ✅ OAuth2 proxy /oauth2/start endpoint redirects to Keycloak
- ✅ Keycloak audience claim configured
- ✅ ForwardAuth middleware active
- ✅ Browser-based login flow working via `/oauth2/start`
- ✅ OAuth2 callback successful after Keycloak authentication
- ✅ Session persistence after successful login
- ✅ Access to OpenMemory UI dashboard

**Access URL**: https://openmemory.ai-servicers.com/oauth2/start

**Dashy Integration**: Updated Dashy link to point to `/oauth2/start` endpoint (2025-11-03)
- Location: `/home/administrator/projects/dashy/config/conf.yml:123`
- Clicking OpenMemory in Dashy now properly redirects to Keycloak login

**Known Limitation**: Direct access to `https://openmemory.ai-servicers.com/` shows "Unauthorized" without auto-redirect. This is expected ForwardAuth behavior. Users must access via `/oauth2/start` to initiate login.

**Testing Verified**:
```bash
# Shows 401 (expected - no auth cookie):
curl -I https://openmemory.ai-servicers.com/

# Redirects to Keycloak (302):
curl -I https://openmemory.ai-servicers.com/oauth2/start
```

## Future Enhancements
- [x] Deploy OpenMemory UI on port 3000 with Keycloak SSO
- [x] Claude Code skill integration (zero boot tokens)
- [ ] ChatGPT Custom GPT integration
- [ ] Gemini function calling integration
- [x] Configure Traefik routing for external access (via ForwardAuth)
- [ ] Set up Loki logging integration
- [ ] Add health check endpoints
- [ ] Semantic search API endpoint
- [ ] Channel filtering (per-client memory isolation)
- [ ] Confidence scoring and decay policies
- [ ] Fix ForwardAuth 401 redirect to OAuth2 sign-in page

## Related Documentation
- mem0 Documentation: https://docs.mem0.ai/
- Gemini API: https://ai.google.dev/
- Qdrant: https://qdrant.tech/documentation/
- LiteLLM Integration: `/home/administrator/projects/litellm/CLAUDE.md`

---
**Created**: 2025-11-02 by Claude Code (Sonnet 4.5)
**Status**: Production-ready with Gemini Flash + Gemini embeddings
