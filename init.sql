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

CREATE TABLE IF NOT EXISTS packages_time_series (
    collected datetime,
    npackages int
);
CREATE INDEX idx_packages_time_series_collected ON packages_time_series (collected);
CREATE EVENT record_npackages ON SCHEDULE EVERY 1 DAY DO
    INSERT INTO packages_time_series (collected, npackages)
    VALUES ((SELECT CURRENT_TIMESTAMP), (SELECT COUNT(package_uuid) FROM package));
