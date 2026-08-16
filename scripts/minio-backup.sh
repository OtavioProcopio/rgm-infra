#!/bin/sh
# Espelha o bucket MinIO de produção para /backups (bind mount no host).
# Sem --remove: arquivos apagados no bucket original NÃO são removidos do
# backup — o objetivo é proteger contra exclusão acidental, não manter um
# espelho idêntico.
set -eu

mc alias set local "http://minio:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

run_backup() {
  echo "[minio-backup] $(date -Iseconds) iniciando mirror de local/${MINIO_BUCKET_NAME} para /backups"
  mc mirror --overwrite "local/${MINIO_BUCKET_NAME}" /backups
  echo "[minio-backup] $(date -Iseconds) concluído"
}

if [ "${1:-}" = "--once" ]; then
  run_backup
  exit 0
fi

while true; do
  run_backup
  sleep "${MINIO_BACKUP_INTERVAL_SECONDS:-86400}"
done
