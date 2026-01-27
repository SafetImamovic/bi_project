# Medical Appointments BI Solution

## Overview

A full-stack Business Intelligence system to analyze Medical Appointment No-Shows.
**Stack**: Docker, PostgreSQL (Star Schema), n8n (ETL), SearxNG (AI Enrichment), Power BI.

## 📂 Project Structure

```text
.
├── docker-compose.yml       # Main infrastructure (n8n, Postgres, Adminer)
├── searxng-docker/          # AI Search Engine (Submodule)
├── local-files/
│   ├── init.sql             # DB Entrypoint (Schema Definition)
│   ├── csv_dropzone/        # Place 'KaggleV2-May-2016.csv' here
│   └── workflows/
│       └── n8n_workflow.json # Import this into n8n
└── README.md
```

## 🚀 Setup & Deployment

### 1. Networking (Crucial)

Ensure `n8n` can talk to `searxng`.

```bash
# Create shared network if not exists
docker network create bi_projekat || true

# Connect running searxng to it (if not in compose)
docker network connect bi_projekat searxng
```

### 2. Database Initialization

The `init.sql` script requires a fresh container start or manual run.

```bash
# Verify file exists
ls local-files/init.sql

# Restart DB to apply (if mounted to /docker-entrypoint-initdb.d)
docker compose restart db
```

*Alternatively, paste content of `init.sql` into Adminer (localhost:8765 -> Postgres).*

### 3. ETL (n8n)

1. **Login**: `http://localhost:5678`
2. **Credentials**:
    * **Postgres**: Host `db`, User `postgres`, Pass `bi_projekat`, DB `postgres`.
3. **Import Workflow**:
    * **Workflows** -> **Import from File**.
    * Navigate to `/files/workflows/n8n_workflow.json` (inside the container).
    * *Note*: On your host machine, this file is at `local-files/workflows/n8n_workflow.json`. You can edit it here and re-import to update.
4. **Run**:
    * Drop your CSV into `local-files/csv_dropzone/`.
    * Activate workflow.

### 4. Power BI Connection

* **Server**: `localhost` (if port 5432 mapped) or `host.docker.internal`.
* **Database**: `postgres`
* **User/Pass**: `postgres` / `bi_projekat`
* **Mode**: DirectQuery (recommended for real-time) or Import.

## 📊 Data Schema (Star Schema)

* **Fact**: `fact_appointment` (Measures: Count, Lead Time, No-show flag).
* **Dims**: `dim_patient`, `dim_location`, `dim_date`.

## 🤖 AI Agent Integration

* **SearxNG API**: `http://searxng:8080` (internal Docker DNS).
* **Usage**: n8n HTTP Request node queries SearxNG for external context (e.g., "Demographics of Neighbourhood X").

## 🧪 CI/CD

* GitHub Actions workflow located in `.github/workflows/ci.yml`.
* Checks: SQL Syntax linting (placeholder), Docker Compose config validation.
