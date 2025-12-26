-- 1. STALE STATS: Tables that have changed significantly since last update
SELECT 
    obj.name AS [Table_Name], 
    stat.name AS [Statistic_Name], 
    sp.last_updated AS [Last_Updated],
    sp.modification_counter AS [Rows_Changed],
    CAST((sp.modification_counter * 100.0 / sp.rows) AS DECIMAL(10,2)) AS [Percent_Drift]
FROM sys.stats AS stat
CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
JOIN sys.objects AS obj ON stat.object_id = obj.object_id
WHERE sp.modification_counter > 1000 -- Only show significant changes
AND CAST((sp.modification_counter * 100.0 / sp.rows) AS DECIMAL(10,2)) > 10.0 -- 10% threshold
ORDER BY [Percent_Drift] DESC;

-- 2. FAIL-FAST ALERTS: Queries killed by the Query Governor or Timeouts
-- (Requires Query Store to be enabled)
SELECT TOP 10
    q.query_id,
    qt.query_sql_text,
    rs.count_executions,
    rs.avg_duration / 1000000.0 AS Avg_Duration_Sec,
    rs.max_query_max_used_memory * 8 / 1024.0 AS Max_Memory_MB
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE rs.execution_type_desc IN ('Aborted', 'Exception')
ORDER BY rs.last_execution_time DESC;

-- 3. RESOURCE PRESSURE: Check for Memory or CPU starvation
SELECT 
    wait_type, 
    wait_time_ms / 1000.0 AS Wait_Sec,
    100.0 * wait_time_ms / SUM(wait_time_ms) OVER() AS [%_of_Total_Wait]
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('RESOURCE_SEMAPHORE', 'SOS_SCHEDULER_YIELD', 'PAGEIOLATCH_EX', 'LCK_M_X')
AND wait_time_ms > 0
ORDER BY Wait_Sec DESC;
