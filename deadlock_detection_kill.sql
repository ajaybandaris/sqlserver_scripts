--1. Create an Extended Event Session for Deadlocks
CREATE EVENT SESSION [Capture_Deadlocks] 
ON SERVER
ADD EVENT sqlserver.deadlock_graph
ADD TARGET package0.event_file
(
    SET filename = N'C:\XE\Deadlocks.xel',
        max_file_size = 10,  -- MB
        max_rollover_files = 5
)
WITH
(
    MAX_MEMORY = 4096 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 5 SECONDS
);
GO

--2. Start the Event Session. -- From this point onward, every deadlock is captured automatically.
ALTER EVENT SESSION [Capture_Deadlocks]
ON SERVER
STATE = START;
GO

--3. Read Deadlock Details (Graph + Queries) -- The DeadlockGraph XML can be opened in SSMS (right-click → “Show Graph”) for a visual deadlock diagram.
SELECT
    XEvent.value('(event/@timestamp)[1]', 'datetime2') AS DeadlockTime,
    XEvent.value('(event/data/value/deadlock)[1]', 'xml') AS DeadlockGraph
FROM
(
    SELECT CAST(event_data AS XML) AS XEvent
    FROM sys.fn_xe_file_target_read_file
    (
        'C:\XE\Deadlocks*.xel',
        NULL,
        NULL,
        NULL
    )
) AS Deadlocks
ORDER BY DeadlockTime DESC;

--4. Identify Deadlock Victim & Queries -- To extract victim process and statements:
SELECT
    DeadlockXML.value('(//victim-list/victimProcess/@id)[1]', 'varchar(50)') AS VictimProcess,
    DeadlockXML.value('(//process[@id=//victim-list/victimProcess/@id]/inputbuf)[1]', 'nvarchar(max)') AS VictimQuery
FROM
(
    SELECT CAST(event_data AS XML) AS DeadlockXML
    FROM sys.fn_xe_file_target_read_file
    (
        'C:\XE\Deadlocks*.xel',
        NULL,
        NULL,
        NULL
    )
) D;

--5. Check if Deadlocks Are Happening Right Now -- Deadlocks are instant events, but you can check current blocking (precursor to deadlocks):
--This does not show deadlocks, but helps detect blocking patterns that often lead to deadlocks.
SELECT
    r.session_id,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time,
    r.status,
    t.text AS RunningQuery
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0;

--Use system_health (Already Enabled) SQL Server ships with system_health, which already captures deadlocks.

SELECT
    XEvent.value('(event/@timestamp)[1]', 'datetime2') AS DeadlockTime,
    XEvent.value('(event/data/value/deadlock)[1]', 'xml') AS DeadlockGraph
FROM
(
    SELECT CAST(event_data AS XML) AS XEvent
    FROM sys.fn_xe_file_target_read_file
    (
        (SELECT CAST(target_data AS XML)
         .value('(EventFileTarget/File/@name)[1]', 'nvarchar(4000)')
         FROM sys.dm_xe_session_targets t
         JOIN sys.dm_xe_sessions s
             ON s.address = t.event_session_address
         WHERE s.name = 'system_health'),
        NULL, NULL, NULL
    )
) AS Deadlocks;





