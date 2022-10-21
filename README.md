<div align="center">
  <h1>pgback-zstd-s3</h1>

[![License: Apache-2.0](https://img.shields.io/github/license/pratikbin/pgback-zstd-s3.svg)](https://github.com/pratikbin/pgback-zstd-s3/blob/main/LICENSE)
[![Lines Of Code](https://img.shields.io/tokei/lines/github/pratikbin/pgback-zstd-s3)](https://github.com/pratikbin/pgback-zstd-s3)

</div>

Postgres (14) s3 zstd streaming backup and restore

## Features

* Backup postgres(pgdump) to s3 with zstd compression on the fly to avoid disk space and IO
  * Can override zstd compression level and compression threads
  * Supports any s3 providers supported by [minio client mc](https://min.io/docs/minio/linux/reference/minio-mc.html), Tested on AWS s3 and minio
  * Create one off backups
* Keep only `X` backup
* Restore latest or particular backup

* Refer `docker-compose.yaml` to run in docker
* Refer `k8s-cron.yaml` to run as kubernets cron
* Refer `k8s-deployment.yaml` to run as kubernets deployment

## Usage

`SCHEDULE`: [cron schdeule](https://pkg.go.dev/github.com/robfig/cron/v3), empty will run oneoff backup

`KEEP_LAST_BACKUPS`: keep specified no of last backups, required

`DEBUG`: enable debug mode, `true` or `false`

`BACKUP_ON_START`: Create backup on start, `true` or `false`

`BACKUP_PREFIX`: backup name prefix, empty will take dbname as prefix

`PGDUMP_EXTRA_OPTS`: pgdump extra flags

`S3_ENDPOINT`: S3 endpoint, for AWS s3 not needed, required

`ZSTD_EXTRA_OPTS`: zstd backup extra args **except -T(n) and -(compression ratio)**

`ZSTD_COMPRESSION_LEVEL`: zstd compression level, default 15

`ZSTD_COMPRESSION_THREADS`: zstd compression and decompression threads, default to no of logical cores

`MC_GLOBAL_FLAGS`: minio client global flags used while bakup and restore

`MC_UPLOAD_FLAGS`: minio client backup flags

`S3_ACCESS_KEY_ID`: S3 key id, required

`S3_SECRET_ACCESS_KEY`: S3 Secret ke, required

`S3_BUCKET`: S3 bucket name, required

`S3_PREFIX`: S3 bucket path e.g. production-db, required

`POSTGRES_HOST`: Postgres host, required

`POSTGRES_DATABASE`: Postgres DB name, required

`POSTGRES_USER`: Postgres user, required

`POSTGRES_PASSWORD`: Postgres password, required

> Backup object path will be something like
> <S3_BUCKET>/<S3_PREFIX>/<BACKUP_PREFIX else POSTGRES_DATABASE>_<TIMESTEMP>

## Restore

Default mode is backup

`MODE`: specify `RESTORE` or `restore` for run it on restore mode, default backup mode

`RESTORE_PSQL_EXTRA_OPTS`: Restore backup psql extra flags, default emtpy

`RESTORE_VERSION`: specific restore version, empty will take latest backup, required in restore mode,

* Set `MODE` env as `RESTORE` / `restore` and run

## Development

### Testing

refer `tests` directory

<!--

## TODO

- Add CI with triggers on package update, mc update etc
- Non streaming backups

-->

> Inspired from [eeshugerman/postgres-backup-s3](https://github.com/eeshugerman/postgres-backup-s3)
