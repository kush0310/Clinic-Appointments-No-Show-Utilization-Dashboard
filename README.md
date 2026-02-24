# 🏥 Clinic Appointments — No-Show & Utilization Dashboard  
**Azure SQL + Tableau**

Executive-level healthcare operations dashboard designed to monitor appointment no-show behavior, provider utilization, patient wait times, and scheduling efficiency using a dimensional model built in Azure SQL.

---

## 🖼 Dashboard Preview

<img src="Clinic_Appointments_Dashboard.png" width="900">

---

## 🧠 Project Overview

This project simulates a production healthcare analytics environment and delivers standardized KPIs through a structured data pipeline:

**raw → stg → dm (star schema) → Tableau**

The dashboard enables leadership to quickly assess:

- No-Show Rate %
- Provider Utilization %
- Cancellation Rate %
- Average Patient Wait Days
- Weekly No-Show Trends
- No-Show Hotspots (Day × Hour)

All business logic is centralized in SQL to ensure metric consistency across reporting tools.

---

## 🏗 Data Architecture

### 🔹 Fact Table
- `dm.FactAppointment`

### 🔹 Dimension Tables
- `dm.DimDate`
- `dm.DimClinic`
- `dm.DimProvider`
- `dm.DimApptType`
- `dm.DimPatient`

### 🔹 Analytics Views
- `dm.vw_AppointmentDetail`
- `dm.vw_AppointmentKPI`

The model follows star schema best practices to support scalable reporting and KPI governance.

---

## 🔄 Data Pipeline

1. **raw layer** – Simulated source data (patients, appointments)
2. **stg layer** – Cleaned and standardized data
3. **dm layer** – Star schema dimensional model
4. **Analytics Views** – Pre-calculated KPIs
5. **Tableau Dashboard** – Executive visualization layer

---

## 📊 Core KPIs (Defined in SQL)

### No-Show Rate
```sql
SUM(CASE WHEN Status = 'No Show' THEN 1 ELSE 0 END) 
* 1.0 / COUNT(*)
```

### Utilization Rate
```sql
SUM(CASE WHEN Status = 'Completed' THEN 1 ELSE 0 END)
* 1.0 / COUNT(*)
```

### Cancel Rate
```sql
SUM(CASE WHEN Status = 'Cancelled' THEN 1 ELSE 0 END)
* 1.0 / COUNT(*)
```

### Average Wait Days
```sql
AVG(DATEDIFF(DAY, BookedDate, AppointmentDate))
```

---

## 🛠 Tech Stack

- Azure SQL Database  
- T-SQL (ETL + Dimensional Modeling)  
- Tableau Desktop / Tableau Public  
- Star Schema Design  
- CSV Export Integration  

---

## 📈 Dashboard Features

- Executive KPI Cards
- Weekly No-Show Trend Analysis
- Provider Performance Comparison
- Day × Hour Heatmap Analysis
- Clean container-based Tableau layout
- Governed KPI definitions from SQL layer

---

## 🎯 Key Outcome

Built an end-to-end healthcare BI solution transforming raw appointment data into executive-ready insights.  

Demonstrates:
- Dimensional modeling
- KPI standardization
- Data pipeline architecture
- Healthcare operational analytics
- Professional dashboard design

---

Created by **Kush Patel**
