# How to Run the SQL - Complete Guide

## ✅ SnowSQL is Installed!

SnowSQL version 1.3.1 is now installed on your Mac.

## 🎯 Three Ways to Run

### Option 1: Automated Setup (Easiest) ⭐

Run everything in one command:

```bash
./setup-and-run.sh
```

This will:
1. Test your connection
2. Create database and schema
3. Create all tables
4. Create the stored procedure
5. Verify everything worked

**You'll need:**
- Snowflake account name (e.g., `abc123.us-east-1`)
- Username
- Password

---

### Option 2: Step-by-Step (Recommended for Learning)

#### Step 1: Test Connection
```bash
./test-snowflake.sh
```

#### Step 2: Connect Interactively
```bash
./run-snowsql.sh -a <account> -u <username>
# Enter password when prompted
```

#### Step 3: Setup Database
```sql
CREATE DATABASE IF NOT EXISTS BUDGET_PLANNING;
USE DATABASE BUDGET_PLANNING;
CREATE SCHEMA IF NOT EXISTS Planning;
USE SCHEMA Planning;

CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH 
    WAREHOUSE_SIZE = 'XSMALL' 
    AUTO_SUSPEND = 60 
    AUTO_RESUME = TRUE;
USE WAREHOUSE COMPUTE_WH;
```

#### Step 4: Run Schema File
```sql
!source snowflake-migration/schema/01_tables.sql
```

#### Step 5: Run Procedure File
```sql
!source snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql
```

#### Step 6: Verify
```sql
SHOW TABLES IN SCHEMA Planning;
SHOW PROCEDURES IN SCHEMA Planning;
```

---

### Option 3: Direct File Execution

Run files without interactive mode:

```bash
# Setup
./run-snowsql.sh -a <account> -u <username> -q "
CREATE DATABASE IF NOT EXISTS BUDGET_PLANNING;
USE DATABASE BUDGET_PLANNING;
CREATE SCHEMA IF NOT EXISTS Planning;
USE SCHEMA Planning;
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH WAREHOUSE_SIZE = 'XSMALL';
USE WAREHOUSE COMPUTE_WH;
"

# Run schema
./run-snowsql.sh -a <account> -u <username> \
    -d BUDGET_PLANNING -s Planning -w COMPUTE_WH \
    -f snowflake-migration/schema/01_tables.sql

# Run procedure
./run-snowsql.sh -a <account> -u <username> \
    -d BUDGET_PLANNING -s Planning -w COMPUTE_WH \
    -f snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql
```

---

## 🆕 Don't Have a Snowflake Account?

### Sign Up (2 minutes, free):

1. Go to https://signup.snowflake.com/
2. Fill in your details
3. Choose:
   - **Edition**: Standard (free trial)
   - **Cloud**: AWS, Azure, or GCP (any is fine)
   - **Region**: Choose closest to you
4. Verify your email
5. Log in to get your account name

Your account name is in the URL:
- URL: `https://abc123.snowflakecomputing.com`
- Account name: `abc123` (or `abc123.us-east-1` with region)

---

## 📋 Quick Reference

### Helper Scripts Created

| Script | Purpose |
|--------|---------|
| `run-snowsql.sh` | Run SnowSQL commands |
| `test-snowflake.sh` | Test your connection |
| `setup-and-run.sh` | Complete automated setup |

### Files to Run

| File | Description |
|------|-------------|
| `snowflake-migration/schema/01_tables.sql` | Creates all tables |
| `snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql` | Creates the stored procedure |

---

## 🧪 Test After Setup

Once everything is set up, test the procedure:

```bash
./run-snowsql.sh -a <account> -u <username> -d BUDGET_PLANNING -s Planning -w COMPUTE_WH
```

Then in SnowSQL:

```sql
-- Load test data (from QUICK_START.md)
-- Then test the procedure:

CALL Planning.usp_ProcessBudgetConsolidation(
    SourceBudgetHeaderID => 1,
    ConsolidationType => 'FULL',
    IncludeEliminations => TRUE,
    RecalculateAllocations => TRUE,
    ProcessingOptions => NULL,
    UserID => 100,
    DebugMode => TRUE
);
```

---

## 🔍 Verify Results

```sql
-- Check created budget
SELECT * FROM Planning.BudgetHeader 
WHERE BudgetType = 'CONSOLIDATED' 
ORDER BY BudgetHeaderID DESC LIMIT 1;

-- Check line items
SELECT COUNT(*) AS line_count 
FROM Planning.BudgetLineItem 
WHERE BudgetHeaderID = (
    SELECT MAX(BudgetHeaderID) 
    FROM Planning.BudgetHeader 
    WHERE BudgetType = 'CONSOLIDATED'
);
```

---

## 📚 Documentation

- **Detailed setup**: `SNOWSQL_SETUP.md`
- **Quick start guide**: `QUICK_START.md`
- **Test data and verification**: `snowflake-migration/testing/verification_approach.md`
- **Full deliverables**: `DELIVERABLES_SUMMARY.md`

---

## ❓ Troubleshooting

### "Command not found: snowsql"
✅ **Fixed!** Use `./run-snowsql.sh` instead

### "Connection refused"
- Check account name format (include region if needed)
- Verify you can access Snowflake web UI
- Try: `abc123.us-east-1` instead of just `abc123`

### "Authentication failed"
- Double-check username and password
- Check if MFA is enabled (you'll need the passcode)

### "Warehouse not found"
- Run the CREATE WAREHOUSE command first
- Or use an existing warehouse name

### "Permission denied"
- Your user needs CREATE privileges
- Contact your Snowflake admin

---

## 🎉 Summary

**Easiest way to get started:**

1. Get Snowflake account (if needed): https://signup.snowflake.com/
2. Run: `./setup-and-run.sh`
3. Follow the prompts
4. Done! ✅

**Total time:** ~5 minutes

---

## 💡 Tips

- **Save credentials**: Create `~/.snowsql/config` (see SNOWSQL_SETUP.md)
- **Use Web UI**: If CLI is tricky, use Snowflake Web UI (easier for first time)
- **Start small**: Test connection first with `./test-snowflake.sh`
- **Read docs**: Check `QUICK_START.md` for detailed test cases

---

**Need help?** All documentation is in this repository. Start with `README_SUBMISSION.md` for an overview.
