<div align="center">
  <h1>pgback-zstd-s3</h1>

[![License: Apache-2.0](https://img.shields.io/github/license/pratikbin/pgback-zstd-s3.svg)](https://github.com/pratikbin/pgback-zstd-s3/blob/main/LICENSE)
[![Lines Of Code](https://img.shields.io/tokei/lines/github/pratikbin/pgback-zstd-s3)](https://github.com/pratikbin/pgback-zstd-s3)

</div>

PostgreSQL 16 S3 backup and restore with zstd compression streaming

## Features

* Backup PostgreSQL (pg_dump) to S3 with zstd compression on the fly to avoid disk space and I/O
  * Configurable zstd compression level and compression threads
  * Supports any S3 providers supported by [minio client mc](https://min.io/docs/minio/linux/reference/minio-mc.html) - tested on AWS S3 and MinIO
  * Create one-off backups or scheduled backups
* Keep only the last `X` backups with automatic cleanup
* Restore latest or specific backup
* Retry mechanism for failed backups

## Quick Start

* Refer to `docker-compose.yaml` to run with Docker
* Refer to `k8s-cron.yaml` to run as Kubernetes CronJob
* Refer to `k8s-deployment.yaml` to run as Kubernetes Deployment

## Environment Variables

### Backup Configuration

`SCHEDULE`: [Cron schedule](https://pkg.go.dev/github.com/robfig/cron/v3) for automated backups. Leave empty for one-off backup.

`KEEP_LAST_BACKUPS`: Number of recent backups to retain. Older backups will be automatically deleted. Set to 0 or leave empty to keep all backups.

`BACKUP_ON_START`: Create a backup immediately on container start when using scheduled mode. Set to `true` or `false`.

`BACKUP_PREFIX`: Prefix for backup filenames. Defaults to the database name if not specified.

### PostgreSQL Configuration

`POSTGRES_HOST`: PostgreSQL server hostname (required)

`POSTGRES_PORT`: PostgreSQL server port. Defaults to 5432 if not specified.

`POSTGRES_DATABASE`: Name of the database to backup (required)

`POSTGRES_USER`: PostgreSQL username (required)

`POSTGRES_PASSWORD`: PostgreSQL password (required)

`PGDUMP_EXTRA_OPTS`: Additional flags to pass to pg_dump

### S3 Configuration

`S3_ACCESS_KEY_ID`: S3 access key ID (required)

`S3_SECRET_ACCESS_KEY`: S3 secret access key (required)

`S3_BUCKET`: S3 bucket name (required)

`S3_PREFIX`: S3 object prefix/path (e.g., "production-db", "backups/postgres")

`S3_ENDPOINT`: S3 endpoint URL. Not required for AWS S3, but needed for other S3-compatible services like MinIO.

### Compression Configuration

`ZSTD_COMPRESSION_LEVEL`: Zstd compression level (1-22). Default is 15. Higher values provide better compression but use more CPU.

`ZSTD_COMPRESSION_THREADS`: Number of threads for zstd compression/decompression. Defaults to the number of logical CPU cores.

`ZSTD_EXTRA_OPTS`: Additional zstd options (excluding `-T` and compression level which are handled separately)

### MinIO Client Configuration

`MC_GLOBAL_FLAGS`: Global flags for the minio client used during backup and restore operations

`MC_UPLOAD_FLAGS`: Additional flags for minio client during backup uploads

### Debug and Logging

`DEBUG`: Enable debug mode with verbose output. Set to `true` to enable.

## Restore Mode

To restore a backup, set the mode to restore and configure the restore options:

### Restore Configuration

`MODE`: Set to `RESTORE` or `restore` to run in restore mode instead of backup mode

`RESTORE_VERSION`: Specific backup filename to restore. Leave empty to restore the latest backup.

`RESTORE_PSQL_EXTRA_OPTS`: Additional flags to pass to psql during restore

### Example Restore Command

```bash
docker run --rm \
  -e MODE=RESTORE \
  -e RESTORE_VERSION=mydb_2024_01_15T10_30_00.zstd \
  -e POSTGRES_HOST=localhost \
  -e POSTGRES_DATABASE=mydb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=password \
  -e S3_ACCESS_KEY_ID=your-key \
  -e S3_SECRET_ACCESS_KEY=your-secret \
  -e S3_BUCKET=my-backup-bucket \
  your-image:latest
```

## Backup Object Path

Backup files are stored in S3 with the following path structure:
```
<S3_BUCKET>/<S3_PREFIX>/<BACKUP_PREFIX or POSTGRES_DATABASE>_<TIMESTAMP>.zstd
```

Example: `my-bucket/production-db/myapp_2024_01_15T10_30_00.zstd`

## Development

### Testing

Refer to the `tests` directory for test cases and examples.

<!--

## TODO

- Add CI with triggers on package updates, mc updates etc
- Non-streaming backups

-->

> Inspired by [eeshugerman/postgres-backup-s3](https://github.com/eeshugerman/postgres-backup-s3)
