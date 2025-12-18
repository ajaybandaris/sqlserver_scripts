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

----------------------------------------------
Example Output (Narrative)
----------------------------------------------

Blocking Scenario 1
-------------------    
Session SPID 82 is blocked by SPID 58.
SPID 82 is currently in a running state and waiting on the lock type LCK_M_X for about 14.2 seconds. The wait resource indicates a KEY-level lock.

The blocker (SPID 58) is connected using the sa login from APP-SERVER-01, running the MyApp.API application. It has one open transaction, which confirms it is actively holding locks.

The blocked session (SPID 82) is also using the sa login but originates from APP-SERVER-02, running the same application. It has no open transactions.

The blocking query executed by SPID 58 is:
UPDATE Corporate.Employee SET LastName = 'Berge Johnson' WHERE BusinessEntityID = 220

The blocked query executed by SPID 82 is:
UPDATE Corporate.Employee SET LastName = 'Smith' WHERE BusinessEntityID = 371
------------------------------------------------------------------------------------------------------------------------------------------

Blocking Scenario 2
-------------------    
Session SPID 105 is blocked by SPID 82.
SPID 105 is running and waiting on a LCK_M_U lock for approximately 8.7 seconds, with the wait resource pointing to a PAGE-level lock.

The blocker (SPID 82) originates from APP-SERVER-02 and is running MyApp.API. It does not currently have any open transactions.

The blocked session (SPID 105) is running from APP-SERVER-03, using the MyApp.ReportJob application.

The blocking query from SPID 82 is:
UPDATE Corporate.Employee SET LastName = 'Smith' WHERE BusinessEntityID = 371

The blocked query from SPID 105 is:
SELECT * FROM Corporate.Employee WHERE BusinessEntityID = 540
------------------------------------------------------------------------------------------------------------------------------------------

----Resolving Steps----
    
1. Identify the Root Blocker

From the blocking chain:

SPID 58 → SPID 82 → SPID 105

SPID 58 is the root blocker, as it is not being blocked by any other session.
The root blocker is always the first SPID in the chain with blocking_session_id = 0, and this is where investigation must begin.
----------------------------------------------

2. Analyze the Root Blocker (SPID 58)

SPID 58 is executing the following query:
UPDATE Corporate.Employee SET LastName = 'Ajay Bandari' WHERE BusinessEntityID = 220

When analyzing the root blocker, focus on:

Session status (running, sleeping, suspended)

Wait type (e.g., LCK_M_X, WRITELOG, PAGELATCH_SH)

Wait resource (KEY, PAGE, OBJECT)

Open transaction count

Login, host, and application name to identify the source system

If SPID 58 is SLEEPING while still holding an open transaction, this indicates an open transaction left running, which is the most common cause of blocking in OLTP systems.

Key checks:

If the open transaction count is 1 or more, the session is holding locks.

If the session is sleeping, it may be waiting for user input or application logic (for example, an API call paused or waiting for a response), which can severely impact concurrency.
----------------------------------------------

3. Decide the Action Based on the Root Blocker

Case 1: SPID 58 is sleeping with an open transaction
Terminate the session using KILL 58.
This immediately releases all locks and resolves the entire blocking chain.

Case 2: SPID 58 is actively running a long UPDATE or DELETE
Allow it to complete if it is a known, legitimate job close to completion.
Terminate it if it is a runaway or accidental query.

Case 3: SPID 58 is a reporting query blocking OLTP operations
Move reporting workloads to Read Committed Snapshot Isolation (RCSI) or use WITH (NOLOCK) if business rules allow.

Case 4: Locks are held due to application issues
 ----------------------------------------------


