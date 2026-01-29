-- Create database and schema for SQL Server
USE master
GO

-- Create database (drop if exists)
DROP DATABASE IF EXISTS BUDGET_PLANNING
GO

CREATE DATABASE BUDGET_PLANNING
GO

USE BUDGET_PLANNING
GO

-- Create schema
CREATE SCHEMA Planning
GO

PRINT 'Database and schema created successfully'
GO
