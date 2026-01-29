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

## Human Supervision

### Decision Making
1. Confirmed assignment requirements
2. Chose to do SQL Server comparison (not just Snowflake)
3. Decided to simplify procedure when complex version had issues
4. Decided to clean up excessive documentation

### Testing & Validation
1. Ran all commands and scripts
2. Reported errors when things didn't work
3. Validated results matched expectations
4. Confirmed amounts were correct

### Error Reporting
1. Reported SQL compilation errors
2. Reported data issues (wrong amounts)
3. Reported missing files/paths
4. Confirmed when fixes worked

### Quality Control
1. Noticed excessive documentation
2. Noticed outdated information in README
4. Asked for cleanup and simplification

---


## Errors Encountered and How They Were Solved

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

## Human Supervision

### 1. Correct BudgetHeaderID
**Situation**: AI used BudgetHeaderID = 1 in examples  
**Human**: "The header should be 7"  
**Impact**: Updated all scripts to use correct ID (7)  
**Why Important**: Wrong ID would cause "budget not found" errors

### 2. SQL Server Setup Required
**Situation**: AI focused only on Snowflake migration  
**Human**: "Should we set up a SqlServer instance first?"  
**Impact**: AI created Docker setup for SQL Server comparison  
**Why Important**: Assignment explicitly requires SQL Server setup for comparison

### 3. Two usp_ProcessBudgetConsolidation.sql Files
**Situation**: Human noticed duplicate filenames  
**Human**: "Why are there two usp_ProcessBudgetConsolidation.sql?"  
**AI Explanation**: One in `src/` (original SQL Server), one in `snowflake-migration/` (converted)  
**Impact**: Clarified repository structure  
**Why Important**: Prevents confusion about which file is which

### 4. Verify Data Completeness
**Situation**: AI didn't verify results in SQL Server matched the ones on Snowflake  
**Human**: "Did you compare this result with the result you calculated? In case the data loaded in snowflake is not complete, so the answer is not correct"  
**Impact**: AI generated scripts to verify amounts matched expected calculations  
**Why Important**: Catches incomplete data loads that would give wrong results

### 5. Clean Up Repository
**Situation**: AI generated many documentation files  
**Human**: "Remove unnecessary files from this directory"  
**Impact**: Deleted 10+ redundant markdown files  
**Why Important**: Clean repo is easier for recruiter to review

### 6. Documentation Accuracy
**Situation**: Documentation had outdated information  
**Human Supervision**: Noticed README still referenced complex procedure details  
**Impact**: AI updated docs to reflect simplified implementation  
**Why Important**: Accurate documentation prevents confusion

---

## Honest Assessment: What AI Cannot Do

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
- Whether to make repo public
- What level of documentation is appropriate
- Whether results are "good enough"
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

## Workflow: What Actually Happened

### Day 1: Initial Setup (2 hours)
1. **Human**: Read assignment, asked AI to help
2. **AI**: Analyzed requirements, created initial plan
3. **AI**: Generated schema conversion
4. **Human**: Created Snowflake account (KBVUCBE-OZB10247)
5. **AI**: Generated SnowSQL setup scripts
6. **Human**: Ran scripts, reported errors
7. **AI**: Fixed errors, regenerated scripts
8. **Human**: Successfully created tables

### Day 2: Procedure Conversion (3 hours)
1. **AI**: Converted stored procedure (complex version with cursors)
2. **Human**: Tried to create procedure, got errors
3. **AI**: Fixed syntax errors
4. **Human**: Created procedure successfully
5. **AI**: Generated test data
6. **Human**: Loaded test data, ran procedure
7. **Human**: Noticed amounts were wrong (6x too high)
8. **AI**: Debugged, found hierarchy processing issue
9. **AI**: Created simplified version
10. **Human**: Tested, confirmed correct results

### Day 3: SQL Server Comparison (2 hours)
1. **Human**: Realized assignment requires SQL Server setup
2. **AI**: Created Docker setup scripts
3. **Human**: Ran Docker, got sqlcmd path error
4. **AI**: Fixed path issues
5. **Human**: Successfully set up SQL Server
6. **AI**: Generated comparison scripts
7. **Human**: Ran comparison, confirmed 100% match

### Day 4: Documentation & Cleanup (1.5 hours)
1. **AI**: Generated extensive documentation
2. **Human**: Noticed too many docs
3. **AI**: Deleted redundant files
4. **Human**: Noticed outdated info in README
5. **AI**: Updated README
6. **Human**: Asked about making repo public
7. **AI**: Advised to keep private, send screenshots
8. **Human**: Ready to submit

---

## Time Breakdown

| Task | AI Time | Human Time | Total |
|------|---------|------------|-------|
| Analysis | 0.1 hr | 0.4 hr | 0.5 hr |
| Schema conversion | 0.2 hr | 0.3 hr | 0.5 hr |
| Procedure conversion | 1.0 hr | 1.0 hr | 2.0 hr |
| Test data | 0.2 hr | 0.3 hr | 0.5 hr |
| SQL Server setup | 0.5 hr | 0.5 hr | 1.0 hr |
| Debugging | 0.5 hr | 0.5 hr | 1.0 hr |
| Documentation | 0.5 hr | 0.2 hr | 0.7 hr |
| Cleanup | 0.2 hr | 0.1 hr | 0.3 hr |
| **Total** | **3.2 hr** | **3.3 hr** | **6.5 hr** |

**Without AI Estimate**: 15 hours (all human work)  
**Productivity Multiplier**: 2.3x

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

AI was extremely valuable for this migration, handling the vast majority of code generation and documentation. However, human involvement was critical for:
- Testing and validation
- Catching errors
- Making decisions
- Ensuring quality

The combination of AI speed and human judgment resulted in a successful migration completed in ~6.5 hours instead of an estimated 15 hours without AI.

**Recommendation**: Use AI extensively for migrations, but maintain human oversight for testing, validation, and decision-making.