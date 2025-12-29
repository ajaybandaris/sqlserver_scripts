-- Bulk Change detection

CREATE PROCEDURE [dbo].[Check_Shield_Breaches] AS
BEGIN
    IF EXISTS (SELECT 1 FROM sys.dm_db_stats_properties WHERE modification_counter > 50000)
    BEGIN
        -- Insert logic here for Slack Webhook or sp_send_dbmail
        PRINT 'ALERT: Massive data drift detected. Shield under pressure.';
    END
END

-- The Bulk-Delete Guardrail Trigger

CREATE TRIGGER [Shield_RowLimit_Delete] ON DATABASE FOR DROP_TABLE, ALTER_TABLE
AS 
BEGIN
    IF (@@ROWCOUNT > 100000) 
    BEGIN
        RAISERROR ('Bulk operation exceeded 100k row guardrail. Use batching.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
