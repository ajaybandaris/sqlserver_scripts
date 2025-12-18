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
