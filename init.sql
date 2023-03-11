CREATE DATABASE IF NOT EXISTS main;
USE main;

CREATE TABLE IF NOT EXISTS registry (
    registry_uuid varchar(36) UNIQUE PRIMARY KEY,
    registry_name varchar(255),
    registry_repo varchar(255)
);

CREATE TABLE IF NOT EXISTS package (
    package_uuid varchar(36),
    registry_uuid varchar(36),
    package_name varchar(255),
    package_repo varchar(255),
    PRIMARY KEY (package_uuid, registry_uuid),
    FOREIGN KEY (registry_uuid) REFERENCES registry(registry_uuid)
);

CREATE TABLE IF NOT EXISTS registry_scan_monitor (
    started datetime,
    ended datetime,
    successful tinyint,
    stacktrace text
);
CREATE INDEX idx_registry_scan_monitor_ended ON registry_scan_monitor (ended);
