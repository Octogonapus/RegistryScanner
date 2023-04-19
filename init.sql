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

CREATE TABLE IF NOT EXISTS finding (
    id INT NOT NULL AUTO_INCREMENT,
    `found` DATETIME NOT NULL,
    `category` ENUM('PULL_REQUEST', 'DATABASE_SCAN') NOT NULL,
    `type` ENUM('PREEXISTING_UUID', 'PREEXISTING_NAME', 'PACKAGE_USES_HTTP', 'PACKAGE_NON_UNIQUE_NAME', 'PACKAGE_NON_UNIQUE_UUID', 'SHADOWED_PACKAGE'),
    `level` ENUM('ERROR', 'WARNING') NOT NULL,
    `body` JSON NOT NULL,
    PRIMARY KEY (id)
)

CREATE TABLE IF NOT EXISTS import_error (
    id INT NOT NULL AUTO_INCREMENT,
    `found` DATETIME NOT NULL,
    registry_uuid varchar(36),
    registry_name varchar(255),
    registry_repo varchar(255),
    package_uuid varchar(36),
    package_name varchar(255),
    package_repo varchar(255),
    PRIMARY KEY (id)
)
