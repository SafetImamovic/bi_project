# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Medical Appointments BI Solution - a full-stack Business Intelligence system for healthcare appointment analytics. Analyzes scheduling efficiency, patient behavior, operational performance, and resource utilization using Docker, PostgreSQL (Star Schema), n8n (ETL), SearxNG (AI Enrichment), and Power BI.

## Key Analytics Areas

- **Operational**: Slot utilization, throughput, appointment duration, on-time starts
- **Patient Experience**: Wait times, arrival punctuality
- **Scheduling**: No-show/cancellation rates, lead time, rebooking
- **Demographics**: Age group, gender, insurance provider patterns
- **Time-based**: Peak hours, day-of-week trends, seasonality

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   n8n ETL   │────▶│  PostgreSQL │◀────│  Power BI   │
│  :5678      │     │  (Star)     │     │  (Client)   │
└──────┬──────┘     └─────────────┘     └─────────────┘
       │
       ▼
┌─────────────┐
│  SearxNG    │  (AI context enrichment)
│  :8080      │
└─────────────┘
```

## Databases

- **stg_medical_dwh**: Staging (raw CSV data)
- **medical_dwh**: Star schema DWH

## Star Schema

**Dimensions**: `dim_date`, `dim_time`, `dim_status`, `dim_age_group`, `dim_insurance`, `dim_patient`

**Fact**: `fact_appointment` (grain: one row per appointment)

## Docker Services

Main stack (`docker-compose.yml`):
- **n8n**: ETL workflow automation (:5678)
- **db**: PostgreSQL database (:5432)
- **adminer**: Database UI (:8765)

## Environment

Credentials in `.env` (copy from `.env.example`):
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`
- `N8N_BASIC_AUTH_USER`, `N8N_BASIC_AUTH_PASSWORD`

## Common Commands

```bash
# Start services
docker compose up -d

# Create databases
docker compose exec db psql -U postgres -c "CREATE DATABASE stg_medical_dwh;"
docker compose exec db psql -U postgres -c "CREATE DATABASE medical_dwh;"

# Validate config
docker compose config -q
```

## Key Paths

- `data/`: Source CSV files (patients, slots, appointments)
- `n8n/workflows/etl_medical_appointments.json`: ETL workflow
- `.env`: Environment variables (git-ignored)
- `searxng-docker/`: SearxNG git submodule
