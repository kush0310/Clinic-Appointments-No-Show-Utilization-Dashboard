/* =========================================================
   02_staging.sql
   Creates staging tables and loads/generates sample data
   ========================================================= */

-- Clean staging tables
DROP TABLE IF EXISTS stg.Patients;
DROP TABLE IF EXISTS stg.Providers;
DROP TABLE IF EXISTS stg.Clinics;
DROP TABLE IF EXISTS stg.AppointmentTypes;
DROP TABLE IF EXISTS stg.Appointments;

-- Staging tables (slightly cleaner typing than raw)
CREATE TABLE stg.Patients (
    PatientID     INT          NOT NULL,
    MRN           VARCHAR(20)  NOT NULL,
    DOB           DATE         NOT NULL,
    Gender        VARCHAR(10)  NOT NULL,
    ZipCode       VARCHAR(10)  NULL,
    CreatedAt     DATETIME2(0) NOT NULL
);

CREATE TABLE stg.Providers (
    ProviderID    INT           NOT NULL,
    ProviderName  VARCHAR(100)  NOT NULL,
    Specialty     VARCHAR(50)   NOT NULL,
    ActiveFlag    BIT           NOT NULL,
    CreatedAt     DATETIME2(0)  NOT NULL
);

CREATE TABLE stg.Clinics (
    ClinicID      INT           NOT NULL,
    ClinicName    VARCHAR(100)  NOT NULL,
    City          VARCHAR(50)   NOT NULL,
    StateCode     CHAR(2)       NOT NULL,
    CreatedAt     DATETIME2(0)  NOT NULL
);

CREATE TABLE stg.AppointmentTypes (
    ApptTypeID      INT          NOT NULL,
    ApptTypeName    VARCHAR(50)  NOT NULL,
    DefaultDurationMins INT      NOT NULL,
    CreatedAt        DATETIME2(0) NOT NULL
);

CREATE TABLE stg.Appointments (
    AppointmentID     BIGINT       NOT NULL,
    PatientID         INT          NOT NULL,
    ProviderID        INT          NOT NULL,
    ClinicID          INT          NOT NULL,
    ApptTypeID        INT          NOT NULL,
    BookedDate        DATE         NOT NULL,
    AppointmentDate   DATE         NOT NULL,
    StartTime         TIME(0)      NOT NULL,
    DurationMins      INT          NOT NULL,
    Status            VARCHAR(20)  NOT NULL,
    CancelReason      VARCHAR(100) NULL,
    CreatedAt         DATETIME2(0) NOT NULL
);

-------------------------------------------------------------------
-- SAMPLE DATA GENERATION (safe + deterministic-ish)
-------------------------------------------------------------------

-- Dimension seed data
TRUNCATE TABLE raw.Clinics;
INSERT INTO raw.Clinics (ClinicID, ClinicName, City, StateCode, CreatedAt)
VALUES
(1,'Midtown Family Clinic','St. Louis','MO',SYSDATETIME()),
(2,'West County Internal Med','Chesterfield','MO',SYSDATETIME()),
(3,'Northside Pediatrics','Florissant','MO',SYSDATETIME()),
(4,'Downtown Specialty Care','St. Louis','MO',SYSDATETIME());

TRUNCATE TABLE raw.Providers;
INSERT INTO raw.Providers (ProviderID, ProviderName, Specialty, ActiveFlag, CreatedAt)
VALUES
(101,'Patel','Primary Care',1,SYSDATETIME()),
(102,'Nguyen','Internal Med',1,SYSDATETIME()),
(103,'Smith','Pediatrics',1,SYSDATETIME()),
(104,'Garcia','Cardiology',1,SYSDATETIME()),
(105,'Johnson','Dermatology',1,SYSDATETIME());

TRUNCATE TABLE raw.AppointmentTypes;
INSERT INTO raw.AppointmentTypes (ApptTypeID, ApptTypeName, DefaultDurationMins, CreatedAt)
VALUES
(10,'Follow-up',20,SYSDATETIME()),
(11,'New Patient',40,SYSDATETIME()),
(12,'Annual Physical',40,SYSDATETIME()),
(13,'Lab Review',20,SYSDATETIME()),
(14,'Procedure',60,SYSDATETIME());

-- Create a simple numbers set (0..9999)
-- Create a simple numbers set (0..9999)
;WITH n AS (
    SELECT TOP (10000)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS num
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
-- Patients: 2,000
INSERT INTO raw.Patients (PatientID, MRN, DOB, Gender, ZipCode, CreatedAt)
SELECT
    num + 1 AS PatientID,
    CONCAT('MRN', RIGHT('000000' + CAST(num + 1 AS VARCHAR(10)), 6)) AS MRN,
    DATEADD(DAY, -1 * (ABS(CHECKSUM(NEWID())) % (365*70) + 365*5), CAST(GETDATE() AS DATE)) AS DOB,
    CASE 
        WHEN (ABS(CHECKSUM(NEWID())) % 2)=0 THEN 'Female'
        ELSE 'Male'
    END AS Gender,
    CONCAT('63', RIGHT('000' + CAST(ABS(CHECKSUM(NEWID())) % 900 AS VARCHAR(10)), 3)) AS ZipCode,
    DATEADD(DAY, -1*(ABS(CHECKSUM(NEWID())) % 365), SYSDATETIME()) AS CreatedAt
FROM n
WHERE num < 2000;

-- Appointments: 25,000 across last 12 months
WITH n AS (
    SELECT TOP (25000)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
gen AS (
    SELECT
        CAST(rn AS BIGINT) AS AppointmentID,
        (ABS(CHECKSUM(NEWID())) % 2000) + 1 AS PatientID,
        (CASE (ABS(CHECKSUM(NEWID())) % 5)
            WHEN 0 THEN 101 WHEN 1 THEN 102 WHEN 2 THEN 103 WHEN 3 THEN 104 ELSE 105 END) AS ProviderID,
        (ABS(CHECKSUM(NEWID())) % 4) + 1 AS ClinicID,
        (CASE (ABS(CHECKSUM(NEWID())) % 5)
            WHEN 0 THEN 10 WHEN 1 THEN 11 WHEN 2 THEN 12 WHEN 3 THEN 13 ELSE 14 END) AS ApptTypeID,

        DATEADD(DAY, -1*(ABS(CHECKSUM(NEWID())) % 365), CAST(GETDATE() AS DATE)) AS AppointmentDate,

        -- booked date is earlier than appointment date by 0–20 days (mostly)
        DATEADD(DAY, -1*(ABS(CHECKSUM(NEWID())) % 20), 
            DATEADD(DAY, -1*(ABS(CHECKSUM(NEWID())) % 365), CAST(GETDATE() AS DATE))
        ) AS BookedDate,

        -- time buckets 8:00 to 17:30
        TIMEFROMPARTS(
            8 + (ABS(CHECKSUM(NEWID())) % 10),
            CASE WHEN (ABS(CHECKSUM(NEWID())) % 2)=0 THEN 0 ELSE 30 END,
            0, 0, 0
        ) AS StartTime,

        (CASE (ABS(CHECKSUM(NEWID())) % 5)
            WHEN 0 THEN 20 WHEN 1 THEN 40 WHEN 2 THEN 40 WHEN 3 THEN 20 ELSE 60 END) AS DurationMins,

        -- status distribution: Completed 85%, NoShow 8%, Canceled 5%, Rescheduled 2%
        CASE
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 85 THEN 'Completed'
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 93 THEN 'NoShow'
            WHEN (ABS(CHECKSUM(NEWID())) % 100) < 98 THEN 'Canceled'
            ELSE 'Rescheduled'
        END AS Status,

        SYSDATETIME() AS CreatedAt
    FROM n
)
INSERT INTO raw.Appointments (
    AppointmentID, PatientID, ProviderID, ClinicID, ApptTypeID,
    BookedDate, AppointmentDate, StartTime, DurationMins,
    Status, CancelReason, CreatedAt
)
SELECT
    AppointmentID,
    PatientID,
    ProviderID,
    ClinicID,
    ApptTypeID,

    -- ensure booked date is not after appointment date
    CASE WHEN BookedDate > AppointmentDate THEN DATEADD(DAY, -7, AppointmentDate) ELSE BookedDate END AS BookedDate,
    AppointmentDate,
    StartTime,
    DurationMins,
    Status,

    CASE
        WHEN Status IN ('Canceled','Rescheduled') THEN 'Patient request'
        ELSE NULL
    END AS CancelReason,

    CreatedAt
FROM gen;
-------------------------------------------------------------------
-- Load RAW -> STG (simple "copy", where you'd normally clean)
-------------------------------------------------------------------
TRUNCATE TABLE stg.Clinics;          INSERT INTO stg.Clinics          SELECT * FROM raw.Clinics;
TRUNCATE TABLE stg.Providers;        INSERT INTO stg.Providers        SELECT * FROM raw.Providers;
TRUNCATE TABLE stg.AppointmentTypes; INSERT INTO stg.AppointmentTypes SELECT * FROM raw.AppointmentTypes;
TRUNCATE TABLE stg.Patients;         INSERT INTO stg.Patients         SELECT * FROM raw.Patients;
TRUNCATE TABLE stg.Appointments;     INSERT INTO stg.Appointments     SELECT * FROM raw.Appointments;