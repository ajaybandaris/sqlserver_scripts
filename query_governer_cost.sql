-- Set server-wide cost limit (e.g., 300 abstract units)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'query governor cost limit', 300; 
RECONFIGURE;

-- Override for specific maintenance/bulk service accounts
SET QUERY_GOVERNOR_COST_LIMIT 0;
