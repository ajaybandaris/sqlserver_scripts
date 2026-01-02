--script that queries the Plan Cache to find the most "expensive" memory offenders. 
--It looks for queries that have actually spilled to TempDB and those that are requesting massive memory grants that might be causing RESOURCE_SEMAPHORE waits.

SELECT TOP 10
    st.text AS [Query Text],
    qp.query_plan,
    rs.max_ideal_grant_kb / 1024.0 AS [Max Desired Grant MB],
    rs.last_granted_memory_kb / 1024.0 AS [Last Granted MB],
    rs.max_used_memory_kb / 1024.0 AS [Max Used MB],
    rs.last_query_cost AS [Query Cost],
    -- A high ratio here suggests an over-estimate
    CAST((rs.max_used_memory_kb * 1.0 / NULLIF(rs.last_granted_memory_kb, 0)) * 100 AS DECIMAL(5,2)) AS [Grant Usage %],
    -- Look for spills
    rs.last_spill_count AS [Last Spill Count (Pages)]
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
JOIN sys.dm_exec_query_resource_semaphores AS rs ON 1=1 -- Join logic varies by version, usually better via Extended Events
WHERE rs.max_used_memory_kb < rs.last_granted_memory_kb -- Significant under-utilization
   OR rs.last_spill_count > 0 -- Actual TempDB spills
ORDER BY rs.max_ideal_grant_kb DESC;
