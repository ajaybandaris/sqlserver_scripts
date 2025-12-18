--Below query that identifies the current blocking chain in the database server. 
--This query is designed to read the blocking chain by using the key relationship defined in the system tables:

SELECT
    ---------------------------
    -- Blocked Request Info
    ---------------------------
    BlockedReq.session_id            AS Blocked_SPID,
    BlockedReq.request_id,
    BlockedReq.status                AS Blocked_Status,
    BlockedReq.wait_type,
    BlockedReq.wait_time,
    BlockedReq.wait_resource,
    wt.blocking_session_id           AS Blocker_SPID,

    ---------------------------
    -- Blocker Session Info
    ---------------------------
    Blocker.login_name               AS Blocker_Login,
    Blocker.host_name                AS Blocker_Host,
    Blocker.program_name             AS Blocker_App,
    Blocker.cpu_time                 AS Blocker_CPU,
    Blocker.memory_usage             AS Blocker_Memory,
    Blocker.open_transaction_count   AS Blocker_OpenTxCount,
    CASE WHEN Blocker.open_transaction_count > 0 THEN 1 ELSE 0 END
                                     AS Blocker_HasOpenTxn,

    ---------------------------
    -- Blocked Session Info
    ---------------------------
    Blocked.login_name               AS Blocked_Login,
    Blocked.host_name                AS Blocked_Host,
    Blocked.program_name             AS Blocked_App,
    Blocked.cpu_time                 AS Blocked_CPU,
    Blocked.memory_usage             AS Blocked_Memory,
    Blocked.open_transaction_count   AS Blocked_OpenTxCount,
    CASE WHEN Blocked.open_transaction_count > 0 THEN 1 ELSE 0 END
                                     AS Blocked_HasOpenTxn,

    ---------------------------
    -- SQL Texts
    ---------------------------
    REPLACE(BlockerText.text, CHAR(10), ' ') AS Blocker_QueryText,
    REPLACE(BlockedText.text, CHAR(10), ' ') AS Blocked_QueryText

FROM sys.dm_os_waiting_tasks wt
JOIN sys.dm_exec_requests BlockedReq
    ON wt.session_id = BlockedReq.session_id
JOIN sys.dm_exec_sessions Blocked
    ON BlockedReq.session_id = Blocked.session_id
JOIN sys.dm_exec_sessions Blocker
    ON wt.blocking_session_id = Blocker.session_id

OUTER APPLY sys.dm_exec_sql_text(Blocker.most_recent_sql_handle) AS BlockerText
OUTER APPLY sys.dm_exec_sql_text(Blocked.most_recent_sql_handle) AS BlockedText

WHERE wt.blocking_session_id <> 0    -- only show actual blocking
ORDER BY BlockedReq.wait_time DESC;

