# MySQL Container Design

**Date:** 2026-05-20
**Status:** Approved

## Overview

A MySQL 8.0 container serving three purposes:
- Metadata store for Apache Airflow
- Storage for data platform pipeline configuration and logs (`data_platform` database)
- CDC source for Debezium (future)

The container is accessible from the host on port 3306 and is configured for Debezium readiness from day one.

## File Structure

```
dator/
├── docker-compose.yml
├── .env                              # credentials (gitignored)
├── .env.example                      # committed template
└── mysql/
    ├── conf.d/
    │   └── debezium.cnf
    └── docker-entrypoint-initdb.d/
        ├── 01_airflow_db.sql
        ├── 02_data_platform_db.sql
        └── 03_debezium_user.sql
```

## Service Configuration

**Image:** `mysql:8.0`
**Container name:** `dator-mysql`
**Port:** `3306:3306` (host → container)
**Restart policy:** `unless-stopped`

**Volumes:**

| Host path | Container path | Purpose |
|---|---|---|
| `mysql_data` (named volume) | `/var/lib/mysql` | Data persistence |
| `./mysql/conf.d` | `/etc/mysql/conf.d` | Debezium config |
| `./mysql/docker-entrypoint-initdb.d` | `/docker-entrypoint-initdb.d` | Init scripts |

Credentials come from `.env` via environment variables. `.env.example` is committed with placeholder values.

## Debezium Configuration (`mysql/conf.d/debezium.cnf`)

```ini
[mysqld]
server-id         = 1
log_bin           = mysql-bin
binlog_format     = ROW
binlog_row_image  = FULL
expire_logs_days  = 7
```

`server-id` must be unique across all MySQL instances in a replication topology. `binlog_format=ROW` and `binlog_row_image=FULL` are required by Debezium to capture full row-level change events.

## Init Scripts

Scripts in `/docker-entrypoint-initdb.d` are executed in alphabetical order on first container start (when the data volume is empty).

| File | Purpose |
|---|---|
| `01_airflow_db.sql` | Creates the `airflow` database and `airflow` user with full grants on it |
| `02_data_platform_db.sql` | Creates the `data_platform` database and `data_platform` user with full grants on it |
| `03_debezium_user.sql` | Creates the `debezium` user with `REPLICATION SLAVE`, `REPLICATION CLIENT`, `SELECT ON *.*` |

The `debezium` user's grants are the minimum required for Debezium to read the binary log and snapshot table data.

## Credentials (.env)

| Variable | Description |
|---|---|
| `MYSQL_ROOT_PASSWORD` | Root password |
| `MYSQL_AIRFLOW_PASSWORD` | Password for `airflow` user |
| `MYSQL_DATA_PLATFORM_PASSWORD` | Password for `data_platform` user |
| `MYSQL_DEBEZIUM_PASSWORD` | Password for `debezium` user |

## Decisions

| Decision | Choice | Reason |
|---|---|---|
| MySQL version | 8.0 | Broader Debezium connector compatibility over 8.4 |
| Host port | 3306 (standard) | Local dev convenience; no local MySQL conflict expected |
| One init file per database | Yes | Single responsibility per file; easier to add databases later |
| Named volume for data | Yes | Avoids permission issues on macOS/Linux; survives `docker compose down` without `--volumes` |
