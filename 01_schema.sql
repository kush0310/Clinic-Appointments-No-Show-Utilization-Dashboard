/* =========================================================
   01_schema.sql
   Project: Clinic Appointments — No-Show & Utilization
   Target: Azure SQL Database (T-SQL)
   ========================================================= */

--Create DB (run only if you have permissions; otherwise create in Azure Portal)
CREATE DATABASE HealthClinicOps;
GO
 USE HealthClinicOps;
 GO

-- Schemas
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw') EXEC('CREATE SCHEMA raw');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg') EXEC('CREATE SCHEMA stg');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dm')  EXEC('CREATE SCHEMA dm');

-- RAW tables (source-like, minimal constraints)
DROP TABLE IF EXISTS raw.Patients;
CREATE TABLE raw.Patients (
    PatientID       INT            NOT NULL,
    MRN             VARCHAR(20)    NOT NULL,
    DOB             DATE           NOT NULL,
    Gender          VARCHAR(10)    NOT NULL,
    ZipCode         VARCHAR(10)    NULL,
    CreatedAt       DATETIME2(0)   NOT NULL
);

DROP TABLE IF EXISTS raw.Providers;
CREATE TABLE raw.Providers (
    ProviderID      INT           NOT NULL,
    ProviderName    VARCHAR(100)  NOT NULL,
    Specialty       VARCHAR(50)   NOT NULL,
    ActiveFlag      BIT           NOT NULL,
    CreatedAt       DATETIME2(0)  NOT NULL
);

DROP TABLE IF EXISTS raw.Clinics;
CREATE TABLE raw.Clinics (
    ClinicID        INT           NOT NULL,
    ClinicName      VARCHAR(100)  NOT NULL,
    City            VARCHAR(50)   NOT NULL,
    StateCode       CHAR(2)       NOT NULL,
    CreatedAt       DATETIME2(0)  NOT NULL
);

DROP TABLE IF EXISTS raw.AppointmentTypes;
CREATE TABLE raw.AppointmentTypes (
    ApptTypeID      INT           NOT NULL,
    ApptTypeName    VARCHAR(50)   NOT NULL,
    DefaultDurationMins INT       NOT NULL,
    CreatedAt       DATETIME2(0)  NOT NULL
);

DROP TABLE IF EXISTS raw.Appointments;
CREATE TABLE raw.Appointments (
    AppointmentID     BIGINT        NOT NULL,
    PatientID         INT           NOT NULL,
    ProviderID        INT           NOT NULL,
    ClinicID          INT           NOT NULL,
    ApptTypeID        INT           NOT NULL,

    BookedDate        DATE          NOT NULL,
    AppointmentDate   DATE          NOT NULL,
    StartTime         TIME(0)       NOT NULL,
    DurationMins      INT           NOT NULL,

    Status            VARCHAR(20)   NOT NULL,   -- Completed, NoShow, Canceled, Rescheduled
    CancelReason      VARCHAR(100)  NULL,

    CreatedAt         DATETIME2(0)  NOT NULL
);

-- Helpful indexes (raw)
CREATE INDEX IX_raw_Appointments_Date ON raw.Appointments (AppointmentDate);
CREATE INDEX IX_raw_Appointments_ClinicProvider ON raw.Appointments (ClinicID, ProviderID);

