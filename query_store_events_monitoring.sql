-- Query store configuration

ALTER DATABASE CURRENT SET QUERY_STORE = ON;
ALTER DATABASE CURRENT SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE, 
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    MAX_STORAGE_SIZE_MB = 1000, 
    QUERY_CAPTURE_MODE = AUTO 
);

-- Enable Automatic Plan Correction (The Auto-Healer)
ALTER DATABASE CURRENT SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);

--Monitoring and Detection using SQL Server External Events

CREATE EVENT SESSION [HighCostQueryShield] ON SERVER 
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.sql_text, sqlserver.database_name, sqlserver.client_hostname)
    WHERE (cpu_time > 1000000 OR logical_reads > 10000) -- Only heavy hitters
)
ADD TARGET package0.event_file(SET filename=N'HighCostShield.xel');
GO
ALTER EVENT SESSION [HighCostQueryShield] ON SERVER STATE = START;

-- Check Monitoring---

-- 1. STALE STATS CHECK
SELECT obj.name AS [Table], stat.name AS [Stat], 
       sp.modification_counter AS [Changes],
       CAST((sp.modification_counter * 100.0 / NULLIF(sp.rows,0)) AS DECIMAL(10,2)) AS [%_Drift]
FROM sys.stats AS stat
CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
JOIN sys.objects AS obj ON stat.object_id = obj.object_id
WHERE sp.modification_counter > 1000 AND (sp.modification_counter * 100.0 / NULLIF(sp.rows,0)) > 10.0;

-- 2. ABORTED QUERIES (FAIL-FAST EVIDENCE)
SELECT TOP 10 qt.query_sql_text, rs.execution_type_desc, rs.avg_duration / 1000000.0 AS [AvgSec]
FROM sys.query_store_query q
JOIN sys.query_store_runtime_stats rs ON q.query_id = rs.query_id
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
WHERE rs.execution_type_desc IN ('Aborted', 'Exception')
ORDER BY rs.last_execution_time DESC;
