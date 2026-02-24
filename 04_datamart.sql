/* =========================================================
   04_datamart.sql
   Data mart views for Tableau
   ========================================================= */

DROP VIEW IF EXISTS dm.vw_AppointmentKPI;
GO
CREATE VIEW dm.vw_AppointmentKPI AS
SELECT
    d.[Date],
    d.[Year],
    d.[Month],
    d.MonthName,
    d.[Quarter],
    dc.ClinicName,
    dp.ProviderName,
    dp.Specialty,
    atp.ApptTypeName,

    COUNT(*) AS ApptCount,
    SUM(CASE WHEN f.IsCompleted=1 THEN 1 ELSE 0 END) AS CompletedCount,
    SUM(CASE WHEN f.IsNoShow=1 THEN 1 ELSE 0 END) AS NoShowCount,
    SUM(CASE WHEN f.IsCanceled=1 THEN 1 ELSE 0 END) AS CancelCount,

    CAST(100.0 * SUM(CASE WHEN f.IsNoShow=1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS NoShowRatePct,
    CAST(100.0 * SUM(CASE WHEN f.IsCanceled=1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS CancelRatePct,
    CAST(100.0 * SUM(CASE WHEN f.IsCompleted=1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS UtilizationPct,

    CAST(AVG(CAST(f.WaitDays AS FLOAT)) AS DECIMAL(10,2)) AS AvgWaitDays
FROM dm.FactAppointment f
JOIN dm.DimDate d      ON d.DateKey = f.DateKey
JOIN dm.DimClinic dc   ON dc.ClinicKey = f.ClinicKey
JOIN dm.DimProvider dp ON dp.ProviderKey = f.ProviderKey
JOIN dm.DimApptType atp ON atp.ApptTypeKey = f.ApptTypeKey
GROUP BY
    d.[Date], d.[Year], d.[Month], d.MonthName, d.[Quarter],
    dc.ClinicName, dp.ProviderName, dp.Specialty, atp.ApptTypeName;
GO

-- Convenience export view at appointment grain (for flexible Tableau analysis)
DROP VIEW IF EXISTS dm.vw_AppointmentDetail;
GO
CREATE VIEW dm.vw_AppointmentDetail AS
SELECT
    f.AppointmentID,
    d.[Date] AS AppointmentDate,
    bd.[Date] AS BookedDate,
    f.WaitDays,
    f.StartTime,
    f.DurationMins,
    f.Status,

    dc.ClinicName,
    dc.City,
    dc.StateCode,
    dp.ProviderName,
    dp.Specialty,
    atp.ApptTypeName,

    pat.Gender,
    pat.ZipCode,
    pat.DOB
FROM dm.FactAppointment f
JOIN dm.DimDate d       ON d.DateKey = f.DateKey
JOIN dm.DimDate bd      ON bd.DateKey = f.BookedDateKey
JOIN dm.DimClinic dc    ON dc.ClinicKey = f.ClinicKey
JOIN dm.DimProvider dp  ON dp.ProviderKey = f.ProviderKey
JOIN dm.DimApptType atp ON atp.ApptTypeKey = f.ApptTypeKey
JOIN dm.DimPatient pat  ON pat.PatientKey = f.PatientKey;
GO