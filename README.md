# RegistryScanner

Scans registries for possible maliscious behavior, security holes, and misconfigurations.

## Usage

Modify the `REGISTRIES_TO_SCAN` environment variable in [docker-compose.yml](./docker-compose.yml). Add all the public registries you use, along with any private registries you have. Only GitHub registries are supported.

Create secrets where necessary. All public registries can use the same secret; this secret only needs public repository scope. Private registries need private repository scope. RegistryScanner uses GraphQL, so these secrets must be classic GitHub secrets; the new fine-grained secrets do not support GraphQL at this time.

Build and deploy:

```sh
docker build RegistryScanner -t registry-scanner:latest
docker build RegistryScannerUI -t registry-scanner-ui:latest
docker compose up -d
```

The main UI runs on [localhost:4000](http://localhost:4000).

Grafana and Loki are available on [localhost:3000](http://localhost:3000).
View logs via Expore > Loki > `compose_service = scanner`.
