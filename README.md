# RegistryScanner

Scans registries for possible maliscious behavior, security holes, and misconfigurations.

## Usage

1. Modify the `REGISTRIES_TO_SCAN` environment variable in [docker-compose.yml](./docker-compose.yml). Add all the public registries you use, along with any private registries you have.
2. Create secrets where necessary. All public registries can use the same secret; this secret only needs public repository scope. Private registries need private repository scope. RegistryScanner uses GraphQL, so these secrets must be classic GitHub secrets; the new fine-grained secrets do not support GraphQL at this time.
3. Build and deploy:

```sh
docker build RegistryScanner -t registry-scanner:v0.1
docker-compose up -d
```

Then monitor the registry-scanner container logs.
