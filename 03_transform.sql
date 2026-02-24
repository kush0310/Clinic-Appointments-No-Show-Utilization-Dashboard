/* =========================================================
   03_transform.sql
   Build dimensional model: dimensions + fact
   ========================================================= */

-- Dimensions
DROP TABLE IF EXISTS dm.DimDate;
CREATE TABLE dm.DimDate (
    DateKey        INT         NOT NULL PRIMARY KEY,  -- yyyymmdd
    [Date]         DATE        NOT NULL,
    [Year]         INT         NOT NULL,
    [Month]        INT         NOT NULL,
    MonthName      VARCHAR(20) NOT NULL,
    [Quarter]      INT         NOT NULL,
    WeekOfYear     INT         NOT NULL,
    DayOfWeek      INT         NOT NULL,               -- 1=Mon..7=Sun (ISO)
    DayName        VARCHAR(20) NOT NULL
);

-- Populate date dimension for last 18 months
DECLARE @StartDate DATE = DATEADD(MONTH, -18, CAST(GETDATE() AS DATE));
DECLARE @EndDate   DATE = DATEADD(DAY, 30, CAST(GETDATE() AS DATE));

;WITH d AS (
    SELECT @StartDate AS dt
    UNION ALL
    SELECT DATEADD(DAY, 1, dt) FROM d WHERE dt < @EndDate
)
INSERT INTO dm.DimDate (DateKey, [Date], [Year], [Month], MonthName, [Quarter], WeekOfYear, DayOfWeek, DayName)
SELECT
    CONVERT(INT, FORMAT(dt,'yyyyMMdd')) AS DateKey,
    dt,
    DATEPART(YEAR, dt),
    DATEPART(MONTH, dt),
    DATENAME(MONTH, dt),
    DATEPART(QUARTER, dt),
    DATEPART(ISO_WEEK, dt),
    DATEPART(ISOWK, dt) % 7 + 1,   -- simple ISO-ish mapping
    DATENAME(WEEKDAY, dt)
FROM d
OPTION (MAXRECURSION 0);

DROP TABLE IF EXISTS dm.DimClinic;
CREATE TABLE dm.DimClinic (
    ClinicKey   INT IDENTITY(1,1) PRIMARY KEY,
    ClinicID    INT NOT NULL,
    ClinicName  VARCHAR(100) NOT NULL,
    City        VARCHAR(50) NOT NULL,
    StateCode   CHAR(2) NOT NULL
);

DROP TABLE IF EXISTS dm.DimProvider;
CREATE TABLE dm.DimProvider (
    ProviderKey   INT IDENTITY(1,1) PRIMARY KEY,
    ProviderID    INT NOT NULL,
    ProviderName  VARCHAR(100) NOT NULL,
    Specialty     VARCHAR(50) NOT NULL,
    ActiveFlag    BIT NOT NULL
);

DROP TABLE IF EXISTS dm.DimApptType;
CREATE TABLE dm.DimApptType (
    ApptTypeKey   INT IDENTITY(1,1) PRIMARY KEY,
    ApptTypeID    INT NOT NULL,
    ApptTypeName  VARCHAR(50) NOT NULL,
    DefaultDurationMins INT NOT NULL
);

DROP TABLE IF EXISTS dm.DimPatient;
CREATE TABLE dm.DimPatient (
    PatientKey   INT IDENTITY(1,1) PRIMARY KEY,
    PatientID    INT NOT NULL,
    MRN          VARCHAR(20) NOT NULL,
    DOB          DATE NOT NULL,
    Gender       VARCHAR(10) NOT NULL,
    ZipCode      VARCHAR(10) NULL
);

-- Load dims (Type 1 simple)
TRUNCATE TABLE dm.DimClinic;
INSERT INTO dm.DimClinic (ClinicID, ClinicName, City, StateCode)
SELECT ClinicID, ClinicName, City, StateCode
FROM stg.Clinics;

TRUNCATE TABLE dm.DimProvider;
INSERT INTO dm.DimProvider (ProviderID, ProviderName, Specialty, ActiveFlag)
SELECT ProviderID, ProviderName, Specialty, ActiveFlag
FROM stg.Providers;

TRUNCATE TABLE dm.DimApptType;
INSERT INTO dm.DimApptType (ApptTypeID, ApptTypeName, DefaultDurationMins)
SELECT ApptTypeID, ApptTypeName, DefaultDurationMins
FROM stg.AppointmentTypes;

TRUNCATE TABLE dm.DimPatient;
INSERT INTO dm.DimPatient (PatientID, MRN, DOB, Gender, ZipCode)
SELECT PatientID, MRN, DOB, Gender, ZipCode
FROM stg.Patients;

-- Fact table
DROP TABLE IF EXISTS dm.FactAppointment;
CREATE TABLE dm.FactAppointment (
    AppointmentID    BIGINT NOT NULL PRIMARY KEY,
    DateKey          INT    NOT NULL,
    ClinicKey        INT    NOT NULL,
    ProviderKey      INT    NOT NULL,
    ApptTypeKey      INT    NOT NULL,
    PatientKey       INT    NOT NULL,

    BookedDateKey    INT    NOT NULL,
    StartTime        TIME(0) NOT NULL,
    DurationMins     INT     NOT NULL,

    Status           VARCHAR(20) NOT NULL,
    WaitDays         INT     NOT NULL,   -- AppointmentDate - BookedDate

    IsCompleted      BIT NOT NULL,
    IsNoShow         BIT NOT NULL,
    IsCanceled       BIT NOT NULL,
    IsRescheduled    BIT NOT NULL
);

TRUNCATE TABLE dm.FactAppointment;

INSERT INTO dm.FactAppointment (
    AppointmentID, DateKey, ClinicKey, ProviderKey, ApptTypeKey, PatientKey,
    BookedDateKey, StartTime, DurationMins, Status, WaitDays,
    IsCompleted, IsNoShow, IsCanceled, IsRescheduled
)
SELECT
    a.AppointmentID,
    CONVERT(INT, FORMAT(a.AppointmentDate,'yyyyMMdd')) AS DateKey,
    c.ClinicKey,
    p.ProviderKey,
    t.ApptTypeKey,
    pat.PatientKey,

    CONVERT(INT, FORMAT(a.BookedDate,'yyyyMMdd')) AS BookedDateKey,
    a.StartTime,
    a.DurationMins,
    a.Status,
    DATEDIFF(DAY, a.BookedDate, a.AppointmentDate) AS WaitDays,

    CASE WHEN a.Status='Completed' THEN 1 ELSE 0 END,
    CASE WHEN a.Status='NoShow' THEN 1 ELSE 0 END,
    CASE WHEN a.Status='Canceled' THEN 1 ELSE 0 END,
    CASE WHEN a.Status='Rescheduled' THEN 1 ELSE 0 END
FROM stg.Appointments a
JOIN dm.DimClinic   c   ON c.ClinicID = a.ClinicID
JOIN dm.DimProvider p   ON p.ProviderID = a.ProviderID
JOIN dm.DimApptType t   ON t.ApptTypeID = a.ApptTypeID
JOIN dm.DimPatient  pat ON pat.PatientID = a.PatientID;