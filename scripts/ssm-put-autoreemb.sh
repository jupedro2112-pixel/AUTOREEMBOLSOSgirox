#!/bin/bash
# Sube los SSM de esta página a /autoreemb1girox/prod/ (cuenta Lautarobaezaws2026).
#
#   1. Editá SOLO la sección "EDITAR ACÁ" (valores entre comillas simples).
#      - COMPLETAR_...  → poné el valor real (si corre en Render, copiá de Render → Environment)
#      - DEL_EXPORT     → NO tocar: se lee solo de ssm-export.json
#      - AUTOGENERAR    → NO tocar: se genera random solo
#   2. CloudShell (sa-east-1) → Upload: este script + ssm-export.json
#      (el export sale de: bash ssm-export-1girox.sh)
#   3. bash ssm-put-autoreemb.sh
#
# Lo que quede sin completar se saltea con aviso (re-corré cuando lo tengas).
# ⚠️ NUNCA subir este archivo con valores reales al repo (es público).
set -uo pipefail
REGION="sa-east-1"
PREFIX="/autoreemb1girox/prod/"

# ============================ EDITAR ACÁ ============================

MONGODB_URI='COMPLETAR_misma_uri_que_Render'
REDIS_URL='COMPLETAR_rediss://ENDPOINT-EXISTENTE:6379/3'
PUBLIC_BASE_URL='COMPLETAR_https://dominio-de-esta-pagina'
ADMIN_HOST='COMPLETAR_url-del-entorno.sa-east-1.elasticbeanstalk.com'
ALLOWED_ORIGINS='COMPLETAR_https://EB-URL,https://dominio,https://www.dominio'
GIROX_API_KEY='COMPLETAR'
GIROX_PLAY_URL='COMPLETAR_url_de_juego'
HGCASH_API_TOKEN='COMPLETAR'
HGCASH_WEBHOOK_SECRET='COMPLETAR_del_dashboard_hgcash'
JWT_SECRET='COMPLETAR_mismo_que_Render'
JWT_REFRESH_SECRET='COMPLETAR_mismo_que_Render'
ADMIN_USERNAME='ignite1000'
ADMIN_PASSWORD='COMPLETAR_misma_que_Render'

# Estos se completan SOLOS desde ssm-export.json — no tocar:
ANTHROPIC_API_KEY='DEL_EXPORT'
FIREBASE_SERVICE_ACCOUNT_JSON_BASE64='DEL_EXPORT'
SMS_MASIVO_PASSWORD='DEL_EXPORT'
AWS_ACCESS_KEY_ID='DEL_EXPORT'
AWS_SECRET_ACCESS_KEY='DEL_EXPORT'

# Fijos — no tocar:
GIROX_API_URL='https://api-1gx.com/api/v1'
GIROX_NETWIN_SCOPE='casino'
AWS_REGION='sa-east-1'

# ====================================================================

PARAMS=(
  MONGODB_URI REDIS_URL PUBLIC_BASE_URL ADMIN_HOST ALLOWED_ORIGINS
  GIROX_API_KEY GIROX_PLAY_URL HGCASH_API_TOKEN HGCASH_WEBHOOK_SECRET
  JWT_SECRET JWT_REFRESH_SECRET ADMIN_USERNAME ADMIN_PASSWORD
  ANTHROPIC_API_KEY FIREBASE_SERVICE_ACCOUNT_JSON_BASE64 SMS_MASIVO_PASSWORD
  AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  GIROX_API_URL GIROX_NETWIN_SCOPE AWS_REGION
)

# Guard: solo la cuenta vieja (Lautarobaezaws2026), nunca la nueva.
if [ "$(aws sts get-caller-identity --query Account --output text)" = "220282357357" ]; then
  echo "❌ ABORTADO: esta es la cuenta NUEVA. Usá la CloudShell de Lautarobaezaws2026."
  exit 1
fi

OK=0; SALTEADOS=()
for name in "${PARAMS[@]}"; do
  value="${!name}"

  if [ "$value" = "DEL_EXPORT" ]; then
    value=$(jq -r --arg n "/1girox/prod/${name}" \
      '.Parameters[] | select(.Name==$n) | .Value' ssm-export.json 2>/dev/null || true)
  fi
  if [ "$value" = "AUTOGENERAR" ]; then
    value=$(openssl rand -hex 64)
  fi
  if [ -z "$value" ] || [[ "$value" == COMPLETAR* ]]; then
    SALTEADOS+=("$name"); continue
  fi

  aws ssm put-parameter --region "$REGION" --name "${PREFIX}${name}" \
    --type SecureString --value "$value" --overwrite >/dev/null \
    && { echo "✅ ${PREFIX}${name}"; OK=$((OK+1)); } \
    || echo "❌ ERROR subiendo $name"
done

echo ""
echo "Subidos: $OK de ${#PARAMS[@]}"
if [ "${#SALTEADOS[@]}" -gt 0 ]; then
  echo "⚠️ Salteados (completar y volver a correr):"
  printf '   - %s\n' "${SALTEADOS[@]}"
fi
