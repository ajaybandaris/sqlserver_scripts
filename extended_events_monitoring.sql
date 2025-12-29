--Captures slow queries, waits, CPU, memory spills, blocking, deadlocks, aborts
--Slow queries	=> sql_statement_completed, rpc_completed
--Waits (CPU / IO / Locks) =>	wait_info
--Blocking	=> blocked_process_report
--Deadlocks =>	xml_deadlock_report
--TempDB spills =>	hash_warning, sort_warning
--Query cancellations =>	attention
--Runtime errors =>	error_reported

CREATE EVENT SESSION [Watchtower_All] ON SERVER
ADD EVENT sqlserver.sql_statement_completed
(
    ACTION
    (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.session_id,
        sqlserver.client_hostname,
        sqlserver.username
    )
    WHERE duration > 5000000 -- > 5 seconds (microseconds)
),
ADD EVENT sqlserver.rpc_completed
(
    ACTION
    (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.session_id
    )
    WHERE duration > 5000000
),
ADD EVENT sqlserver.wait_info
(
    ACTION
    (
        sqlserver.session_id,
        sqlserver.sql_text
    )
    WHERE wait_type NOT IN (0) -- exclude idle waits
),
ADD EVENT sqlserver.blocked_process_report,
ADD EVENT sqlserver.xml_deadlock_report,
ADD EVENT sqlserver.hash_warning,
ADD EVENT sqlserver.sort_warning,
ADD EVENT sqlserver.attention,
ADD EVENT sqlserver.error_reported
(
    WHERE severity >= 16
)
ADD TARGET package0.event_file
(
    SET filename = 'C:\XE\Watchtower_All.xel',
        max_file_size = 100,
        max_rollover_files = 5
);
GO

ALTER EVENT SESSION [Watchtower_All] ON SERVER STATE = START;
GO


-- High CPU and Plan Instability

CREATE EVENT SESSION [Watchtower_CPU] ON SERVER
ADD EVENT sqlserver.query_post_execution_showplan
(
    ACTION
    (
        sqlserver.sql_text,
        sqlserver.database_name,
        sqlserver.session_id
    )
    WHERE cpu_time > 200000 -- >200ms CPU
)
ADD TARGET package0.event_file
(
    SET filename = 'C:\XE\Watchtower_CPU.xel'
);
GO

ALTER EVENT SESSION [Watchtower_CPU] ON SERVER STATE = START;
GO


-- Evidence data
SELECT
    event_data.value('(event/@name)[1]', 'varchar(50)') AS event_name,
    event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text,
    event_data.value('(event/action[@name="database_name"]/value)[1]', 'sysname') AS database_name,
    event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') AS session_id
FROM sys.fn_xe_file_target_read_file
(
    'C:\XE\Watchtower_All*.xel',
    NULL, NULL, NULL
)
CROSS APPLY (SELECT CAST(event_data AS XML)) AS X(event_data);



