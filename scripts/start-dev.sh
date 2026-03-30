#!/bin/bash

# SciMiner 2.0 Development Start Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Create network if it doesn't exist
create_network() {
    if ! docker network inspect sciminer-network > /dev/null 2>&1; then
        print_info "Creating Docker network..."
        docker network create sciminer-network
    fi
}

# Start development environment
start_dev() {
    print_header "Starting SciMiner 2.0 Development Environment"

    check_docker
    create_network

    print_info "Starting services with development configuration..."

    # Use docker-compose with both production and dev files
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

    print_info "Waiting for services to be ready..."
    sleep 20

    print_header "Services Started Successfully!"
    echo ""
    print_info "Development URLs:"
    echo "  • Frontend (React):     http://localhost:3000"
    echo "  • Backend API:          http://localhost:8000"
    echo "  • API Documentation:    http://localhost:8000/docs"
    echo "  • Nginx Proxy:          http://localhost:8888"
    echo "  • Database Admin:       http://localhost:8080 (Adminer)"
    echo "  • Redis Commander:      http://localhost:8081"
    echo ""
    print_info "Database Connection:"
    echo "  • Host: localhost"
    echo "  • Port: 3306"
    echo "  • Database: sciminer"
    echo "  • User: sciminer"
    echo ""
    print_warning "Press Ctrl+C to stop watching logs"
    echo ""

    # Show logs
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f
}

# Stop development environment
stop_dev() {
    print_info "Stopping development environment..."
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml down
    print_info "Services stopped"
}

# Reset development environment
reset_dev() {
    print_warning "This will remove all containers and volumes. Are you sure? (y/N)"
    read -r response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        print_info "Resetting development environment..."
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v
        docker system prune -f
        print_info "Reset completed"
    else
        print_info "Reset cancelled"
    fi
}

# Install dependencies
install_deps() {
    print_header "Installing Dependencies"

    print_info "Installing backend dependencies..."
    cd backend
    pip install -r requirements.txt
    cd ..

    print_info "Installing frontend dependencies..."
    cd frontend
    npm install
    cd ..

    print_info "Dependencies installed successfully"
}

# Run backend tests
test_backend() {
    print_info "Running backend tests..."
    cd backend
    python -m pytest tests/ -v
    cd ..
}

# Run frontend tests
test_frontend() {
    print_info "Running frontend tests..."
    cd frontend
    npm test
    cd ..
}

# Show help
show_help() {
    echo "SciMiner 2.0 Development Script"
    echo ""
    echo "Usage: $0 {start|stop|reset|install|test-backend|test-front|logs|help}"
    echo ""
    echo "Commands:"
    echo "  start         Start development environment"
    echo "  stop          Stop development environment"
    echo "  reset         Reset environment (removes all data)"
    echo "  install       Install Python and Node dependencies"
    echo "  test-backend  Run backend tests"
    echo "  test-frontend Run frontend tests"
    echo "  logs          Show logs"
    echo "  help          Show this help message"
}

# Main
case "$1" in
    "start")
        start_dev
        ;;
    "stop")
        stop_dev
        ;;
    "reset")
        reset_dev
        ;;
    "install")
        install_deps
        ;;
    "test-backend")
        test_backend
        ;;
    "test-frontend")
        test_frontend
        ;;
    "logs")
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Invalid command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac