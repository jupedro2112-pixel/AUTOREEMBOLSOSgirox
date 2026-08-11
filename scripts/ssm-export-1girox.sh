#!/bin/bash
# ============================================================================
# ssm-export-1girox.sh — EXPORTA los parámetros de /1girox/prod/ de la cuenta
# VIEJA (Lautarobaezaws2026) a un ssm-export.json descargable.
#
# Reemplaza al ssm-export.json de ~/Documents/amazonviejo/ que Tails borró.
#
# CÓMO SE USA:
#   1. CloudShell de la cuenta VIEJA (Lautarobaezaws2026), región sa-east-1.
#   2. Subir este archivo (Actions → Upload file) y correr:
#        bash ssm-export-1girox.sh
#   3. Descargar el resultado: Actions → Download file → ssm-export.json
#   4. Ese archivo se sube después a la CloudShell de la cuenta NUEVA junto
#      con ssm-put-1girox-prod.sh (ver ese script).
#
# ⚠️ El JSON contiene TODOS los secretos de producción: no dejarlo dando
#    vueltas — usarlo y borrarlo (en CloudShell: rm ssm-export.json).
# ============================================================================
set -euo pipefail

REGION="sa-east-1"
PATH_SSM="/1girox/prod/"
# Guard: este export corre en la cuenta VIEJA (donde vive /1girox/prod).
CUENTA_NUEVA="220282357357"

CUENTA_ACTUAL=$(aws sts get-caller-identity --query Account --output text)
if [ "$CUENTA_ACTUAL" = "$CUENTA_NUEVA" ]; then
  echo "❌ ABORTADO: esta CloudShell es de la cuenta NUEVA ($CUENTA_ACTUAL)."
  echo "   El export se hace en la cuenta VIEJA (Lautarobaezaws2026), que es donde está $PATH_SSM"
  exit 1
fi

aws ssm get-parameters-by-path \
  --path "$PATH_SSM" \
  --region "$REGION" \
  --recursive \
  --with-decryption \
  --output json > ssm-export.json

COUNT=$(grep -c '"Name"' ssm-export.json || true)
echo "✅ Exportados $COUNT parámetros de $PATH_SSM a ssm-export.json"
echo "   Descargalo con: Actions → Download file → ssm-export.json"
