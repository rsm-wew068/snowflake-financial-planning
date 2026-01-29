#!/bin/bash
# Helper script to run SnowSQL

SNOWSQL_PATH="/Applications/SnowSQL.app/Contents/MacOS/snowsql"

if [ ! -f "$SNOWSQL_PATH" ]; then
    echo "Error: SnowSQL not found at $SNOWSQL_PATH"
    exit 1
fi

# Run SnowSQL with all arguments passed to this script
"$SNOWSQL_PATH" "$@"
