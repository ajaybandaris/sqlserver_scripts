-- 1. Create a pool for Heavy/Bulk operations (Limited to 20% CPU)
CREATE RESOURCE POOL HeavyPool
WITH (MAX_CPU_PERCENT = 20);

-- 2. Create a pool for Users (Guaranteed 50% CPU)
CREATE RESOURCE POOL UserPool
WITH (MIN_CPU_PERCENT = 50);

-- 3. Create Workload Groups within those pools
CREATE WORKLOAD GROUP HeavyGroup USING HeavyPool;
CREATE WORKLOAD GROUP UserGroup USING UserPool;
GO

-- 4. Create Classifier function

USE master;
GO

CREATE FUNCTION dbo.rg_classifier_v1()
RETURNS SYSNAME
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @GroupName SYSNAME;

    -- Logic A: Route by Login Name
    -- If the user is the ETL service account, send to HeavyGroup
    IF (SUSER_SNAME() = 'Corp\DataLoader')
        SET @GroupName = 'HeavyGroup';

    -- Logic B: Route by Application Name 
    -- If the connection comes from a Management tool or Bulk Load tool
    ELSE IF (APP_NAME() LIKE '%SQLCMD%' OR APP_NAME() LIKE '%Integration Services%')
        SET @GroupName = 'HeavyGroup';

    -- Logic C: Route everyone else to the UserGroup
    ELSE
        SET @GroupName = 'UserGroup';

    -- Return the name of the Workload Group
    RETURN @GroupName;
END;

GO

-- Apply the function to the Resource Governor
ALTER RESOURCE GOVERNOR 
WITH (CLASSIFIER_FUNCTION = dbo.rg_classifier_v1);

-- Reconfigure to start the Resource Governor
ALTER RESOURCE GOVERNOR RECONFIGURE;
GO
