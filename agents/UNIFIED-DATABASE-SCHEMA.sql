-- Unified Agent System Database Schema
-- Extends existing agent_central database without breaking changes
-- Version: 1.0
-- Date: January 2025

USE agent_central;

-- ============================================
-- UNIFIED VIEWS FOR CROSS-SYSTEM VISIBILITY
-- ============================================

-- Unified Agent Registry View
-- Combines agents from APEX, ARIA, and agent_registry tables
CREATE OR REPLACE VIEW v_unified_agents AS
SELECT 
    -- APEX agents (from apex_agents table)
    CONCAT('apex:', a.agent_code) as unified_id,
    'apex' as source_system,
    a.id as source_agent_id,
    a.agent_code as code,
    a.agent_name as name,
    a.category,
    a.description,
    a.status,
    a.last_active,
    a.response_time_ms,
    a.total_tasks,
    a.success_count,
    ROUND(CASE WHEN a.total_tasks > 0 THEN (a.success_count * 100.0 / a.total_tasks) ELSE 0 END, 2) as success_rate,
    a.created_at,
    a.updated_at
FROM apex_agents a
UNION ALL
SELECT 
    -- ARIA agents (from agent_registry table)
    CONCAT('aria:', ar.agent_name) as unified_id,
    'aria' as source_system,
    ar.id as source_agent_id,
    ar.agent_name as code,
    ar.agent_name as name,
    ar.agent_type as category,
    ar.capabilities as description,
    ar.status,
    ar.last_seen as last_active,
    ar.avg_response_time as response_time_ms,
    ar.total_executions as total_tasks,
    ar.successful_executions as success_count,
    ROUND(CASE WHEN ar.total_executions > 0 THEN (ar.successful_executions * 100.0 / ar.total_executions) ELSE 0 END, 2) as success_rate,
    ar.created_at,
    ar.updated_at
FROM agent_registry ar
UNION ALL
SELECT 
    -- SuperClaude agents (from claude_agent_memory)
    CONCAT('superclaude:', cam.command_name) as unified_id,
    'superclaude' as source_system,
    cam.id as source_agent_id,
    cam.command_name as code,
    cam.display_name as name,
    cam.category,
    cam.description,
    'active' as status,
    cam.last_used as last_active,
    0 as response_time_ms,
    cam.execution_count as total_tasks,
    cam.success_count,
    ROUND(CASE WHEN cam.execution_count > 0 THEN (cam.success_count * 100.0 / cam.execution_count) ELSE 0 END, 2) as success_rate,
    cam.created_at,
    cam.updated_at
FROM claude_agent_memory cam;

-- Unified Task Queue View
-- Combines tasks from all systems
CREATE OR REPLACE VIEW v_unified_task_queue AS
SELECT 
    -- APEX tasks
    CONCAT('apex:', t.task_code) as unified_task_id,
    'apex' as source_system,
    t.id as source_task_id,
    t.task_code,
    CONCAT('apex:', t.agent_id) as unified_agent_id,
    t.client_id,
    t.project_id,
    t.task_type,
    t.description,
    t.status,
    t.priority,
    t.created_at,
    t.started_at,
    t.completed_at,
    t.execution_time_ms,
    t.result,
    t.error_message
FROM apex_tasks t
UNION ALL
SELECT 
    -- ARIA tasks
    CONCAT('aria:', at.id) as unified_task_id,
    'aria' as source_system,
    at.id as source_task_id,
    CONCAT('ARIA-', at.id) as task_code,
    CONCAT('aria:', at.assigned_agent_id) as unified_agent_id,
    NULL as client_id,
    at.project_id,
    at.task_type,
    at.task_details as description,
    at.status,
    at.priority,
    at.created_at,
    at.started_at,
    at.completed_at,
    at.execution_time_ms,
    at.output as result,
    at.error_log as error_message
FROM aria_tasks at
UNION ALL
SELECT 
    -- General tasks from tasks table
    CONCAT('general:', t.id) as unified_task_id,
    'general' as source_system,
    t.id as source_task_id,
    CONCAT('TASK-', t.id) as task_code,
    CONCAT('general:', t.agent_id) as unified_agent_id,
    NULL as client_id,
    t.project_id,
    'general' as task_type,
    t.description,
    t.status,
    t.priority,
    t.created_at,
    t.started_at,
    t.completed_at,
    TIMESTAMPDIFF(MILLISECOND, t.started_at, t.completed_at) as execution_time_ms,
    t.result,
    NULL as error_message
FROM tasks t;

-- Unified Performance Metrics View
CREATE OR REPLACE VIEW v_unified_performance_metrics AS
SELECT 
    DATE(metric_timestamp) as metric_date,
    HOUR(metric_timestamp) as metric_hour,
    source_system,
    unified_agent_id,
    COUNT(*) as task_count,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count,
    AVG(execution_time_ms) as avg_execution_time,
    MIN(execution_time_ms) as min_execution_time,
    MAX(execution_time_ms) as max_execution_time,
    ROUND(SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as success_rate
FROM (
    SELECT 
        created_at as metric_timestamp,
        source_system,
        unified_agent_id,
        status,
        execution_time_ms
    FROM v_unified_task_queue
    WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
) metrics
GROUP BY DATE(metric_timestamp), HOUR(metric_timestamp), source_system, unified_agent_id;

-- Unified Agent Workload View
CREATE OR REPLACE VIEW v_unified_agent_workload AS
SELECT 
    ua.unified_id,
    ua.source_system,
    ua.code as agent_code,
    ua.name as agent_name,
    ua.category,
    ua.status as agent_status,
    COUNT(DISTINCT CASE WHEN t.status = 'pending' THEN t.unified_task_id END) as pending_tasks,
    COUNT(DISTINCT CASE WHEN t.status = 'in_progress' THEN t.unified_task_id END) as active_tasks,
    COUNT(DISTINCT CASE WHEN t.status = 'completed' AND DATE(t.completed_at) = CURDATE() THEN t.unified_task_id END) as completed_today,
    AVG(CASE WHEN t.status = 'completed' AND DATE(t.completed_at) = CURDATE() THEN t.execution_time_ms END) as avg_time_today
FROM v_unified_agents ua
LEFT JOIN v_unified_task_queue t ON ua.unified_id = t.unified_agent_id
GROUP BY ua.unified_id, ua.source_system, ua.code, ua.name, ua.category, ua.status;

-- ============================================
-- NEW UNIFIED SYSTEM TABLES
-- ============================================

-- Unified Agent Capabilities
-- Maps capabilities across all agent systems
CREATE TABLE IF NOT EXISTS unified_agent_capabilities (
    id INT AUTO_INCREMENT PRIMARY KEY,
    unified_agent_id VARCHAR(200) NOT NULL,
    capability_name VARCHAR(100) NOT NULL,
    capability_category VARCHAR(50),
    proficiency_level INT DEFAULT 5 CHECK (proficiency_level BETWEEN 1 AND 10),
    verified BOOLEAN DEFAULT FALSE,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_agent_capability (unified_agent_id, capability_name),
    INDEX idx_capability (capability_name),
    INDEX idx_category (capability_category),
    INDEX idx_proficiency (proficiency_level DESC)
);

-- Unified Execution History
-- Tracks all executions across systems with detailed metrics
CREATE TABLE IF NOT EXISTS unified_execution_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    execution_id VARCHAR(128) UNIQUE NOT NULL,
    unified_agent_id VARCHAR(200) NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    task_type VARCHAR(100),
    input_hash VARCHAR(64), -- For deduplication
    input_data JSON,
    output_data JSON,
    status ENUM('queued', 'running', 'completed', 'failed', 'cancelled', 'timeout') NOT NULL,
    error_code VARCHAR(50),
    error_message TEXT,
    execution_time_ms INT,
    cpu_usage_percent DECIMAL(5,2),
    memory_usage_mb INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    INDEX idx_agent_executions (unified_agent_id, created_at DESC),
    INDEX idx_status_time (status, created_at DESC),
    INDEX idx_task_type (task_type, created_at DESC),
    INDEX idx_input_hash (input_hash),
    INDEX idx_execution_time (execution_time_ms)
) PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION pfuture VALUES LESS THAN MAXVALUE
);

-- Unified Workflow Definitions
-- Stores multi-agent workflow templates
CREATE TABLE IF NOT EXISTS unified_workflows (
    id INT AUTO_INCREMENT PRIMARY KEY,
    workflow_code VARCHAR(100) UNIQUE NOT NULL,
    workflow_name VARCHAR(200) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    workflow_definition JSON NOT NULL, -- DAG structure
    input_schema JSON,
    output_schema JSON,
    estimated_duration_ms INT,
    is_active BOOLEAN DEFAULT TRUE,
    version INT DEFAULT 1,
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_active (is_active),
    FULLTEXT idx_search (workflow_name, description)
);

-- Unified Workflow Executions
-- Tracks workflow execution instances
CREATE TABLE IF NOT EXISTS unified_workflow_executions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    execution_id VARCHAR(128) UNIQUE NOT NULL,
    workflow_id INT NOT NULL,
    status ENUM('pending', 'running', 'completed', 'failed', 'cancelled') NOT NULL,
    input_data JSON,
    output_data JSON,
    execution_graph JSON, -- Current state of DAG execution
    total_steps INT,
    completed_steps INT,
    failed_steps INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    total_duration_ms INT,
    FOREIGN KEY (workflow_id) REFERENCES unified_workflows(id),
    INDEX idx_workflow_status (workflow_id, status),
    INDEX idx_created (created_at DESC)
);

-- Unified Agent Collaboration
-- Tracks agent-to-agent interactions
CREATE TABLE IF NOT EXISTS unified_agent_collaboration (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    requesting_agent_id VARCHAR(200) NOT NULL,
    responding_agent_id VARCHAR(200) NOT NULL,
    collaboration_type ENUM('delegation', 'consultation', 'review', 'handoff', 'parallel') NOT NULL,
    task_reference VARCHAR(200),
    request_data JSON,
    response_data JSON,
    status ENUM('pending', 'accepted', 'completed', 'rejected') NOT NULL,
    response_time_ms INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMP NULL,
    INDEX idx_requesting (requesting_agent_id, created_at DESC),
    INDEX idx_responding (responding_agent_id, created_at DESC),
    INDEX idx_type_status (collaboration_type, status)
);

-- WebSocket Session Management
CREATE TABLE IF NOT EXISTS unified_websocket_sessions (
    session_id VARCHAR(128) PRIMARY KEY,
    client_type ENUM('web', 'api', 'agent', 'system', 'monitoring') NOT NULL,
    client_identifier VARCHAR(255),
    client_ip VARCHAR(45),
    connected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    subscriptions JSON, -- List of event types subscribed to
    metadata JSON,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_client_type (client_type),
    INDEX idx_heartbeat (last_heartbeat),
    INDEX idx_active (is_active)
);

-- Unified System Events
-- Central event log for all systems
CREATE TABLE IF NOT EXISTS unified_system_events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_id VARCHAR(128) UNIQUE NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    severity ENUM('debug', 'info', 'warning', 'error', 'critical') NOT NULL,
    category VARCHAR(50),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    affected_agents JSON, -- List of affected agent IDs
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by VARCHAR(100),
    acknowledged_at TIMESTAMP NULL,
    INDEX idx_type_time (event_type, created_at DESC),
    INDEX idx_severity_time (severity, created_at DESC),
    INDEX idx_source (source_system, created_at DESC),
    FULLTEXT idx_event_search (title, description)
);

-- Performance Optimization Cache
-- High-performance cache for frequently accessed data
CREATE TABLE IF NOT EXISTS unified_performance_cache (
    cache_key VARCHAR(255) PRIMARY KEY,
    cache_type ENUM('agent_info', 'metrics', 'workflow', 'config') NOT NULL,
    cache_data JSON NOT NULL,
    ttl_seconds INT DEFAULT 300,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP GENERATED ALWAYS AS (DATE_ADD(created_at, INTERVAL ttl_seconds SECOND)) STORED,
    hit_count INT DEFAULT 0,
    last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_type (cache_type),
    INDEX idx_expires (expires_at)
) ENGINE=MEMORY;

-- ============================================
-- STORED PROCEDURES FOR UNIFIED OPERATIONS
-- ============================================

DELIMITER //

-- Get unified agent information with capabilities
CREATE PROCEDURE sp_get_unified_agent(
    IN p_unified_agent_id VARCHAR(200)
)
BEGIN
    -- Get agent info
    SELECT * FROM v_unified_agents WHERE unified_id = p_unified_agent_id;
    
    -- Get capabilities
    SELECT * FROM unified_agent_capabilities 
    WHERE unified_agent_id = p_unified_agent_id
    ORDER BY proficiency_level DESC;
    
    -- Get recent performance
    SELECT * FROM v_unified_performance_metrics
    WHERE unified_agent_id = p_unified_agent_id
    AND metric_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    ORDER BY metric_date DESC, metric_hour DESC;
END//

-- Submit unified task
CREATE PROCEDURE sp_submit_unified_task(
    IN p_agent_id VARCHAR(200),
    IN p_task_type VARCHAR(100),
    IN p_input_data JSON,
    IN p_priority VARCHAR(20),
    OUT p_execution_id VARCHAR(128)
)
BEGIN
    DECLARE v_execution_id VARCHAR(128);
    DECLARE v_source_system VARCHAR(50);
    
    -- Generate execution ID
    SET v_execution_id = UUID();
    SET p_execution_id = v_execution_id;
    
    -- Determine source system
    SET v_source_system = SUBSTRING_INDEX(p_agent_id, ':', 1);
    
    -- Insert into execution history
    INSERT INTO unified_execution_history (
        execution_id, unified_agent_id, source_system, 
        task_type, input_data, status, created_at
    ) VALUES (
        v_execution_id, p_agent_id, v_source_system,
        p_task_type, p_input_data, 'queued', NOW()
    );
    
    -- Log system event
    INSERT INTO unified_system_events (
        event_id, event_type, source_system, severity,
        title, affected_agents, created_at
    ) VALUES (
        UUID(), 'task_submitted', 'unified', 'info',
        CONCAT('Task submitted to ', p_agent_id),
        JSON_ARRAY(p_agent_id), NOW()
    );
END//

-- Update task execution status
CREATE PROCEDURE sp_update_execution_status(
    IN p_execution_id VARCHAR(128),
    IN p_status VARCHAR(20),
    IN p_output_data JSON,
    IN p_error_message TEXT
)
BEGIN
    DECLARE v_start_time TIMESTAMP;
    DECLARE v_execution_ms INT;
    
    -- Get start time
    SELECT started_at INTO v_start_time 
    FROM unified_execution_history 
    WHERE execution_id = p_execution_id;
    
    -- Calculate execution time if completing
    IF p_status IN ('completed', 'failed', 'cancelled') THEN
        SET v_execution_ms = TIMESTAMPDIFF(MILLISECOND, v_start_time, NOW());
    END IF;
    
    -- Update execution record
    UPDATE unified_execution_history
    SET 
        status = p_status,
        output_data = p_output_data,
        error_message = p_error_message,
        started_at = CASE WHEN p_status = 'running' THEN NOW() ELSE started_at END,
        completed_at = CASE WHEN p_status IN ('completed', 'failed', 'cancelled') THEN NOW() ELSE NULL END,
        execution_time_ms = v_execution_ms
    WHERE execution_id = p_execution_id;
END//

-- Get agent recommendations for a task
CREATE FUNCTION fn_recommend_agents(
    p_required_capabilities JSON,
    p_limit INT
)
RETURNS JSON
READS SQL DATA
BEGIN
    DECLARE v_recommendations JSON DEFAULT JSON_ARRAY();
    DECLARE v_agent_id VARCHAR(200);
    DECLARE v_score DECIMAL(5,2);
    DECLARE done INT DEFAULT FALSE;
    
    DECLARE cur CURSOR FOR
        SELECT 
            ua.unified_id,
            (
                ua.success_rate * 0.3 +
                (100 - (ua.response_time_ms / 1000)) * 0.3 +
                COALESCE(cap_score.score, 0) * 0.4
            ) as recommendation_score
        FROM v_unified_agents ua
        LEFT JOIN (
            SELECT 
                unified_agent_id,
                AVG(proficiency_level) * 10 as score
            FROM unified_agent_capabilities
            WHERE capability_name IN (
                SELECT value FROM JSON_TABLE(
                    p_required_capabilities, 
                    '$[*]' COLUMNS(value VARCHAR(100) PATH '$')
                ) AS jt
            )
            GROUP BY unified_agent_id
        ) cap_score ON ua.unified_id = cap_score.unified_agent_id
        WHERE ua.status = 'active'
        ORDER BY recommendation_score DESC
        LIMIT p_limit;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN cur;
    
    read_loop: LOOP
        FETCH cur INTO v_agent_id, v_score;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        SET v_recommendations = JSON_ARRAY_APPEND(
            v_recommendations, 
            '$', 
            JSON_OBJECT('agent_id', v_agent_id, 'score', v_score)
        );
    END LOOP;
    
    CLOSE cur;
    
    RETURN v_recommendations;
END//

DELIMITER ;

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

-- Composite indexes for common queries
CREATE INDEX idx_unified_active_agents ON v_unified_agents(status, category, success_rate DESC);
CREATE INDEX idx_unified_recent_tasks ON v_unified_task_queue(created_at DESC, status);
CREATE INDEX idx_execution_lookup ON unified_execution_history(execution_id, status);

-- ============================================
-- INITIAL DATA POPULATION
-- ============================================

-- Populate unified capabilities for existing agents
INSERT INTO unified_agent_capabilities (unified_agent_id, capability_name, capability_category, proficiency_level)
SELECT DISTINCT
    CONCAT('apex:', agent_code) as unified_agent_id,
    CASE 
        WHEN category = 'technical' THEN 'programming'
        WHEN category = 'creative' THEN 'design'
        WHEN category = 'revenue' THEN 'sales'
        ELSE category
    END as capability_name,
    category as capability_category,
    8 as proficiency_level
FROM apex_agents
WHERE status = 'active';

-- Sample workflow definitions
INSERT INTO unified_workflows (workflow_code, workflow_name, description, category, workflow_definition)
VALUES
('code_review_workflow', 'Code Review Workflow', 'Multi-agent code review process', 'development', 
    JSON_OBJECT(
        'steps', JSON_ARRAY(
            JSON_OBJECT('id', 'analyze', 'agent', 'apex:CODE', 'action', 'analyze_code'),
            JSON_OBJECT('id', 'security', 'agent', 'apex:SECURITY', 'action', 'security_scan', 'depends_on', JSON_ARRAY('analyze')),
            JSON_OBJECT('id', 'quality', 'agent', 'apex:QA', 'action', 'quality_check', 'depends_on', JSON_ARRAY('analyze')),
            JSON_OBJECT('id', 'review', 'agent', 'aria:reviewer', 'action', 'final_review', 'depends_on', JSON_ARRAY('security', 'quality'))
        )
    )
),
('customer_onboarding', 'Customer Onboarding', 'Complete customer onboarding workflow', 'customer', 
    JSON_OBJECT(
        'steps', JSON_ARRAY(
            JSON_OBJECT('id', 'setup', 'agent', 'apex:ONBOARD', 'action', 'account_setup'),
            JSON_OBJECT('id', 'training', 'agent', 'apex:SUCCESS', 'action', 'schedule_training', 'depends_on', JSON_ARRAY('setup')),
            JSON_OBJECT('id', 'followup', 'agent', 'apex:SUPPORT', 'action', 'initial_followup', 'depends_on', JSON_ARRAY('training'))
        )
    )
);

-- ============================================
-- MAINTENANCE PROCEDURES
-- ============================================

-- Event to clean up old data
DELIMITER //
CREATE EVENT IF NOT EXISTS evt_unified_cleanup
ON SCHEDULE EVERY 1 DAY
STARTS '2025-01-01 02:00:00'
DO
BEGIN
    -- Clean old WebSocket sessions
    DELETE FROM unified_websocket_sessions 
    WHERE last_heartbeat < DATE_SUB(NOW(), INTERVAL 1 DAY);
    
    -- Archive old execution history
    DELETE FROM unified_execution_history 
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY)
    AND status IN ('completed', 'failed', 'cancelled');
    
    -- Clean expired cache
    DELETE FROM unified_performance_cache 
    WHERE expires_at < NOW();
    
    -- Clean old events
    DELETE FROM unified_system_events
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
    AND severity IN ('debug', 'info');
END//
DELIMITER ;

-- Enable event scheduler if not already enabled
SET GLOBAL event_scheduler = ON;