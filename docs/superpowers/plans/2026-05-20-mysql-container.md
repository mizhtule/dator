# MySQL Container Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a MySQL 8.0 container accessible on host port 3306, pre-configured for Debezium CDC, with isolated databases for Airflow and the data platform.

**Architecture:** A single `docker-compose.yml` at the repo root defines the `dator-mysql` service. MySQL config is bind-mounted from `mysql/conf.d/` and init SQL scripts from `mysql/docker-entrypoint-initdb.d/` run once on first start to create databases and users. Data is persisted in a named Docker volume.

**Tech Stack:** Docker, Docker Compose, MySQL 8.0

---

## File Map

| File | Status | Responsibility |
|---|---|---|
| `.gitignore` | Create | Ignore `.env` and `.superpowers/` |
| `.env.example` | Create | Committed credential template |
| `.env` | Create | Local dev credentials (gitignored) |
| `mysql/conf.d/debezium.cnf` | Create | MySQL binary log config for Debezium |
| `mysql/docker-entrypoint-initdb.d/01_airflow_db.sql` | Create | Create `airflow` database and user |
| `mysql/docker-entrypoint-initdb.d/02_data_platform_db.sql` | Create | Create `data_platform` database and user |
| `mysql/docker-entrypoint-initdb.d/03_debezium_user.sql` | Create | Create `debezium` replication user |
| `docker-compose.yml` | Create | MySQL service definition |

---

### Task 1: Project scaffolding

**Files:**
- Create: `.gitignore`
- Create: `.env.example`
- Create: `.env`

- [ ] **Step 1: Create `.gitignore`**

```
.env
.superpowers/
```

- [ ] **Step 2: Create `.env.example`**

```
MYSQL_ROOT_PASSWORD=changeme

# Reference only — these passwords are hardcoded in mysql/docker-entrypoint-initdb.d/*.sql
# Update the SQL files directly if you change them.
# MYSQL_AIRFLOW_PASSWORD=airflow
# MYSQL_DATA_PLATFORM_PASSWORD=data_platform
# MYSQL_DEBEZIUM_PASSWORD=debezium
```

- [ ] **Step 3: Create `.env`**

```
MYSQL_ROOT_PASSWORD=rootpassword
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore .env.example
git commit -m "chore: add gitignore and env template"
```

---

### Task 2: Debezium MySQL config

**Files:**
- Create: `mysql/conf.d/debezium.cnf`

- [ ] **Step 1: Create directory and config file**

```bash
mkdir -p mysql/conf.d
```

`mysql/conf.d/debezium.cnf`:

```ini
[mysqld]
server-id         = 1
log_bin           = mysql-bin
binlog_format     = ROW
binlog_row_image  = FULL
expire_logs_days  = 7
```

- [ ] **Step 2: Commit**

```bash
git add mysql/conf.d/debezium.cnf
git commit -m "feat: add Debezium-ready MySQL config"
```

---

### Task 3: Init SQL scripts

**Files:**
- Create: `mysql/docker-entrypoint-initdb.d/01_airflow_db.sql`
- Create: `mysql/docker-entrypoint-initdb.d/02_data_platform_db.sql`
- Create: `mysql/docker-entrypoint-initdb.d/03_debezium_user.sql`

- [ ] **Step 1: Create directory**

```bash
mkdir -p mysql/docker-entrypoint-initdb.d
```

- [ ] **Step 2: Create `01_airflow_db.sql`**

```sql
CREATE DATABASE IF NOT EXISTS airflow
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'airflow'@'%' IDENTIFIED BY 'airflow';

GRANT ALL PRIVILEGES ON airflow.* TO 'airflow'@'%';

FLUSH PRIVILEGES;
```

- [ ] **Step 3: Create `02_data_platform_db.sql`**

```sql
CREATE DATABASE IF NOT EXISTS data_platform
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'data_platform'@'%' IDENTIFIED BY 'data_platform';

GRANT ALL PRIVILEGES ON data_platform.* TO 'data_platform'@'%';

FLUSH PRIVILEGES;
```

- [ ] **Step 4: Create `03_debezium_user.sql`**

```sql
CREATE USER IF NOT EXISTS 'debezium'@'%' IDENTIFIED BY 'debezium';

GRANT REPLICATION SLAVE, REPLICATION CLIENT, SELECT ON *.* TO 'debezium'@'%';

FLUSH PRIVILEGES;
```

- [ ] **Step 5: Commit**

```bash
git add mysql/docker-entrypoint-initdb.d/
git commit -m "feat: add MySQL init scripts for airflow, data_platform, and debezium users"
```

---

### Task 4: docker-compose.yml

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Create `docker-compose.yml`**

```yaml
services:
  mysql:
    image: mysql:8.0
    container_name: dator-mysql
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./mysql/conf.d:/etc/mysql/conf.d
      - ./mysql/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d
    restart: unless-stopped

volumes:
  mysql_data:
```

- [ ] **Step 2: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add docker-compose with MySQL service"
```

---

### Task 5: Smoke test

Verify the container starts, all databases and users exist, and binary logging is configured correctly.

- [ ] **Step 1: Start the container**

```bash
docker compose up -d
```

Expected: `Container dator-mysql  Started`

- [ ] **Step 2: Wait for MySQL to be ready**

```bash
docker exec dator-mysql mysqladmin --user=root --password=rootpassword ping --wait --connect-timeout=30
```

Expected: `mysqld is alive`

- [ ] **Step 3: Verify databases**

```bash
docker exec dator-mysql mysql -u root -prootpassword -e "SHOW DATABASES;"
```

Expected output includes:
```
airflow
data_platform
```

- [ ] **Step 4: Verify users**

```bash
docker exec dator-mysql mysql -u root -prootpassword \
  -e "SELECT User, Host FROM mysql.user WHERE User IN ('airflow', 'data_platform', 'debezium');"
```

Expected:
```
+---------------+------+
| User          | Host |
+---------------+------+
| airflow       | %    |
| data_platform | %    |
| debezium      | %    |
+---------------+------+
```

- [ ] **Step 5: Verify binary log config**

```bash
docker exec dator-mysql mysql -u root -prootpassword \
  -e "SHOW VARIABLES WHERE Variable_name IN ('log_bin','binlog_format','binlog_row_image','server_id');"
```

Expected:
```
+------------------+----------+
| Variable_name    | Value    |
+------------------+----------+
| binlog_format    | ROW      |
| binlog_row_image | FULL     |
| log_bin          | ON       |
| server_id        | 1        |
+------------------+----------+
```

- [ ] **Step 6: Verify host connectivity on port 3306**

Use a temporary container to connect through the host-mapped port (tests the actual port binding, not internal networking):

```bash
docker run --rm --network host mysql:8.0 \
  mysql -h 127.0.0.1 -P 3306 -u airflow -pairflow -e "SELECT 'ok' AS status;"
```

Expected:
```
+--------+
| status |
+--------+
| ok     |
+--------+
```

- [ ] **Step 7: Stop the container**

```bash
docker compose down
```

- [ ] **Step 8: Verify data volume persists after restart**

```bash
docker compose up -d
docker exec dator-mysql mysqladmin --user=root --password=rootpassword ping --wait --connect-timeout=30
docker exec dator-mysql mysql -u root -prootpassword -e "SHOW DATABASES;"
docker compose down
```

Expected: `airflow` and `data_platform` still present after restart — confirms named volume is working.
