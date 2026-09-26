---
name: custom-sql-guidelines
description: Internal organizational guidelines, safety constraints, and formatting rules for writing BigQuery SQL.
metadata:
  version: "1.0"
---

# Skill: Custom SQL Guidelines

This skill defines mandatory internal organizational standards and query safety constraints when interacting with BigQuery.

## 1. Safety and Cost Control Rules

- **Mandatory Row Limits**: Always include a `LIMIT` clause (maximum 1000 rows, e.g., `LIMIT 1000`) for all exploratory and interactive data queries unless explicitly requested by the user.
- **Disallow Unbounded Wildcards**: Avoid `SELECT *` on large production tables. Always specify the exact column names needed.
- **Partition Filtering**: When querying date-partitioned or time-partitioned tables, always include a filter on the partition column (e.g., `DATE(created_at) >= CURRENT_DATE() - 7`) to minimize scanned bytes and control costs.

## 2. Formatting & Standard SQL Conventions

- **Dialect**: Strictly generate Google Standard SQL (avoid legacy SQL syntax).
- **Date/Time Formatting**: Represent dates in ISO format (`YYYY-MM-DD`) and timestamps in UTC.
- **Null Handling**: Use `COALESCE` or `IFNULL` when aggregating fields that may contain null values to ensure deterministic output.
- **Safe Operations**: Prefer `SAFE_CAST` over `CAST` when type-casting columns with potential formatting inconsistencies.
