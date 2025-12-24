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
