#!/bin/bash

#===============================================================================
# Medical Appointments BI Project - Setup Script
#
# Usage: ./setup.sh <action>
# Actions: setup, start, stop, reset, cleanup, bot-start, bot-deploy, etl-run, help
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# Paths
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"
DISCORD_BOT_DIR="$PROJECT_ROOT/discord-bot"
N8N_WORKFLOW="$PROJECT_ROOT/n8n/workflows/ETL Medical Appointments.json"

# Output functions
step()    { echo -e "\n${CYAN}[*] $1${NC}"; }
success() { echo -e "${GREEN}[+] $1${NC}"; }
error()   { echo -e "${RED}[-] $1${NC}"; }
info()    { echo -e "${GRAY}    $1${NC}"; }

# Load environment variables
load_env() {
    if [ -f "$ENV_FILE" ]; then
        export $(grep -v '^#' "$ENV_FILE" | xargs)
        return 0
    fi
    return 1
}

# Check prerequisites
check_prerequisites() {
    step "Checking prerequisites..."
    local missing=()

    if ! command -v docker &> /dev/null; then
        missing+=("Docker")
    else
        success "Docker found"
    fi

    if ! docker compose version &> /dev/null; then
        missing+=("Docker Compose")
    else
        success "Docker Compose found"
    fi

    if ! command -v node &> /dev/null; then
        missing+=("Node.js")
    else
        success "Node.js found ($(node --version))"
    fi

    if ! command -v npm &> /dev/null; then
        missing+=("npm")
    else
        success "npm found"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing prerequisites: ${missing[*]}"
        info "Please install the missing tools and try again."
        return 1
    fi

    return 0
}

# Check environment file
check_env() {
    step "Checking environment configuration..."

    if [ ! -f "$ENV_FILE" ]; then
        info ".env file not found, creating from template..."
        if [ -f "$ENV_EXAMPLE" ]; then
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            success "Created .env from .env.example"
            info "Please edit .env with your actual credentials before continuing."
            return 1
        else
            error ".env.example not found!"
            return 1
        fi
    fi

    load_env

    # Validate required variables
    local required=("POSTGRES_USER" "POSTGRES_PASSWORD" "N8N_BASIC_AUTH_USER" "N8N_BASIC_AUTH_PASSWORD")
    local missing=()

    for var in "${required[@]}"; do
        if [ -z "${!var}" ]; then
            missing+=("$var")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required environment variables: ${missing[*]}"
        return 1
    fi

    success "Environment configuration valid"
    return 0
}

# Start Docker services
start_docker() {
    step "Starting Docker services..."
    cd "$PROJECT_ROOT"
    docker compose up -d
    success "Docker services started"
}

# Stop Docker services
stop_docker() {
    step "Stopping Docker services..."
    cd "$PROJECT_ROOT"
    docker compose down
    success "Docker services stopped"
}

# Wait for service
wait_for_service() {
    local name=$1
    local check_cmd=$2
    local max_attempts=${3:-30}
    local delay=${4:-2}

    info "Waiting for $name to be ready..."

    for ((i=1; i<=max_attempts; i++)); do
        if eval "$check_cmd" &> /dev/null; then
            success "$name is ready"
            return 0
        fi
        echo -n "."
        sleep $delay
    done

    echo ""
    error "$name failed to become ready after $((max_attempts * delay)) seconds"
    return 1
}

# Wait for PostgreSQL
wait_for_postgres() {
    wait_for_service "PostgreSQL" "docker compose exec -T db pg_isready -U postgres"
}

# Wait for n8n
wait_for_n8n() {
    wait_for_service "n8n" "curl -sf http://localhost:5678/healthz" 45
}

# Create databases
init_databases() {
    step "Creating databases..."

    local exists=$(docker compose exec -T db psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='stg_medical_dwh'")
    if [ "$exists" != "1" ]; then
        docker compose exec -T db psql -U postgres -c "CREATE DATABASE stg_medical_dwh;"
        success "Created database: stg_medical_dwh"
    else
        info "Database stg_medical_dwh already exists"
    fi

    exists=$(docker compose exec -T db psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='medical_dwh'")
    if [ "$exists" != "1" ]; then
        docker compose exec -T db psql -U postgres -c "CREATE DATABASE medical_dwh;"
        success "Created database: medical_dwh"
    else
        info "Database medical_dwh already exists"
    fi
}

# Import n8n workflow
import_workflow() {
    step "Importing n8n ETL workflow..."

    if [ ! -f "$N8N_WORKFLOW" ]; then
        error "Workflow file not found: $N8N_WORKFLOW"
        return 1
    fi

    local creds=$(echo -n "$N8N_BASIC_AUTH_USER:$N8N_BASIC_AUTH_PASSWORD" | base64)
    local workflow=$(cat "$N8N_WORKFLOW")

    # Check if workflow exists
    local existing=$(curl -sf -H "Authorization: Basic $creds" \
        "http://localhost:5678/api/v1/workflows" | \
        jq -r '.data[] | select(.name=="ETL Medical Appointments") | .id')

    if [ -n "$existing" ]; then
        info "Workflow already exists (ID: $existing), updating..."
        curl -sf -X PUT -H "Authorization: Basic $creds" \
            -H "Content-Type: application/json" \
            -d "$workflow" \
            "http://localhost:5678/api/v1/workflows/$existing" > /dev/null
        success "Workflow updated"
    else
        local result=$(curl -sf -X POST -H "Authorization: Basic $creds" \
            -H "Content-Type: application/json" \
            -d "$workflow" \
            "http://localhost:5678/api/v1/workflows")
        local id=$(echo "$result" | jq -r '.id')
        success "Workflow imported (ID: $id)"
    fi
}

# Run ETL
run_etl() {
    step "Running ETL workflow..."

    local creds=$(echo -n "$N8N_BASIC_AUTH_USER:$N8N_BASIC_AUTH_PASSWORD" | base64)

    local workflow_id=$(curl -sf -H "Authorization: Basic $creds" \
        "http://localhost:5678/api/v1/workflows" | \
        jq -r '.data[] | select(.name=="ETL Medical Appointments") | .id')

    if [ -z "$workflow_id" ]; then
        error "ETL workflow not found. Please import it first."
        return 1
    fi

    info "Executing workflow (this may take a few minutes)..."
    local result=$(curl -sf -X POST -H "Authorization: Basic $creds" \
        -H "Content-Type: application/json" \
        -d "{}" \
        "http://localhost:5678/api/v1/workflows/$workflow_id/run")

    local exec_id=$(echo "$result" | jq -r '.id')
    success "ETL workflow executed (Execution ID: $exec_id)"
    info "Check n8n UI for details: http://localhost:5678"
}

# Setup Discord bot
setup_discord_bot() {
    step "Setting up Discord bot..."

    if [ ! -d "$DISCORD_BOT_DIR" ]; then
        error "Discord bot directory not found"
        return 1
    fi

    cd "$DISCORD_BOT_DIR"
    info "Installing dependencies..."
    npm install
    success "Discord bot dependencies installed"
    cd "$PROJECT_ROOT"
}

# Deploy Discord commands
deploy_discord_commands() {
    step "Deploying Discord commands..."

    if [ -z "$DISCORD_TOKEN" ] || [ -z "$DISCORD_CLIENT_ID" ] || [ -z "$DISCORD_GUILD_ID" ]; then
        error "Missing Discord credentials in .env"
        info "Required: DISCORD_TOKEN, DISCORD_CLIENT_ID, DISCORD_GUILD_ID"
        return 1
    fi

    cd "$DISCORD_BOT_DIR"
    node deploy-commands.js
    success "Discord commands deployed"
    cd "$PROJECT_ROOT"
}

# Start Discord bot
start_discord_bot() {
    step "Starting Discord bot..."

    if [ -z "$DISCORD_TOKEN" ]; then
        error "DISCORD_TOKEN not set in .env"
        return 1
    fi

    cd "$DISCORD_BOT_DIR"
    info "Bot starting... Press Ctrl+C to stop"
    node index.js
}

# Reset databases
reset_databases() {
    step "Resetting databases (destructive)..."

    read -p "This will DELETE all data. Type 'yes' to confirm: " confirm
    if [ "$confirm" != "yes" ]; then
        info "Aborted"
        return
    fi

    docker compose exec -T db psql -U postgres -c "DROP DATABASE IF EXISTS stg_medical_dwh;"
    docker compose exec -T db psql -U postgres -c "DROP DATABASE IF EXISTS medical_dwh;"

    init_databases
    success "Databases reset"
}

# Full cleanup
full_cleanup() {
    step "Full cleanup (destructive)..."

    read -p "This will DELETE all containers, volumes, and data. Type 'yes' to confirm: " confirm
    if [ "$confirm" != "yes" ]; then
        info "Aborted"
        return
    fi

    cd "$PROJECT_ROOT"
    docker compose down -v

    if [ -d "$DISCORD_BOT_DIR/node_modules" ]; then
        rm -rf "$DISCORD_BOT_DIR/node_modules"
    fi

    success "Cleanup complete"
}

# Show help
show_help() {
    cat << EOF

Medical Appointments BI Project - Setup Script
===============================================

Usage: ./setup.sh <action>

Actions:
  setup       Full initial setup (recommended for first run)
  start       Start Docker services only
  stop        Stop Docker services
  reset       Reset databases (destructive)
  cleanup     Full cleanup - removes containers, volumes, data (destructive)
  bot-start   Start the Discord bot
  bot-deploy  Deploy Discord slash commands
  etl-run     Run the ETL workflow
  help        Show this help message

Examples:
  ./setup.sh setup      # First time setup
  ./setup.sh start      # Start services after setup
  ./setup.sh bot-start  # Run Discord bot in foreground

Prerequisites:
  - Docker
  - Node.js (v18+)
  - curl, jq
  - .env file configured (copy from .env.example)

EOF
}

# Full setup
full_setup() {
    check_prerequisites || exit 1
    check_env || exit 1
    start_docker
    wait_for_postgres || exit 1
    init_databases
    wait_for_n8n || exit 1
    import_workflow || info "Continuing without workflow import..."
    setup_discord_bot || exit 1

    echo ""
    echo "======================================"
    success "Setup complete!"
    echo "======================================"
    echo ""
    echo "Next steps:"
    echo "  1. Open n8n at http://localhost:5678"
    echo "  2. Configure PostgreSQL credentials in n8n"
    echo "  3. Run the ETL workflow: ./setup.sh etl-run"
    echo "  4. Deploy Discord commands: ./setup.sh bot-deploy"
    echo "  5. Start Discord bot: ./setup.sh bot-start"
    echo ""
}

# Main
main() {
    echo ""
    echo "======================================"
    echo "  Medical Appointments BI Setup"
    echo "======================================"

    case "${1:-help}" in
        setup)      full_setup ;;
        start)      check_env && start_docker ;;
        stop)       stop_docker ;;
        reset)      check_env && reset_databases ;;
        cleanup)    full_cleanup ;;
        bot-start)  check_env && load_env && start_discord_bot ;;
        bot-deploy) check_env && load_env && setup_discord_bot && deploy_discord_commands ;;
        etl-run)    check_env && load_env && run_etl ;;
        help)       show_help ;;
        *)          error "Unknown action: $1" && show_help && exit 1 ;;
    esac
}

main "$@"
