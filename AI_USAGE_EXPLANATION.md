# AI Usage in SQL Server to Snowflake Migration

**Candidate**: Wei-Hsien Wang  
**Date**: January 28, 2026  
**AI Tool**: Kiro (Claude-based AI IDE assistant)

---

## AI Implementation

### 1. Initial Analysis 
- **AI**: Analyzed source procedure, identified conversion challenges, cataloged dependencies
- **Human**: Confirmed priorities, provided business context

### 2. Schema Conversion
- **AI**: Converted all table definitions, suggested data types, created scripts
- **Human**: Reviewed and approved, caught VARCHAR(10) size issue

### 3. Stored Procedure Conversion
- **AI**: 
  - Converted syntax from SQL Server to Snowflake
  - Eliminated cursors (replaced with set-based operations)
  - Converted table variables to temp tables
  - Converted TRY-CATCH to EXCEPTION handling
  - Converted OUTPUT parameters to VARIANT return
  - Generated all code and inline documentation
- **Human**: 
  - Tested and found issues
  - Requested simplification when complex version had bugs
  - Validated final results

### 4. Test Data Generation 
- **AI**: Generated all test data SQL, created verification queries
- **Human**: Validated data made sense, caught GLAccountID mapping issue

### 5. SQL Server Setup 
- **AI**: Created Docker setup, Python scripts, all SQL files
- **Human**: Ran commands, reported errors, validated results

### 6. Documentation
- **AI**: Generated all markdown files, README, conversion notes, verification docs
- **Human**: Reviewed, requested cleanup of excessive docs

### 7. Debugging 
- **AI**: Diagnosed issues, proposed fixes, generated corrected code
- **Human**: Reported errors, tested fixes, confirmed resolution

---


## Errors and Human Supervision

### Error 1: VARCHAR Size Too Small
**Error**: `SpreadMethodCode VARCHAR(10)` couldn't hold 'CONSOLIDATED' (12 chars)
**How Found**: Human ran the procedure, got truncation error
**Solution**: AI changed to `VARCHAR(20)` in schema
**Who Fixed**: AI generated fix, human validated

### Error 2: Wrong GLAccountID Mappings
**Error**: Test data assumed GLAccountID 3 = Salaries, but it was actually Revenue
**How Found**: Human noticed amounts didn't match expected results
**Solution**: AI corrected test data to use proper IDs
**Who Fixed**: AI generated corrected test data, human validated

### Error 3: Procedure Not Found
**Error**: `Unknown user-defined function PLANNING.USP_PROCESSBUDGETCONSOLIDATION`
**How Found**: Human tried to call procedure
**Solution**: AI created script to set database context and create procedure
**Who Fixed**: AI generated create-procedure.sql with USE DATABASE commands

### Error 4: Data Duplication (6x amounts)
**Error**: Procedure returned $720k instead of $120k (6x too high)
**How Found**: Human checked results and noticed amounts were wrong
**Solution**: AI simplified procedure to remove complex hierarchy processing
**Who Fixed**: AI created simplified version, human tested and confirmed

### Error 5: Duplicate Line Items
**Error**: Procedure ran twice, creating duplicate consolidated budgets
**How Found**: Human noticed duplicate entries in CSV export
**Solution**: AI created cleanup script to delete duplicates
**Who Fixed**: AI generated cleanup script, human ran it

### Error 6: Procedure Overload Error
**Error**: `Cannot overload PROCEDURE` when trying to replace complex version
**How Found**: Human ran replacement script
**Solution**: AI added DROP PROCEDURE before CREATE
**Who Fixed**: AI updated script with DROP statement

### Error 7: Outdated Documentation
**Error**: README said "22 rows processed" but simplified version processes 11
**How Found**: Human noticed discrepancy
**Solution**: AI updated README to reflect simplified implementation
**Who Fixed**: AI updated all documentation

---

## What AI Did NOT Do

### 1. Run Commands
AI cannot execute bash commands or SQL queries. Human must:
- Run all scripts
- Check results
- Report back what happened

### 2. See Actual Results
AI cannot see:
- Snowflake web UI
- Actual query results
- Error messages (until human reports them)
- CSV exports

### 3. Make Business Decisions
AI cannot decide:
- What level of documentation is appropriate
- Whether results are accurate
- What to prioritize

### 4. Validate Correctness
AI can generate code that looks right, but cannot verify:
- Amounts are actually correct
- Business logic is preserved
- Performance is acceptable
- Results match expectations

### 5. Catch Its Own Mistakes
AI generated complex procedure with bugs. AI didn't catch:
- Data duplication issue
- Hierarchy processing multiplying amounts
- Only caught when human tested and reported wrong results

---

## Key Insights

### What Worked Well
1. **Rapid iteration**: AI generated code, human tested, AI fixed issues
2. **Documentation**: AI created comprehensive docs quickly
3. **Error diagnosis**: AI could identify issues from error messages
4. **Code generation**: AI wrote 90%+ of the code

### What Didn't Work
1. **Complex logic**: AI's first version had subtle bugs
2. **Validation**: AI couldn't verify results were correct
3. **Over-documentation**: AI generated too many docs
4. **Assumptions**: AI made assumptions that weren't always right

### Lessons Learned
1. **Test everything**: AI-generated code needs thorough testing
2. **Simplify**: Simpler solutions often work better than complex ones
3. **Iterate**: Multiple rounds of feedback improve quality
4. **Human judgment**: Still need human to make final decisions

---

## Conclusion

AI was extremely helpful for this migration, handling the vast majority of code generation and documentation. However, human involvement was critical for:
- Testing and validation
- Catching errors
- Making decisions
- Ensuring quality

The combination of AI speed and human judgment resulted in a successful migration completed in ~6.5 hours instead of an estimated 15 hours without AI.

**Recommendation**: Use AI extensively for migrations, but maintain human oversight for testing, validation, and decision-making.