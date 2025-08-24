# Unified Agent Architecture Design
## Combining APEX, ARIA, and SuperClaude Frameworks

**Version**: 1.0  
**Date**: January 2025  
**Location**: `/mnt/d/MikesDev/.claude/agents/UNIFIED-ARCHITECTURE.md`  
**Database**: `agent_central` (existing MariaDB on port 3306)  
**Web Interface**: `http://localhost/agents/`  

---

## Executive Summary

This architecture unifies three existing agent systems (APEX, ARIA, SuperClaude) into a cohesive platform that maintains backward compatibility while providing enhanced capabilities. The design leverages the existing `agent_central` database with 90+ tables and provides a unified web interface for all agent operations.

### Key Principles
- **Database First**: Use existing `agent_central` schema, extend without breaking
- **Backward Compatible**: All existing systems continue functioning
- **API Consolidation**: Single unified API gateway routing to appropriate backends
- **True Parallelism**: WebSocket-based real-time execution across all agents
- **Unified Interface**: Single web portal aggregating all agent capabilities
- **Progressive Enhancement**: Add new features without disrupting existing ones

---

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Unified Web Interface                            │
│                  http://localhost/agents/                            │
├─────────────────────────────────────────────────────────────────────┤
│                    API Gateway Layer                                 │
│              FastAPI + Legacy PHP Proxy                              │
├──────────────────┬────────────────────┬────────────────────────────┤
│   APEX Engine    │   ARIA Engine      │   SuperClaude Engine       │
│   (FastAPI)      │   (PHP)            │   (Shell/Node.js)          │
├──────────────────┴────────────────────┴────────────────────────────┤
│                  Unified Agent Registry                              │
│                 Agent Discovery & Routing                            │
├─────────────────────────────────────────────────────────────────────┤
│              WebSocket Communication Hub                             │
│           Real-time Agent Coordination                               │
├─────────────────────────────────────────────────────────────────────┤
│                  MariaDB: agent_central                              │
│                    90+ Existing Tables                               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Database Architecture

### Core Schema Design

The existing `agent_central` database contains comprehensive tables. We'll add unified views and procedures without modifying existing structures:

```sql
-- Unified Agent Registry View
CREATE OR REPLACE VIEW v_unified_agents AS
SELECT 
    -- APEX agents
    'apex' as source_system,
    id as agent_id,
    agent_code as code,
    agent_name as name,
    category,
    description,
    status,
    last_active,
    response_time_ms,
    total_tasks,
    success_count
FROM apex_agents
UNION ALL
SELECT 
    -- ARIA agents
    'aria' as source_system,
    id as agent_id,
    agent_name as code,
    agent_description as name,
    agent_type as category,
    capabilities as description,
    status,
    last_seen as last_active,
    avg_response_time as response_time_ms,
    total_executions as total_tasks,
    successful_executions as success_count
FROM agent_registry
UNION ALL
SELECT 
    -- SuperClaude agents
    'superclaude' as source_system,
    id as agent_id,
    command_name as code,
    display_name as name,
    category,
    description,
    'active' as status,
    last_used as last_active,
    0 as response_time_ms,
    execution_count as total_tasks,
    success_count
FROM claude_agent_memory;

-- Unified Task Queue
CREATE OR REPLACE VIEW v_unified_tasks AS
SELECT 
    'apex' as source,
    task_code as unified_task_id,
    agent_id,
    client_id,
    project_id,
    task_type,
    description,
    status,
    priority,
    created_at,
    started_at,
    completed_at,
    execution_time_ms,
    result
FROM apex_tasks
UNION ALL
SELECT 
    'aria' as source,
    CONCAT('aria_', id) as unified_task_id,
    assigned_agent_id as agent_id,
    NULL as client_id,
    project_id,
    task_type,
    task_details as description,
    status,
    priority,
    created_at,
    started_at,
    completed_at,
    execution_time_ms,
    output as result
FROM aria_tasks
UNION ALL
SELECT 
    'agent_central' as source,
    CONCAT('ac_', id) as unified_task_id,
    agent_id,
    NULL as client_id,
    project_id,
    'general' as task_type,
    description,
    status,
    priority,
    created_at,
    started_at,
    completed_at,
    TIMESTAMPDIFF(MILLISECOND, started_at, completed_at) as execution_time_ms,
    result
FROM tasks;

-- Unified Performance Metrics
CREATE OR REPLACE VIEW v_unified_performance AS
SELECT 
    source_system,
    agent_id,
    metric_date,
    SUM(tasks_completed) as tasks_completed,
    AVG(success_rate) as avg_success_rate,
    AVG(response_time_ms) as avg_response_time,
    MIN(response_time_ms) as min_response_time,
    MAX(response_time_ms) as max_response_time
FROM (
    SELECT 'apex' as source_system, agent_id, metric_date, 
           tasks_completed, success_rate, avg_response_time_ms as response_time_ms
    FROM apex_performance
    UNION ALL
    SELECT 'aria' as source_system, agent_id, DATE(recorded_at) as metric_date,
           executions_count as tasks_completed, success_rate, avg_response_time as response_time_ms
    FROM aria_agent_performance
    UNION ALL
    SELECT 'agent_central' as source_system, agent_id, metric_date,
           completed_tasks as tasks_completed, success_rate, avg_execution_time as response_time_ms
    FROM agent_performance
) unified_metrics
GROUP BY source_system, agent_id, metric_date;

-- New Tables for Unified System
CREATE TABLE IF NOT EXISTS unified_agent_capabilities (
    id INT AUTO_INCREMENT PRIMARY KEY,
    agent_code VARCHAR(100) NOT NULL,
    source_system ENUM('apex', 'aria', 'superclaude', 'unified') NOT NULL,
    capability VARCHAR(200) NOT NULL,
    proficiency_level INT DEFAULT 5 CHECK (proficiency_level BETWEEN 1 AND 10),
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_agent_capability (agent_code, source_system, capability),
    INDEX idx_capability (capability),
    INDEX idx_agent_source (agent_code, source_system)
);

CREATE TABLE IF NOT EXISTS unified_execution_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    execution_id VARCHAR(128) UNIQUE NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    agent_code VARCHAR(100) NOT NULL,
    task_type VARCHAR(100),
    input_data JSON,
    output_data JSON,
    status ENUM('queued', 'running', 'completed', 'failed', 'cancelled') NOT NULL,
    error_details TEXT,
    execution_time_ms INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    INDEX idx_execution_status (status, created_at DESC),
    INDEX idx_agent_execution (agent_code, created_at DESC),
    INDEX idx_source_system (source_system, created_at DESC)
) PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION pfuture VALUES LESS THAN MAXVALUE
);

CREATE TABLE IF NOT EXISTS unified_websocket_sessions (
    session_id VARCHAR(128) PRIMARY KEY,
    client_type ENUM('web', 'api', 'agent', 'system') NOT NULL,
    client_identifier VARCHAR(255),
    connected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    metadata JSON,
    INDEX idx_client_type (client_type),
    INDEX idx_heartbeat (last_heartbeat)
);
```

---

## API Architecture

### Unified API Gateway

Located at `/mnt/d/MikesDev/www/agents/api/`, the gateway provides:

```python
# api/main.py - FastAPI Gateway
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import httpx
import asyncio
from typing import Dict, Any

app = FastAPI(title="Unified Agent API", version="1.0")

# CORS for web interface
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Backend routing configuration
BACKEND_ROUTES = {
    "apex": "http://localhost:8001",      # APEX FastAPI
    "aria": "http://localhost/kdp/aria",  # ARIA PHP
    "superclaude": "http://localhost:8002", # SuperClaude Node.js
}

@app.get("/api/agents")
async def list_all_agents():
    """Unified agent listing from all systems"""
    agents = []
    
    # Fetch from database view
    async with get_db() as db:
        result = await db.fetch_all("SELECT * FROM v_unified_agents WHERE status = 'active'")
        agents = [dict(row) for row in result]
    
    return {"agents": agents, "total": len(agents)}

@app.post("/api/execute")
async def execute_task(request: Dict[str, Any]):
    """Unified task execution with intelligent routing"""
    agent_code = request.get("agent_code")
    task_data = request.get("task_data")
    
    # Determine which system handles this agent
    agent_info = await get_agent_info(agent_code)
    if not agent_info:
        raise HTTPException(404, "Agent not found")
    
    # Route to appropriate backend
    backend_url = BACKEND_ROUTES.get(agent_info["source_system"])
    if agent_info["source_system"] == "apex":
        return await execute_apex_task(agent_code, task_data)
    elif agent_info["source_system"] == "aria":
        return await execute_aria_task(agent_code, task_data)
    elif agent_info["source_system"] == "superclaude":
        return await execute_superclaude_command(agent_code, task_data)
    else:
        # New unified agent
        return await execute_unified_task(agent_code, task_data)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """Unified WebSocket for real-time updates"""
    await websocket.accept()
    session_id = str(uuid.uuid4())
    
    # Register session
    await register_websocket_session(session_id, websocket)
    
    try:
        while True:
            data = await websocket.receive_json()
            await handle_websocket_message(session_id, data)
    except WebSocketDisconnect:
        await unregister_websocket_session(session_id)
```

### Legacy System Adapters

```python
# api/adapters/apex_adapter.py
class APEXAdapter:
    def __init__(self):
        self.base_url = "http://localhost:8001"
    
    async def execute_task(self, agent_code: str, task_data: Dict):
        """Adapt unified request to APEX format"""
        apex_request = {
            "agent_code": agent_code,
            "task_type": task_data.get("type", "general"),
            "parameters": task_data.get("parameters", {}),
            "priority": task_data.get("priority", "medium")
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/api/tasks/create",
                json=apex_request
            )
            return response.json()

# api/adapters/aria_adapter.py
class ARIAAdapter:
    def __init__(self):
        self.base_url = "http://localhost/kdp/aria/api"
    
    async def execute_task(self, agent_name: str, task_data: Dict):
        """Adapt unified request to ARIA format"""
        # ARIA uses different field names
        aria_request = {
            "agent_name": agent_name,
            "action": task_data.get("type"),
            "params": json.dumps(task_data.get("parameters", {}))
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/agent_execute.php",
                data=aria_request  # PHP expects form data
            )
            return response.json()

# api/adapters/superclaude_adapter.py
class SuperClaudeAdapter:
    def __init__(self):
        self.base_url = "http://localhost:8002"
    
    async def execute_command(self, command_name: str, args: Dict):
        """Execute SuperClaude command"""
        sc_request = {
            "command": command_name,
            "args": args,
            "context": {
                "cwd": args.get("working_directory", "/mnt/d/MikesDev"),
                "env": args.get("environment", {})
            }
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/execute",
                json=sc_request
            )
            return response.json()
```

---

## Web Interface Architecture

### Unified Dashboard

Located at `/mnt/d/MikesDev/www/agents/`, built with React:

```javascript
// frontend/src/App.jsx
import React, { useState, useEffect } from 'react';
import { AgentRegistry } from './components/AgentRegistry';
import { TaskQueue } from './components/TaskQueue';
import { PerformanceDashboard } from './components/PerformanceDashboard';
import { ExecutionPanel } from './components/ExecutionPanel';
import { WebSocketProvider } from './contexts/WebSocketContext';

function App() {
  return (
    <WebSocketProvider url="ws://localhost/agents/ws">
      <div className="unified-agent-dashboard">
        <header>
          <h1>Unified Agent System</h1>
          <SystemStatus />
        </header>
        
        <main>
          <div className="grid grid-cols-12 gap-4">
            {/* Agent Registry - Shows all agents from all systems */}
            <div className="col-span-3">
              <AgentRegistry />
            </div>
            
            {/* Task Execution Panel */}
            <div className="col-span-6">
              <ExecutionPanel />
              <TaskQueue />
            </div>
            
            {/* Performance Metrics */}
            <div className="col-span-3">
              <PerformanceDashboard />
            </div>
          </div>
        </main>
      </div>
    </WebSocketProvider>
  );
}

// frontend/src/components/AgentRegistry.jsx
export function AgentRegistry() {
  const [agents, setAgents] = useState([]);
  const [filter, setFilter] = useState({ system: 'all', category: 'all' });
  
  useEffect(() => {
    fetchAgents();
    const interval = setInterval(fetchAgents, 5000); // Auto-refresh
    return () => clearInterval(interval);
  }, [filter]);
  
  const fetchAgents = async () => {
    const response = await fetch('/agents/api/agents?' + new URLSearchParams(filter));
    const data = await response.json();
    setAgents(data.agents);
  };
  
  return (
    <div className="agent-registry">
      <h2>Agent Registry</h2>
      
      <div className="filters">
        <select onChange={(e) => setFilter({...filter, system: e.target.value})}>
          <option value="all">All Systems</option>
          <option value="apex">APEX</option>
          <option value="aria">ARIA</option>
          <option value="superclaude">SuperClaude</option>
        </select>
      </div>
      
      <div className="agent-list">
        {agents.map(agent => (
          <AgentCard key={`${agent.source_system}-${agent.code}`} agent={agent} />
        ))}
      </div>
    </div>
  );
}

// frontend/src/components/ExecutionPanel.jsx
export function ExecutionPanel() {
  const [selectedAgent, setSelectedAgent] = useState(null);
  const [taskForm, setTaskForm] = useState({});
  const { sendMessage } = useWebSocket();
  
  const executeTask = async () => {
    const response = await fetch('/agents/api/execute', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        agent_code: selectedAgent.code,
        task_data: taskForm
      })
    });
    
    const result = await response.json();
    
    // Notify via WebSocket for real-time updates
    sendMessage({
      type: 'task_executed',
      data: result
    });
  };
  
  return (
    <div className="execution-panel">
      <h2>Task Execution</h2>
      {/* Task form and execution interface */}
    </div>
  );
}
```

---

## Agent Registry Consolidation

### Unified Agent Discovery

```python
# services/agent_discovery.py
class UnifiedAgentDiscovery:
    def __init__(self):
        self.cache = {}
        self.discovery_interval = 60  # seconds
        
    async def discover_all_agents(self):
        """Discover agents from all systems"""
        agents = {}
        
        # 1. APEX Agents (from database)
        apex_agents = await self.discover_apex_agents()
        agents.update({f"apex:{a['code']}": a for a in apex_agents})
        
        # 2. ARIA Agents (from database)
        aria_agents = await self.discover_aria_agents()
        agents.update({f"aria:{a['name']}": a for a in aria_agents})
        
        # 3. SuperClaude Agents (from filesystem)
        sc_agents = await self.discover_superclaude_agents()
        agents.update({f"sc:{a['command']}": a for a in sc_agents})
        
        # 4. New Unified Agents
        unified_agents = await self.discover_unified_agents()
        agents.update({f"unified:{a['code']}": a for a in unified_agents})
        
        self.cache = agents
        return agents
    
    async def discover_superclaude_agents(self):
        """Scan SuperClaude command directories"""
        agents = []
        base_path = Path("~/.claude/commands").expanduser()
        
        for category_dir in base_path.iterdir():
            if category_dir.is_dir():
                for cmd_file in category_dir.glob("*.md"):
                    agent_info = self.parse_superclaude_command(cmd_file)
                    if agent_info:
                        agents.append(agent_info)
        
        return agents
    
    def parse_superclaude_command(self, cmd_file: Path):
        """Parse SuperClaude command file"""
        content = cmd_file.read_text()
        # Extract metadata from markdown
        return {
            "command": cmd_file.stem,
            "category": cmd_file.parent.name,
            "description": self.extract_description(content),
            "capabilities": self.extract_capabilities(content)
        }
```

### Agent Capability Mapping

```python
# services/capability_mapper.py
class CapabilityMapper:
    """Maps agent capabilities across different systems"""
    
    CAPABILITY_MAPPINGS = {
        # APEX -> Unified
        "code": ["development", "programming", "implementation"],
        "architect": ["system-design", "architecture", "planning"],
        "qa": ["testing", "quality-assurance", "validation"],
        
        # ARIA -> Unified
        "coder": ["development", "programming"],
        "reviewer": ["code-review", "quality-check"],
        "delegator": ["task-distribution", "coordination"],
        
        # SuperClaude -> Unified
        "swarm-init": ["multi-agent", "coordination", "orchestration"],
        "code": ["development", "implementation"],
        "architect": ["design", "planning", "architecture"]
    }
    
    def normalize_capabilities(self, agent_info: Dict) -> List[str]:
        """Normalize capabilities across systems"""
        source = agent_info.get("source_system")
        original_caps = agent_info.get("capabilities", [])
        
        normalized = set()
        for cap in original_caps:
            if cap in self.CAPABILITY_MAPPINGS:
                normalized.update(self.CAPABILITY_MAPPINGS[cap])
            else:
                normalized.add(cap)
        
        return list(normalized)
```

---

## Parallel Execution Engine

### WebSocket-Based Orchestration

```python
# services/parallel_executor.py
class ParallelExecutionEngine:
    def __init__(self):
        self.execution_pool = asyncio.Queue(maxsize=1000)
        self.workers = []
        self.results = {}
        
    async def start(self, num_workers=10):
        """Start parallel execution workers"""
        for i in range(num_workers):
            worker = asyncio.create_task(self.worker_loop(i))
            self.workers.append(worker)
    
    async def worker_loop(self, worker_id: int):
        """Worker process for parallel execution"""
        while True:
            try:
                task = await self.execution_pool.get()
                result = await self.execute_single_task(task)
                await self.broadcast_result(task['id'], result)
            except Exception as e:
                logging.error(f"Worker {worker_id} error: {e}")
    
    async def submit_task(self, task: Dict) -> str:
        """Submit task for parallel execution"""
        task_id = str(uuid.uuid4())
        task['id'] = task_id
        task['submitted_at'] = datetime.now()
        
        # Store in database
        await self.store_task_submission(task)
        
        # Add to execution queue
        await self.execution_pool.put(task)
        
        return task_id
    
    async def execute_single_task(self, task: Dict):
        """Execute a single task with the appropriate agent"""
        agent_code = task['agent_code']
        agent_info = await get_agent_info(agent_code)
        
        # Route to appropriate executor
        if agent_info['source_system'] == 'apex':
            return await self.execute_apex_task(task)
        elif agent_info['source_system'] == 'aria':
            return await self.execute_aria_task(task)
        elif agent_info['source_system'] == 'superclaude':
            return await self.execute_superclaude_task(task)
        else:
            return await self.execute_unified_task(task)
    
    async def broadcast_result(self, task_id: str, result: Dict):
        """Broadcast execution result via WebSocket"""
        message = {
            "type": "task_complete",
            "task_id": task_id,
            "result": result,
            "timestamp": datetime.now().isoformat()
        }
        
        await websocket_manager.broadcast(message)

# services/task_coordinator.py
class TaskCoordinator:
    """Coordinates complex multi-agent workflows"""
    
    def __init__(self, executor: ParallelExecutionEngine):
        self.executor = executor
        self.workflows = {}
        
    async def execute_workflow(self, workflow_definition: Dict):
        """Execute a multi-step workflow with dependencies"""
        workflow_id = str(uuid.uuid4())
        workflow = {
            "id": workflow_id,
            "definition": workflow_definition,
            "status": "running",
            "steps": {},
            "results": {}
        }
        
        self.workflows[workflow_id] = workflow
        
        # Build dependency graph
        graph = self.build_dependency_graph(workflow_definition)
        
        # Execute in parallel respecting dependencies
        await self.execute_graph(workflow_id, graph)
        
        return workflow_id
    
    async def execute_graph(self, workflow_id: str, graph: Dict):
        """Execute workflow graph with proper parallelization"""
        completed = set()
        
        while len(completed) < len(graph):
            # Find tasks ready to execute
            ready_tasks = [
                task_id for task_id, deps in graph.items()
                if task_id not in completed and all(d in completed for d in deps)
            ]
            
            # Execute ready tasks in parallel
            if ready_tasks:
                tasks = []
                for task_id in ready_tasks:
                    task_def = self.workflows[workflow_id]["definition"]["steps"][task_id]
                    task = asyncio.create_task(self.executor.submit_task(task_def))
                    tasks.append((task_id, task))
                
                # Wait for completion
                for task_id, task in tasks:
                    result = await task
                    self.workflows[workflow_id]["results"][task_id] = result
                    completed.add(task_id)
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
1. **Database Schema Updates**
   - Create unified views in `agent_central`
   - Add new unified tables
   - Set up stored procedures for cross-system queries

2. **API Gateway Setup**
   - Deploy FastAPI gateway at `/agents/api/`
   - Implement legacy system adapters
   - Set up WebSocket infrastructure

3. **Basic Web Interface**
   - Create React app structure
   - Implement agent registry view
   - Basic task execution interface

### Phase 2: Integration (Week 2)
1. **Agent Discovery**
   - Implement unified discovery service
   - Create capability mapping system
   - Build agent registry cache

2. **Parallel Execution**
   - Implement execution engine
   - Create task coordinator
   - Set up worker pools

3. **Real-time Updates**
   - WebSocket integration
   - Live dashboard updates
   - Activity feed implementation

### Phase 3: Enhancement (Week 3)
1. **Advanced Features**
   - Workflow builder UI
   - Performance analytics
   - Agent collaboration tools

2. **Optimization**
   - Query optimization
   - Caching strategies
   - Load balancing

3. **Testing & Documentation**
   - Integration tests
   - Performance benchmarks
   - User documentation

### Phase 4: Migration (Week 4)
1. **Data Migration**
   - Migrate existing workflows
   - Update agent configurations
   - Preserve historical data

2. **Cutover Planning**
   - Phased migration strategy
   - Rollback procedures
   - Monitoring setup

3. **Launch**
   - Deploy to production
   - Monitor performance
   - Gather feedback

---

## Technical Implementation Details

### Directory Structure
```
/mnt/d/MikesDev/www/agents/
├── api/
│   ├── main.py                 # FastAPI gateway
│   ├── adapters/              # Legacy system adapters
│   ├── routers/               # API endpoints
│   └── services/              # Business logic
├── frontend/
│   ├── src/
│   │   ├── components/        # React components
│   │   ├── contexts/          # React contexts
│   │   ├── hooks/             # Custom hooks
│   │   └── services/          # API clients
│   └── public/
├── shared/
│   ├── schemas/               # Shared data models
│   ├── utils/                 # Shared utilities
│   └── constants/             # Configuration
├── scripts/
│   ├── setup.sh              # Initial setup
│   ├── migrate.py            # Data migration
│   └── test.py               # Integration tests
└── docs/
    ├── API.md                # API documentation
    ├── SETUP.md              # Setup guide
    └── USAGE.md              # User guide
```

### Configuration Management
```python
# config/unified_config.py
class UnifiedConfig:
    # Database
    DB_HOST = "127.0.0.1"
    DB_PORT = 3306
    DB_NAME = "agent_central"
    DB_USER = "root"
    DB_PASS = "mike"
    
    # API Endpoints
    APEX_API = "http://localhost:8001"
    ARIA_API = "http://localhost/kdp/aria"
    SUPERCLAUDE_API = "http://localhost:8002"
    
    # WebSocket
    WS_PORT = 8080
    WS_HEARTBEAT_INTERVAL = 30
    
    # Performance
    WORKER_COUNT = 10
    TASK_QUEUE_SIZE = 1000
    CACHE_TTL = 300
    
    # Features
    ENABLE_LEGACY_SUPPORT = True
    ENABLE_PERFORMANCE_TRACKING = True
    ENABLE_WORKFLOW_ENGINE = True
```

---

## Security & Performance

### Security Measures
1. **API Authentication** (Phase 2)
   - JWT tokens for API access
   - Role-based permissions
   - Audit logging

2. **Data Protection**
   - Encrypted sensitive data
   - SQL injection prevention
   - XSS protection

### Performance Optimization
1. **Database**
   - Indexed views for fast queries
   - Connection pooling
   - Query result caching

2. **API**
   - Response caching
   - Async execution
   - Load balancing

3. **Frontend**
   - Code splitting
   - Lazy loading
   - WebSocket connection pooling

---

## Monitoring & Maintenance

### Monitoring Setup
```python
# monitoring/metrics.py
class UnifiedMetrics:
    def __init__(self):
        self.prometheus_client = PrometheusClient()
        
    async def track_execution(self, agent_code: str, duration_ms: int, status: str):
        self.prometheus_client.histogram(
            'agent_execution_duration',
            duration_ms,
            labels={'agent': agent_code, 'status': status}
        )
    
    async def track_api_request(self, endpoint: str, duration_ms: int, status_code: int):
        self.prometheus_client.histogram(
            'api_request_duration',
            duration_ms,
            labels={'endpoint': endpoint, 'status': status_code}
        )
```

### Health Checks
```python
@app.get("/health")
async def health_check():
    checks = {
        "database": await check_database(),
        "apex": await check_apex_connection(),
        "aria": await check_aria_connection(),
        "superclaude": await check_superclaude_connection(),
        "websocket": await check_websocket_server()
    }
    
    status = "healthy" if all(checks.values()) else "degraded"
    return {"status": status, "checks": checks}
```

---

## Conclusion

This unified architecture provides:
1. **Seamless Integration** - All three systems work together
2. **Backward Compatibility** - Existing functionality preserved
3. **Enhanced Capabilities** - New features without disruption
4. **True Parallelism** - WebSocket-based real-time execution
5. **Unified Interface** - Single point of control
6. **Scalable Design** - Ready for future growth

The implementation maintains the strengths of each system while providing a cohesive platform for all agent operations.