#!/bin/bash
# Setup SQL Server in Docker for macOS

echo "=========================================="
echo "SQL Server Setup for macOS"
echo "=========================================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

echo "✅ Docker is running"
echo ""

# Pull SQL Server image (Azure SQL Edge for ARM compatibility)
echo "Pulling SQL Server image (Azure SQL Edge for Apple Silicon)..."
docker pull mcr.microsoft.com/azure-sql-edge:latest

echo ""
echo "Starting SQL Server container..."
echo ""

# Run SQL Server container
docker run -d \
    --name sqlserver-takehome \
    -e 'ACCEPT_EULA=Y' \
    -e 'MSSQL_SA_PASSWORD=YourStrong@Passw0rd' \
    -p 1433:1433 \
    mcr.microsoft.com/azure-sql-edge:latest

echo ""
echo "Waiting for SQL Server to start (30 seconds)..."
sleep 30

echo ""
echo "=========================================="
echo "✅ SQL Server Setup Complete!"
echo "=========================================="
echo ""
echo "Connection Details:"
echo "  Server: localhost,1433"
echo "  Username: sa"
echo "  Password: YourStrong@Passw0rd"
echo ""
echo "To connect:"
echo "  docker exec -it sqlserver-takehome /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd'"
echo ""
echo "To stop:"
echo "  docker stop sqlserver-takehome"
echo ""
echo "To remove:"
echo "  docker rm sqlserver-takehome"
echo ""
