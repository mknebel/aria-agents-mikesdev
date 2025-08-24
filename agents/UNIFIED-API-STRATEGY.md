# Unified API Consolidation Strategy
## Integrating APEX, ARIA, and SuperClaude APIs

**Version**: 1.0  
**Date**: January 2025  
**Location**: `/mnt/d/MikesDev/.claude/agents/UNIFIED-API-STRATEGY.md`

---

## Overview

This document outlines the strategy for consolidating three distinct API systems into a unified gateway while maintaining backward compatibility and enabling new capabilities.

### Current API Landscape

1. **APEX API** (FastAPI/Python)
   - Location: `http://localhost:8001`
   - RESTful + WebSocket
   - JSON request/response
   - Modern async architecture

2. **ARIA API** (PHP)
   - Location: `http://localhost/kdp/aria/api/`
   - Traditional REST
   - Form-encoded + JSON responses
   - Synchronous execution

3. **SuperClaude API** (Shell/Node.js)
   - Location: Command-line based
   - File-system integration
   - Markdown command definitions
   - Process spawning

---

## Unified API Architecture

### API Gateway Design

```
┌─────────────────────────────────────────────────────────────┐
│                   Client Applications                        │
├─────────────────────────────────────────────────────────────┤
│                  Unified API Gateway                         │
│                 http://localhost/agents/api                  │
├─────────────────────────────────────────────────────────────┤
│                    Route Handler                             │
│              Pattern Matching & Transformation               │
├──────────────┬────────────────┬─────────────────────────────┤
│  APEX Proxy  │   ARIA Proxy   │  SuperClaude Adapter        │
├──────────────┴────────────────┴─────────────────────────────┤
│              Unified Response Formatter                      │
└─────────────────────────────────────────────────────────────┘
```

### Core API Endpoints

#### 1. Agent Management
```yaml
# List all agents
GET /api/v1/agents
Response:
{
  "agents": [
    {
      "id": "apex:CODE",
      "name": "Code Agent",
      "system": "apex",
      "category": "technical",
      "status": "active",
      "capabilities": ["programming", "debugging", "refactoring"],
      "metrics": {
        "success_rate": 98.5,
        "avg_response_ms": 1250,
        "total_tasks": 15420
      }
    }
  ],
  "total": 95,
  "systems": {
    "apex": 60,
    "aria": 25,
    "superclaude": 10
  }
}

# Get specific agent
GET /api/v1/agents/{agent_id}

# Update agent configuration
PUT /api/v1/agents/{agent_id}/config
```

#### 2. Task Execution
```yaml
# Submit task for execution
POST /api/v1/execute
Request:
{
  "agent": "apex:CODE",  # or "aria:coder" or "sc:architect"
  "task": {
    "type": "code_review",
    "parameters": {
      "repository": "https://github.com/user/repo",
      "branch": "feature/new-api"
    },
    "priority": "high",
    "timeout": 30000
  },
  "options": {
    "async": true,
    "callback_url": "https://webhook.site/..."
  }
}

Response:
{
  "execution_id": "exec_1234567890",
  "status": "queued",
  "agent": "apex:CODE",
  "estimated_duration_ms": 5000,
  "queue_position": 3
}

# Get execution status
GET /api/v1/executions/{execution_id}

# Cancel execution
DELETE /api/v1/executions/{execution_id}
```

#### 3. Workflow Management
```yaml
# Execute workflow
POST /api/v1/workflows/execute
Request:
{
  "workflow_id": "code_review_workflow",
  "input": {
    "repository": "https://github.com/user/repo",
    "requirements": ["security", "performance", "style"]
  }
}

# List available workflows
GET /api/v1/workflows

# Create custom workflow
POST /api/v1/workflows
```

#### 4. Real-time Subscriptions
```yaml
# WebSocket endpoint
WS /api/v1/ws

# Subscribe to events
{
  "action": "subscribe",
  "events": ["task_complete", "agent_status", "workflow_update"],
  "filters": {
    "agents": ["apex:CODE", "aria:reviewer"],
    "priority": ["high", "critical"]
  }
}
```

---

## Implementation Details

### 1. API Gateway Implementation

```python
# /mnt/d/MikesDev/www/agents/api/gateway.py
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
import httpx
import asyncio
from typing import Dict, Any, Optional

class UnifiedAPIGateway:
    def __init__(self):
        self.app = FastAPI(title="Unified Agent API", version="1.0")
        self.route_handlers = {
            'apex': APEXRouteHandler(),
            'aria': ARIARouteHandler(),
            'superclaude': SuperClaudeRouteHandler()
        }
        self.setup_routes()
    
    def setup_routes(self):
        # Agent endpoints
        self.app.get("/api/v1/agents")(self.list_agents)
        self.app.get("/api/v1/agents/{agent_id}")(self.get_agent)
        
        # Execution endpoints
        self.app.post("/api/v1/execute")(self.execute_task)
        self.app.get("/api/v1/executions/{execution_id}")(self.get_execution)
        
        # Workflow endpoints
        self.app.post("/api/v1/workflows/execute")(self.execute_workflow)
        self.app.get("/api/v1/workflows")(self.list_workflows)
    
    async def list_agents(self, 
                         system: Optional[str] = None,
                         category: Optional[str] = None,
                         status: Optional[str] = None):
        """List agents with optional filtering"""
        # Query unified database view
        query = """
            SELECT * FROM v_unified_agents 
            WHERE 1=1
            AND (:system IS NULL OR source_system = :system)
            AND (:category IS NULL OR category = :category)
            AND (:status IS NULL OR status = :status)
            ORDER BY success_rate DESC
        """
        
        agents = await db.fetch_all(query, {
            "system": system,
            "category": category, 
            "status": status
        })
        
        return {
            "agents": [self.format_agent(a) for a in agents],
            "total": len(agents)
        }
    
    async def execute_task(self, request: TaskExecutionRequest):
        """Route task to appropriate system"""
        agent_system = request.agent.split(':')[0]
        
        if agent_system not in self.route_handlers:
            raise HTTPException(400, f"Unknown agent system: {agent_system}")
        
        handler = self.route_handlers[agent_system]
        execution_id = await handler.execute(request)
        
        # Store in unified execution history
        await self.store_execution(execution_id, request)
        
        return {
            "execution_id": execution_id,
            "status": "queued",
            "agent": request.agent
        }
```

### 2. Route Handlers for Each System

```python
# /mnt/d/MikesDev/www/agents/api/handlers/apex_handler.py
class APEXRouteHandler:
    def __init__(self):
        self.base_url = "http://localhost:8001"
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def execute(self, request: TaskExecutionRequest) -> str:
        """Execute task via APEX API"""
        agent_code = request.agent.split(':')[1]
        
        apex_request = {
            "agent_code": agent_code,
            "task_type": request.task.type,
            "description": request.task.get("description", ""),
            "parameters": request.task.parameters,
            "priority": request.task.priority
        }
        
        response = await self.client.post(
            f"{self.base_url}/api/tasks/create",
            json=apex_request
        )
        
        if response.status_code != 200:
            raise HTTPException(response.status_code, response.text)
        
        data = response.json()
        return f"apex:{data['task_id']}"
    
    async def get_status(self, task_id: str) -> Dict:
        """Get task status from APEX"""
        response = await self.client.get(
            f"{self.base_url}/api/tasks/{task_id}"
        )
        return response.json()

# /mnt/d/MikesDev/www/agents/api/handlers/aria_handler.py
class ARIARouteHandler:
    def __init__(self):
        self.base_url = "http://localhost/kdp/aria/api"
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def execute(self, request: TaskExecutionRequest) -> str:
        """Execute task via ARIA API"""
        agent_name = request.agent.split(':')[1]
        
        # ARIA expects form data
        form_data = {
            "action": "execute_task",
            "agent_name": agent_name,
            "task_type": request.task.type,
            "parameters": json.dumps(request.task.parameters),
            "priority": request.task.priority
        }
        
        response = await self.client.post(
            f"{self.base_url}/agent_execute.php",
            data=form_data
        )
        
        data = response.json()
        return f"aria:{data['task_id']}"

# /mnt/d/MikesDev/www/agents/api/handlers/superclaude_handler.py
class SuperClaudeRouteHandler:
    def __init__(self):
        self.command_executor = SuperClaudeExecutor()
    
    async def execute(self, request: TaskExecutionRequest) -> str:
        """Execute SuperClaude command"""
        command_name = request.agent.split(':')[1]
        
        # SuperClaude uses file-based commands
        execution_id = str(uuid.uuid4())
        
        # Create async task for command execution
        asyncio.create_task(
            self.command_executor.run_command(
                command_name,
                request.task.parameters,
                execution_id
            )
        )
        
        return f"sc:{execution_id}"
```

### 3. Response Standardization

```python
# /mnt/d/MikesDev/www/agents/api/formatters.py
class UnifiedResponseFormatter:
    """Standardizes responses across all systems"""
    
    @staticmethod
    def format_agent(agent_data: Dict, source_system: str) -> Dict:
        """Convert agent data to unified format"""
        if source_system == 'apex':
            return {
                "id": f"apex:{agent_data['agent_code']}",
                "name": agent_data['agent_name'],
                "system": "apex",
                "category": agent_data['category'],
                "status": agent_data['status'],
                "capabilities": agent_data.get('skills', []),
                "metrics": {
                    "success_rate": agent_data.get('success_rate', 0),
                    "avg_response_ms": agent_data.get('response_time_ms', 0),
                    "total_tasks": agent_data.get('total_tasks', 0)
                }
            }
        elif source_system == 'aria':
            return {
                "id": f"aria:{agent_data['agent_name']}",
                "name": agent_data['agent_name'],
                "system": "aria",
                "category": agent_data.get('agent_type', 'general'),
                "status": agent_data['status'],
                "capabilities": json.loads(agent_data.get('capabilities', '[]')),
                "metrics": {
                    "success_rate": agent_data.get('success_rate', 0),
                    "avg_response_ms": agent_data.get('avg_response_time', 0),
                    "total_tasks": agent_data.get('total_executions', 0)
                }
            }
        elif source_system == 'superclaude':
            return {
                "id": f"sc:{agent_data['command_name']}",
                "name": agent_data['display_name'],
                "system": "superclaude",
                "category": agent_data['category'],
                "status": "active",
                "capabilities": agent_data.get('capabilities', []),
                "metrics": {
                    "success_rate": agent_data.get('success_rate', 100),
                    "avg_response_ms": 0,
                    "total_tasks": agent_data.get('execution_count', 0)
                }
            }
    
    @staticmethod
    def format_execution_result(result: Dict, source_system: str) -> Dict:
        """Convert execution result to unified format"""
        return {
            "execution_id": result.get('execution_id'),
            "status": UnifiedResponseFormatter.map_status(
                result.get('status'), 
                source_system
            ),
            "result": result.get('output', result.get('result')),
            "error": result.get('error', result.get('error_message')),
            "metrics": {
                "execution_time_ms": result.get('execution_time_ms', 0),
                "tokens_used": result.get('tokens_used', 0)
            },
            "timestamp": result.get('completed_at', datetime.now().isoformat())
        }
    
    @staticmethod
    def map_status(status: str, source_system: str) -> str:
        """Map system-specific statuses to unified statuses"""
        status_mapping = {
            'apex': {
                'pending': 'queued',
                'in_progress': 'running',
                'completed': 'completed',
                'failed': 'failed'
            },
            'aria': {
                'waiting': 'queued',
                'processing': 'running',
                'done': 'completed',
                'error': 'failed'
            },
            'superclaude': {
                'initiated': 'queued',
                'executing': 'running',
                'finished': 'completed',
                'crashed': 'failed'
            }
        }
        
        return status_mapping.get(source_system, {}).get(status, status)
```

### 4. Authentication & Rate Limiting

```python
# /mnt/d/MikesDev/www/agents/api/middleware.py
from fastapi import Request, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import redis
from datetime import datetime, timedelta

class RateLimiter:
    def __init__(self, redis_client):
        self.redis = redis_client
        self.limits = {
            'default': {'requests': 100, 'window': 60},  # 100 req/min
            'execute': {'requests': 20, 'window': 60},   # 20 exec/min
            'workflow': {'requests': 5, 'window': 60}    # 5 workflows/min
        }
    
    async def check_rate_limit(self, 
                              client_id: str, 
                              endpoint_type: str = 'default'):
        key = f"rate_limit:{client_id}:{endpoint_type}"
        limit = self.limits.get(endpoint_type, self.limits['default'])
        
        current = await self.redis.incr(key)
        if current == 1:
            await self.redis.expire(key, limit['window'])
        
        if current > limit['requests']:
            raise HTTPException(429, "Rate limit exceeded")
        
        return {
            'limit': limit['requests'],
            'remaining': limit['requests'] - current,
            'reset': await self.redis.ttl(key)
        }

class APIKeyAuth(HTTPBearer):
    async def __call__(self, request: Request):
        credentials = await super().__call__(request)
        
        # Validate API key
        if not await self.validate_api_key(credentials.credentials):
            raise HTTPException(403, "Invalid API key")
        
        return credentials.credentials
    
    async def validate_api_key(self, api_key: str) -> bool:
        # Check against database
        result = await db.fetch_one(
            "SELECT * FROM api_keys WHERE key_hash = SHA2(:key, 256) AND active = 1",
            {"key": api_key}
        )
        return result is not None
```

### 5. Error Handling & Logging

```python
# /mnt/d/MikesDev/www/agents/api/errors.py
from fastapi import Request
from fastapi.responses import JSONResponse
import traceback
import logging

class UnifiedErrorHandler:
    @staticmethod
    async def handle_error(request: Request, exc: Exception):
        error_id = str(uuid.uuid4())
        
        # Log detailed error
        logging.error(f"Error {error_id}: {str(exc)}", exc_info=True)
        
        # Store in database for analysis
        await db.execute("""
            INSERT INTO unified_system_events 
            (event_id, event_type, source_system, severity, title, description)
            VALUES (:id, 'api_error', 'unified', 'error', :title, :trace)
        """, {
            "id": error_id,
            "title": str(exc)[:255],
            "trace": traceback.format_exc()
        })
        
        # Return sanitized error to client
        status_code = getattr(exc, 'status_code', 500)
        return JSONResponse(
            status_code=status_code,
            content={
                "error": {
                    "id": error_id,
                    "message": str(exc) if status_code < 500 else "Internal server error",
                    "type": exc.__class__.__name__,
                    "timestamp": datetime.now().isoformat()
                }
            }
        )
```

---

## Migration Strategy

### Phase 1: Parallel Operation (Week 1-2)
1. Deploy unified API gateway
2. Route traffic to legacy endpoints
3. Monitor for compatibility issues
4. Collect performance metrics

### Phase 2: Client Migration (Week 3-4)
1. Update documentation
2. Provide migration guides
3. Support both old and new endpoints
4. Gradual client updates

### Phase 3: Optimization (Week 5-6)
1. Implement caching layer
2. Optimize database queries
3. Add advanced features
4. Performance tuning

### Phase 4: Legacy Sunset (Month 2+)
1. Deprecation notices
2. Final migration assistance
3. Shutdown legacy endpoints
4. Full unified operation

---

## API Documentation

### OpenAPI Specification
```yaml
openapi: 3.0.0
info:
  title: Unified Agent System API
  version: 1.0.0
  description: Consolidated API for APEX, ARIA, and SuperClaude agent systems

servers:
  - url: http://localhost/agents/api/v1

paths:
  /agents:
    get:
      summary: List all agents
      parameters:
        - name: system
          in: query
          schema:
            type: string
            enum: [apex, aria, superclaude]
        - name: category
          in: query
          schema:
            type: string
        - name: status
          in: query
          schema:
            type: string
            enum: [active, busy, offline]
      responses:
        200:
          description: List of agents
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AgentList'

  /execute:
    post:
      summary: Execute a task
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TaskExecutionRequest'
      responses:
        200:
          description: Execution started
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ExecutionResponse'

components:
  schemas:
    Agent:
      type: object
      properties:
        id:
          type: string
          example: "apex:CODE"
        name:
          type: string
        system:
          type: string
          enum: [apex, aria, superclaude]
        category:
          type: string
        status:
          type: string
        capabilities:
          type: array
          items:
            type: string
        metrics:
          type: object
          properties:
            success_rate:
              type: number
            avg_response_ms:
              type: integer
            total_tasks:
              type: integer

    TaskExecutionRequest:
      type: object
      required:
        - agent
        - task
      properties:
        agent:
          type: string
          example: "apex:CODE"
        task:
          type: object
          properties:
            type:
              type: string
            parameters:
              type: object
            priority:
              type: string
              enum: [low, medium, high, critical]
```

---

## Performance Optimization

### Caching Strategy
```python
# Redis-based caching for frequently accessed data
class APICache:
    def __init__(self, redis_client):
        self.redis = redis_client
        self.ttls = {
            'agent_list': 300,      # 5 minutes
            'agent_detail': 600,    # 10 minutes
            'workflow_list': 3600,  # 1 hour
            'metrics': 60           # 1 minute
        }
    
    async def get_or_fetch(self, key: str, fetch_func, ttl_type: str = 'default'):
        # Try cache first
        cached = await self.redis.get(f"api_cache:{key}")
        if cached:
            return json.loads(cached)
        
        # Fetch and cache
        data = await fetch_func()
        ttl = self.ttls.get(ttl_type, 300)
        await self.redis.setex(
            f"api_cache:{key}", 
            ttl, 
            json.dumps(data)
        )
        
        return data
```

### Database Query Optimization
```sql
-- Materialized view for API responses
CREATE MATERIALIZED VIEW mv_api_agent_summary AS
SELECT 
    unified_id,
    source_system,
    code,
    name,
    category,
    status,
    success_rate,
    response_time_ms,
    total_tasks,
    JSON_OBJECT(
        'capabilities', (
            SELECT JSON_ARRAYAGG(capability_name)
            FROM unified_agent_capabilities
            WHERE unified_agent_id = ua.unified_id
        )
    ) as capabilities_json
FROM v_unified_agents ua
WHERE status = 'active';

-- Refresh every 5 minutes
CREATE EVENT refresh_api_views
ON SCHEDULE EVERY 5 MINUTE
DO REFRESH MATERIALIZED VIEW mv_api_agent_summary;
```

---

## Monitoring & Analytics

### API Metrics Collection
```python
# Prometheus metrics for API monitoring
from prometheus_client import Counter, Histogram, Gauge

# Request metrics
api_requests_total = Counter(
    'unified_api_requests_total',
    'Total API requests',
    ['method', 'endpoint', 'status']
)

api_request_duration = Histogram(
    'unified_api_request_duration_seconds',
    'API request duration',
    ['method', 'endpoint']
)

# System metrics
active_executions = Gauge(
    'unified_active_executions',
    'Currently active task executions',
    ['system']
)

# Middleware to collect metrics
@app.middleware("http")
async def collect_metrics(request: Request, call_next):
    start_time = time.time()
    
    response = await call_next(request)
    
    duration = time.time() - start_time
    api_requests_total.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    api_request_duration.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
    
    return response
```

---

## Security Considerations

1. **API Key Management**
   - Secure key generation
   - Regular rotation
   - Scope-based permissions

2. **Input Validation**
   - Request schema validation
   - SQL injection prevention
   - XSS protection

3. **Rate Limiting**
   - Per-client limits
   - Endpoint-specific limits
   - DDoS protection

4. **Audit Logging**
   - All API calls logged
   - Sensitive data masked
   - Retention policies

---

## Next Steps

1. **Implementation Priority**
   - Core gateway functionality
   - Legacy system adapters
   - Response standardization
   - Basic authentication

2. **Testing Strategy**
   - Unit tests for handlers
   - Integration tests
   - Load testing
   - Security testing

3. **Documentation**
   - API reference
   - Migration guides
   - Code examples
   - Troubleshooting

4. **Deployment**
   - Docker containerization
   - Kubernetes orchestration
   - CI/CD pipeline
   - Monitoring setup