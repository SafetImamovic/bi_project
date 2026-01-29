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
       │                   ▲
       ▼                   │
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  SearxNG    │     │   ngrok     │◀────│  Discord    │
│  :8080      │     │  (tunnel)   │     │    Bot      │
└─────────────┘     └─────────────┘     └─────────────┘
```

## Databases

- **stg_medical_dwh**: Staging (raw CSV data)
- **medical_dwh**: Star schema DWH

## Star Schema

**Dimensions**: `dim_date`, `dim_time`, `dim_status`, `dim_age_group`, `dim_insurance`, `dim_patient`

**Fact**: `fact_appointment` (grain: one row per appointment)

**Aggregates** (pre-calculated metrics):
- `agg_daily`: Daily KPIs (appointments, no-shows, rates, revenue)
- `agg_monthly`: Monthly rollups with MoM growth %
- `agg_yearly`: Yearly totals with YoY comparisons built-in

## Docker Services

Main stack (`docker-compose.yml`):
- **n8n**: ETL workflow automation (:5678)
- **db**: PostgreSQL database (:5432)
- **adminer**: Database UI (:8765)

## Environment

All credentials centralized in root `.env` (copy from `.env.example`):

**Database:**
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`

**n8n:**
- `N8N_BASIC_AUTH_USER`, `N8N_BASIC_AUTH_PASSWORD`
- `N8N_WEBHOOK_URL` (full webhook URL for Discord integration)

**ngrok:**
- `NGROK_AUTHTOKEN`, `NGROK_DOMAIN`

**Discord Bot:**
- `DISCORD_TOKEN`, `DISCORD_CLIENT_ID`, `DISCORD_GUILD_ID`

## Common Commands

**Setup Scripts (Recommended):**
```powershell
# Windows
.\setup.ps1 setup       # Full setup
.\setup.ps1 etl-run     # Run ETL
.\setup.ps1 bot-start   # Start Discord bot
```

```bash
# Linux/macOS
./setup.sh setup        # Full setup
./setup.sh etl-run      # Run ETL
./setup.sh bot-start    # Start Discord bot
```

**Manual Commands:**
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
- `n8n/workflows/ETL Medical Appointments.json`: ETL workflow
- `discord-bot/`: Discord bot (uses parent `.env`)
- `powerbi-mcp-server/`: Power BI MCP integration
- `.env`: All environment variables (git-ignored)
- `searxng-docker/`: SearxNG git submodule

## Discord Bot Commands

- `/verify-data`: Returns DWH table row counts via n8n webhook
