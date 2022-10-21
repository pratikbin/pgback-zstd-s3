set -x
docker compose down -v -t0

docker compose up postgres s3 -d
echo "waiting..."
sleep 10
docker compose up postgres-txs
docker compose up pgback-zstd-s3 --build
docker compose up s3-client
docker compose down -v -t0
