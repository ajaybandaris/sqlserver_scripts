-- Example - Employee Table
--To implement partitioning for an Employee database, we typically partition by the date the employee joined or by their department ID. 
In this example, we will use JoiningDate to manage historical data effectively.

========= Step1: The Foundation: Function and Scheme ======
--We will create a partition function that splits data by year. This is common for HR systems to separate "Current" employees from "Historical" records.



-- 1. Create Partition Function (Yearly boundaries)
CREATE PARTITION FUNCTION pf_EmployeeJoining (DATE)
AS RANGE LEFT FOR VALUES 
('2022-12-31', '2023-12-31', '2024-12-31', '2025-12-31');

-- 2. Create Partition Scheme
CREATE PARTITION SCHEME ps_EmployeeScheme
AS PARTITION pf_EmployeeJoining ALL TO ([PRIMARY]);

======== Step2:  Table Creation (Clustered & Non-Clustered) =====
--When partitioning, the Partition Key (JoiningDate) must be part of the Clustered Index (Primary Key).


-- 3. Create Partitioned Employee Table
CREATE TABLE dbo.Employees_Partitioned (
    EmployeeID INT IDENTITY(1,1) NOT NULL,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Email NVARCHAR(100),
    JoiningDate DATE NOT NULL,
    DepartmentID INT,
    Salary DECIMAL(18, 2),
    -- Primary Key must include the partitioning column
    CONSTRAINT PK_Employees_Partitioned PRIMARY KEY CLUSTERED (EmployeeID, JoiningDate)
) ON ps_EmployeeScheme(JoiningDate);

-- 4. Create a Non-Clustered Index (Aligned with the partition)
CREATE NONCLUSTERED INDEX IX_Emp_Dept 
ON dbo.Employees_Partitioned (DepartmentID)
ON ps_EmployeeScheme(JoiningDate);

======Step3: Data Insertion and Verification =====
--We will insert records spanning different years to see the partitioning in action.



-- 5. Insert Sample Data
INSERT INTO dbo.Employees_Partitioned (FirstName, LastName, Email, JoiningDate, DepartmentID, Salary)
VALUES 
('John', 'Doe', 'john@example.com', '2022-05-15', 1, 60000),  -- Partition 1
('Jane', 'Smith', 'jane@example.com', '2023-08-20', 2, 75000), -- Partition 2
('Mike', 'Ross', 'mike@example.com', '2024-01-10', 1, 80000),  -- Partition 3
('Rachel', 'Zane', 'rachel@example.com', '2025-06-01', 3, 90000);-- Partition 4

-- 6. Verify which partition holds which data
SELECT 
    p.partition_number,
    p.rows AS Row_Count,
    rv.value AS Boundary_Value,
    OBJECT_NAME(p.object_id) AS Table_Name
FROM sys.partitions p
JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
JOIN sys.partition_range_values rv ON ps.function_id = rv.function_id AND p.partition_number = rv.boundary_id
WHERE p.object_id = OBJECT_ID('Employees_Partitioned');

=========Step4: Maintenance ==========
  --Archive and Cleanup: If an employee record is very old, we "SWITCH" it out to an archive table. This is a metadata-only operation and happens instantly.


-- 7. Create Archive Table (Exact same schema)
CREATE TABLE dbo.Employees_Archive (
    EmployeeID INT NOT NULL,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Email NVARCHAR(100),
    JoiningDate DATE NOT NULL,
    DepartmentID INT,
    Salary DECIMAL(18, 2),
    CONSTRAINT PK_Employees_Archive PRIMARY KEY CLUSTERED (EmployeeID, JoiningDate)
) ON [PRIMARY];

-- 8. Switch out the oldest partition (Partition 1: Year 2022 and earlier)
ALTER TABLE dbo.Employees_Partitioned SWITCH PARTITION 1 TO dbo.Employees_Archive;

-- 9. Merge the old boundary (Cleanup)
ALTER PARTITION FUNCTION pf_EmployeeJoining() MERGE RANGE ('2022-12-31');
5. Adding New Capacity (Split)
When a new year starts, we add a new partition boundary.

-- 10. Prepare Scheme and Split Function for 2026
ALTER PARTITION SCHEME ps_EmployeeScheme NEXT USED [PRIMARY];
ALTER PARTITION FUNCTION pf_EmployeeJoining() SPLIT RANGE ('2026-12-31');
