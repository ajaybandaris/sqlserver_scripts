-- Get overall server-level WAIT staticstics

SELECT 
    wait_type,
    waiting_tasks_count,
    wait_time_ms / 1000.0 AS wait_time_seconds,
    100.0 * wait_time_ms / SUM(wait_time_ms) OVER() AS wait_pct
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE',
    'SLEEP_TASK','SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH',
    'WAITFOR','LOGMGR_QUEUE','CHECKPOINT_QUEUE',
    'REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT',
    'XE_DISPATCHER_WAIT','BROKER_TO_FLUSH','BROKER_TASK_STOP',
    'CLR_MANUAL_EVENT','CLR_AUTO_EVENT','DISPATCHER_QUEUE_SEMAPHORE'
)
ORDER BY wait_time_ms DESC;


-- Active requests + WAITs

SELECT 
    r.session_id,
    r.status,
    r.wait_type,
    r.wait_time,
    r.blocking_session_id,
    r.cpu_time,
    r.total_elapsed_time,
    t.text AS running_query
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.wait_type IS NOT NULL
ORDER BY r.wait_time DESC;

-- user-session level WAITS

SELECT 
    s.session_id,
    s.login_name,
    s.host_name,
    w.wait_type,
    w.wait_duration_ms,
    w.resource_description
FROM sys.dm_os_waiting_tasks w
JOIN sys.dm_exec_sessions s 
    ON w.session_id = s.session_id
ORDER BY w.wait_duration_ms DESC;

-- Query Store - Historical WAIT analysis

SELECT 
    qt.query_sql_text,
    rs.avg_cpu_time,
    rs.avg_duration,
    rs.avg_logical_io_reads,
    ws.wait_category_desc,
    ws.avg_wait_time_ms
FROM sys.query_store_wait_stats ws
JOIN sys.query_store_runtime_stats rs 
    ON ws.runtime_stats_interval_id = rs.runtime_stats_interval_id
JOIN sys.query_store_plan qp 
    ON rs.plan_id = qp.plan_id
JOIN sys.query_store_query q 
    ON qp.query_id = q.query_id
JOIN sys.query_store_query_text qt 
    ON q.query_text_id = qt.query_text_id
ORDER BY ws.avg_wait_time_ms DESC;

