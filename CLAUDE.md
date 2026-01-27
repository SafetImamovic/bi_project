# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Medical Appointments BI Solution - a full-stack Business Intelligence system to analyze Medical Appointment No-Shows using Docker, PostgreSQL (Star Schema), n8n (ETL), SearxNG (AI Enrichment), and Power BI.

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

**Star Schema**: `fact_appointment` with dimensions `dim_patient`, `dim_location`, `dim_date`

## Docker Services

Main stack (`docker-compose.yml`):
- **n8n**: ETL workflow automation (:5678)
- **db**: PostgreSQL database
- **adminer**: Database UI (:8765)

SearxNG stack (`searxng-docker/docker-compose.yaml`):
- **searxng**: Meta search engine (:8080)
- **redis**: Cache backend
- **caddy**: Reverse proxy

## Common Commands

```bash
# Start main services
docker compose up -d

# Start SearxNG (separate compose in submodule)
cd searxng-docker && docker compose up -d

# Create shared network for inter-stack communication
docker network create bi_projekat || true
docker network connect bi_projekat searxng

# Import n8n workflow from container
docker exec -it -u node <container_id> n8n import:workflow --separate --input=/home/node/workflows/

# Validate Docker Compose config
docker compose config -q
```

## Service Connections

| Service | Internal Host | Port | Credentials |
|---------|--------------|------|-------------|
| PostgreSQL | `db` | 5432 | postgres / bi_projekat |
| Adminer | localhost | 8765 | - |
| n8n | localhost | 5678 | username / password |
| SearxNG | `searxng` | 8080 | - |

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on push/PR to main:
1. Validates Docker Compose configuration
2. Checks for `local-files/init.sql` existence (SQL linting placeholder)

## Key Paths

- `n8n/workflows/`: n8n workflow JSON files (mounted to container at `/home/node/workflows`)
- `local-files/init.sql`: Database schema initialization script
- `local-files/csv_dropzone/`: Drop CSV data files here for ETL processing
- `searxng-docker/`: SearxNG git submodule
