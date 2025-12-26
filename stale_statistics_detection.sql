--"stale" statistics Detection
SELECT 
    obj.name AS TableName, 
    stat.name AS StatName, 
    STATS_DATE(stat.object_id, stat.stats_id) AS LastUpdate,
    sp.modification_counter AS RowsChangedSinceUpdate
FROM sys.stats AS stat
CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
JOIN sys.objects AS obj ON stat.object_id = obj.object_id
WHERE sp.modification_counter > 1000 -- Alert if > 1000 rows changed
ORDER BY sp.modification_counter DESC;


-- Conceptual "Self-Healing" Guardrail Logic
IF EXISTS (SELECT 1 FROM sys.dm_db_stats_properties WHERE modification_counter > @Threshold)
BEGIN
    -- Tactical Update: Only update the specific stale stat, not the whole DB
    -- Use RESUMEABLE = ON if on SQL 2019+ to prevent blocking
    UPDATE STATISTICS @TableName @StatName WITH SAMPLE 20 PERCENT;
    
    -- Log the action for the monitoring dashboard
    INSERT INTO DBA_Maintenance_Log (Action, TableName) VALUES ('Auto-Update Stats', @TableName);
END
