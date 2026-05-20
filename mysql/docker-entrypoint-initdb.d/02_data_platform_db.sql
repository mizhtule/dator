CREATE DATABASE IF NOT EXISTS data_platform
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'data_platform'@'%' IDENTIFIED BY 'data_platform';

GRANT ALL PRIVILEGES ON data_platform.* TO 'data_platform'@'%';

FLUSH PRIVILEGES;
