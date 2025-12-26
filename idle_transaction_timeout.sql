--sys.dm_exec_sessions to find connections that haven't sent a request in a long time.
SELECT 
    session_id,
    login_name,
    status,
    last_request_end_time,
    DATEDIFF(minute, last_request_end_time, GETDATE()) AS idle_minutes,
    open_transaction_count
FROM sys.dm_exec_sessions
WHERE status = 'sleeping' 
  AND DATEDIFF(minute, last_request_end_time, GETDATE()) > 30 -- Idle for 30+ mins
ORDER BY idle_minutes DESC;


-- SQL Agent Job that runs every 10 minutes and kills any session idle for more than, say, 5min—especially if they have an open transaction.
DECLARE @kill_cmd NVARCHAR(MAX) = '';

SELECT @kill_cmd += 'KILL ' + CAST(session_id AS VARCHAR(10)) + ';'
FROM sys.dm_exec_sessions
WHERE status = 'sleeping'
  AND open_transaction_count > 0 -- Focus only on those holding locks
  AND DATEDIFF(minute, last_request_end_time, GETDATE()) > 05; -- 5 minutes

EXEC sp_executesql @kill_cmd;
