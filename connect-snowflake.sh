#!/bin/bash
# Better connection script that handles special characters in passwords

echo "=========================================="
echo "Snowflake Connection (Secure Method)"
echo "=========================================="
echo ""

# Get credentials
read -p "Account name: " ACCOUNT
read -p "Username: " USERNAME
read -sp "Password: " PASSWORD
echo ""
echo ""

# Create temporary config file
TEMP_CONFIG=$(mktemp)
cat > "$TEMP_CONFIG" << EOF
[connections.temp]
accountname = $ACCOUNT
username = $USERNAME
password = $PASSWORD
EOF

echo "Testing connection..."
echo ""

# Connect using config file
/Applications/SnowSQL.app/Contents/MacOS/snowsql \
    -c temp \
    --config "$TEMP_CONFIG" \
    -q "SELECT CURRENT_VERSION() AS version, CURRENT_USER() AS user, CURRENT_ACCOUNT() AS account;"

RESULT=$?

# Clean up
rm -f "$TEMP_CONFIG"

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Connection successful!"
    echo "=========================================="
    echo ""
    echo "Now run the full setup:"
    echo "  ./run-full-setup.sh"
else
    echo ""
    echo "=========================================="
    echo "❌ Connection failed!"
    echo "=========================================="
    echo ""
    echo "Please verify your credentials in Snowflake Web UI first."
fi
