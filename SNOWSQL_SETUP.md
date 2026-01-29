# SnowSQL Setup and Usage Guide

## ✅ Installation Complete!

SnowSQL is now installed at: `/Applications/SnowSQL.app/Contents/MacOS/snowsql`

## 🚀 How to Connect

### Step 1: Get Your Snowflake Account Details

You'll need:
- **Account name** (e.g., `abc123.us-east-1`)
- **Username** (your Snowflake username)
- **Password** (your Snowflake password)

If you don't have a Snowflake account yet:
1. Go to https://signup.snowflake.com/
2. Sign up for a free trial (takes 2 minutes)
3. Note your account URL (e.g., `https://abc123.snowflakecomputing.com`)
4. Your account name is the part before `.snowflakecomputing.com`

### Step 2: Connect to Snowflake

Use the helper script I created:

```bash
./run-snowsql.sh -a <account_name> -u <username>
```

**Example:**
```bash
./run-snowsql.sh -a abc123.us-east-1 -u myusername
# You'll be prompted for password
```

Or with password (less secure):
```bash
./run-snowsql.sh -a abc123.us-east-1 -u myusername -p mypassword
```

### Step 3: Run the SQL Files

Once connected, you'll see the SnowSQL prompt:

```
username#(no warehouse)@(no database).(no schema)>
```

Now run these commands:

```sql
-- 1. Create database and schema
CREATE DATABASE IF NOT EXISTS BUDGET_PLANNING;
USE DATABASE BUDGET_PLANNING;
CREATE SCHEMA IF NOT EXISTS Planning;
USE SCHEMA Planning;

-- 2. Create a warehouse (compute resource)
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH 
    WAREHOUSE_SIZE = 'XSMALL' 
    AUTO_SUSPEND = 60 
    AUTO_RESUME = TRUE;
USE WAREHOUSE COMPUTE_WH;

-- 3. Run the schema file
!source snowflake-migration/schema/01_tables.sql

-- 4. Run the procedure file
!source snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql

-- 5. Verify it worked
SHOW TABLES IN SCHEMA Planning;
SHOW PROCEDURES IN SCHEMA Planning;
```

## 📝 Alternative: Run Files Directly

You can also run SQL files without entering the interactive prompt:

```bash
# Run schema
./run-snowsql.sh -a <account> -u <username> -f snowflake-migration/schema/01_tables.sql

# Run procedure
./run-snowsql.sh -a <account> -u <username> -f snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql
```

## 🧪 Quick Test

Here's a complete test script:

```bash
# Save your connection details
ACCOUNT="your_account_name"
USERNAME="your_username"

# Connect and run everything
./run-snowsql.sh -a $ACCOUNT -u $USERNAME << 'EOF'
-- Setup
CREATE DATABASE IF NOT EXISTS BUDGET_PLANNING;
USE DATABASE BUDGET_PLANNING;
CREATE SCHEMA IF NOT EXISTS Planning;
USE SCHEMA Planning;

CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH 
    WAREHOUSE_SIZE = 'XSMALL' 
    AUTO_SUSPEND = 60 
    AUTO_RESUME = TRUE;
USE WAREHOUSE COMPUTE_WH;

-- Create a simple test table
CREATE OR REPLACE TABLE Planning.TestTable (
    id INTEGER,
    name VARCHAR(100)
);

-- Insert test data
INSERT INTO Planning.TestTable VALUES (1, 'Test');

-- Query it
SELECT * FROM Planning.TestTable;

-- Clean up
DROP TABLE Planning.TestTable;
EOF
```

## 🔧 Configuration File (Optional)

Create a config file to avoid typing credentials every time:

```bash
mkdir -p ~/.snowsql
cat > ~/.snowsql/config << 'EOF'
[connections.myconnection]
accountname = your_account_name
username = your_username
# password = your_password  # Optional, will prompt if not set
dbname = BUDGET_PLANNING
schemaname = Planning
warehousename = COMPUTE_WH
EOF
```

Then connect with:
```bash
./run-snowsql.sh -c myconnection
```

## 📚 Useful SnowSQL Commands

Once connected:

```sql
-- Show current context
!set

-- List databases
SHOW DATABASES;

-- List schemas
SHOW SCHEMAS;

-- List tables
SHOW TABLES;

-- List procedures
SHOW PROCEDURES;

-- Run a file
!source path/to/file.sql

-- Exit
!exit
```

## 🎯 Next Steps

1. **Get Snowflake account** (if you don't have one)
2. **Connect using the helper script**: `./run-snowsql.sh -a <account> -u <username>`
3. **Run the schema**: `!source snowflake-migration/schema/01_tables.sql`
4. **Run the procedure**: `!source snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql`
5. **Test it**: Follow the test cases in `QUICK_START.md`

## ❓ Troubleshooting

### "Connection refused"
- Check your account name is correct
- Verify you can access Snowflake web UI
- Check your network/firewall

### "Authentication failed"
- Verify username and password
- Check if MFA is enabled (use `--mfa-passcode` flag)

### "Warehouse not found"
- Create a warehouse first (see Step 3 above)
- Or use an existing warehouse: `USE WAREHOUSE <name>;`

### "Permission denied"
- Make sure your user has appropriate privileges
- Contact your Snowflake admin

## 🆘 Need Help?

If you run into issues:
1. Check the SnowSQL docs: https://docs.snowflake.com/en/user-guide/snowsql
2. Verify your Snowflake account is active
3. Try the Snowflake Web UI first (easier for testing)

---

**Ready to run?** Just execute:
```bash
./run-snowsql.sh -a <your_account> -u <your_username>
```
