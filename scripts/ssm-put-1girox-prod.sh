#!/bin/bash
# ============================================================================
# ssm-put-1girox-prod.sh — Sube los 21 parámetros SSM del clon a /1girox/prod/
# EN LA CUENTA NUEVA (Maiteabigailsosaaws, 220282357357, sa-east-1).
#
# Plan original del runbook docs/MIGRACION-AWS.md (paso 5), retomado ahora que
# Amazon verificó la cuenta nueva. GUARD: este script ABORTA si la CloudShell
# no es la de la cuenta nueva — así jamás pisa el /1girox/prod/ VIVO de la
# cuenta vieja.
#
# ⚠️ ARCHIVO TEMPORAL del runbook. Borrar del repo al terminar la clonación.
# ⚠️ NUNCA commitear/pushear este archivo con valores reales: EL REPO ES
#    PÚBLICO. Se edita local / en CloudShell, se usa, y se borra.
#
# CÓMO SE USA:
#   1. En la cuenta VIEJA: correr ssm-export-1girox.sh y descargar
#      ssm-export.json (tiene los valores que se COPIAN IGUAL).
#   2. EDITAR este archivo y completar la sección "COMPLETAR" (los valores
#      propios del clon: Mongo nuevo, girox nuevo, hgcash nuevo, etc.).
#   3. CloudShell de la cuenta NUEVA (región sa-east-1) → Actions → Upload
#      file → subir ESTE script Y ssm-export.json (los dos al mismo dir).
#   4. Subir TODO:            bash ssm-put-1girox-prod.sh
#      Subir/corregir UNO(s): bash ssm-put-1girox-prod.sh GIROX_API_KEY
#      Ver qué quedó:         bash ssm-put-1girox-prod.sh --check
#   5. Al terminar: rm ssm-export.json
#
#   Re-correrlo es SEGURO (usa --overwrite). Los parámetros sin completar se
#   SALTEAN con aviso, así se puede subir por tandas (ej. HGCASH_WEBHOOK_SECRET
#   recién cuando el dashboard de hgcash lo genere).
#
#   Los marcados DEL_EXPORT se leen SOLOS de ssm-export.json si está presente
#   (para no copiar a mano valores gigantes como el JSON de Firebase). Si se
#   quiere pisar alguno, escribir el valor acá y ese gana sobre el export.
# ============================================================================
set -euo pipefail

REGION="sa-east-1"
PREFIX="/1girox/prod/"
CUENTA_ESPERADA="220282357357"   # Maiteabigailsosaaws — la ÚNICA permitida
EXPORT_FILE="ssm-export.json"

# ============================================================================
# COMPLETAR — valores propios del clon
# (entre comillas SIMPLES; si un valor tiene comilla simple, avisar y se ajusta)
# ============================================================================

# --- Se COPIAN IGUAL — se leen solos de ssm-export.json (dejar DEL_EXPORT) ---
ANTHROPIC_API_KEY='DEL_EXPORT'
FIREBASE_SERVICE_ACCOUNT_JSON_BASE64='DEL_EXPORT'
GIROX_API_URL='https://api-1gx.com/api/v1'
GIROX_NETWIN_SCOPE='casino'
AWS_REGION='sa-east-1'
SMS_MASIVO_PASSWORD='DEL_EXPORT'

# --- NUEVOS / PROPIOS DEL CLON ---
# ⚠️ Las keys AWS del export NO sirven acá: son de un usuario IAM de la cuenta
# VIEJA. Crear usuario IAM en la cuenta NUEVA con permiso SNS → Access Key.
AWS_ACCESS_KEY_ID='COMPLETAR_usuario_IAM_de_la_cuenta_NUEVA'
AWS_SECRET_ACCESS_KEY='COMPLETAR_usuario_IAM_de_la_cuenta_NUEVA'
MONGODB_URI='COMPLETAR_uri_atlas_nueva_CON_nombre_de_base'  # ej: ...mongodb.net/NOMBREBASE?appName=...
REDIS_URL='COMPLETAR_rediss://ENDPOINT-NUEVO:6379/0'  # ElastiCache de la cuenta nueva (TLS)
PUBLIC_BASE_URL='COMPLETAR_https://dominio-nuevo'
ADMIN_HOST='COMPLETAR_url-del-entorno.sa-east-1.elasticbeanstalk.com'
ALLOWED_ORIGINS='COMPLETAR'  # https://EB-URL,http://EB-URL,https://dominio,https://www.dominio — MINÚSCULAS y con esquema
GIROX_API_KEY='COMPLETAR_key_1girox_nueva'
GIROX_PLAY_URL='COMPLETAR_url_de_juego_marca_nueva'
HGCASH_API_TOKEN='COMPLETAR_token_hgcash_nuevo'
HGCASH_WEBHOOK_SECRET='COMPLETAR_del_dashboard_hgcash'
JWT_SECRET='AUTOGENERAR'          # dejar AUTOGENERAR = el script crea uno random
JWT_REFRESH_SECRET='AUTOGENERAR'  # ídem
ADMIN_USERNAME='ignite1000'
ADMIN_PASSWORD='COMPLETAR_password_admin_inicial'

# (OMITIDOS a propósito, decisión owner 2026-08-06: META_PIXEL_ID,
#  META_CAPI_ACCESS_TOKEN, FBADS_WEBHOOK_TOKEN, FBADS_WEBHOOK_URL)

# ============================================================================
# De acá para abajo NO hay que tocar nada
# ============================================================================

PARAMS=(
  ANTHROPIC_API_KEY FIREBASE_SERVICE_ACCOUNT_JSON_BASE64 GIROX_API_URL
  GIROX_NETWIN_SCOPE AWS_REGION SMS_MASIVO_PASSWORD
  AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  MONGODB_URI REDIS_URL PUBLIC_BASE_URL ADMIN_HOST ALLOWED_ORIGINS
  GIROX_API_KEY GIROX_PLAY_URL HGCASH_API_TOKEN HGCASH_WEBHOOK_SECRET
  JWT_SECRET JWT_REFRESH_SECRET ADMIN_USERNAME ADMIN_PASSWORD
)

# GUARD — SOLO la cuenta nueva. En cualquier otra (p. ej. la vieja, donde
# /1girox/prod/ está EN PRODUCCIÓN) se aborta sin tocar nada.
CUENTA_ACTUAL=$(aws sts get-caller-identity --query Account --output text)
if [ "$CUENTA_ACTUAL" != "$CUENTA_ESPERADA" ]; then
  echo "❌ ABORTADO: esta CloudShell es de la cuenta $CUENTA_ACTUAL."
  echo "   Este script SOLO corre en la cuenta NUEVA ($CUENTA_ESPERADA, Maiteabigailsosaaws)."
  echo "   En la cuenta VIEJA, /1girox/prod/ es el entorno VIVO — no se toca."
  exit 1
fi
echo "✅ Cuenta $CUENTA_ACTUAL (Maiteabigailsosaaws) — región $REGION — prefijo $PREFIX"

# Lector del export: devuelve el valor del parámetro o vacío si no está.
_from_export() {
  local name="$1"
  [ -f "$EXPORT_FILE" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg n "${PREFIX}${name}" \
      '.Parameters[] | select(.Name==$n) | .Value' "$EXPORT_FILE" 2>/dev/null || true
  else
    python3 - "$name" <<'PYEOF'
import json, sys
name = sys.argv[1]
try:
    data = json.load(open("ssm-export.json"))
except Exception:
    sys.exit(0)
for p in data.get("Parameters", []):
    if p.get("Name") == "/1girox/prod/" + name:
        sys.stdout.write(p.get("Value", ""))
        break
PYEOF
  fi
}

# Modo --check: listar lo que YA está subido y qué falta, sin tocar nada.
if [ "${1:-}" = "--check" ]; then
  echo "— Parámetros presentes en $PREFIX:"
  EXISTENTES=$(aws ssm get-parameters-by-path --path "$PREFIX" --region "$REGION" \
    --query 'Parameters[].Name' --output text | tr '\t' '\n' | sed "s|$PREFIX||" | sort)
  echo "$EXISTENTES" | sed 's/^/   ✔ /'
  echo "— Faltantes (de los 21 esperados):"
  FALTAN=0
  for name in "${PARAMS[@]}"; do
    if ! echo "$EXISTENTES" | grep -qx "$name"; then echo "   ✘ $name"; FALTAN=1; fi
  done
  [ "$FALTAN" = "0" ] && echo "   (ninguno — están los 21) ✅"
  exit 0
fi

# Si se pasaron nombres por argumento, subir SOLO esos.
if [ "$#" -gt 0 ]; then
  SUBIR=("$@")
  for name in "${SUBIR[@]}"; do
    case " ${PARAMS[*]} " in
      *" $name "*) ;;
      *) echo "❌ '$name' no es uno de los 21 parámetros del clon."; exit 1 ;;
    esac
  done
else
  SUBIR=("${PARAMS[@]}")
fi

OK=0; SALTEADOS=()
for name in "${SUBIR[@]}"; do
  value="${!name}"

  # DEL_EXPORT: leerlo de ssm-export.json.
  if [ "$value" = "DEL_EXPORT" ]; then
    value="$(_from_export "$name")"
    if [ -z "$value" ]; then
      echo "⚠️ $name: no está en $EXPORT_FILE (¿lo subiste al mismo directorio?)"
      SALTEADOS+=("$name")
      continue
    fi
    echo "📥 $name: leído del export"
  fi

  # JWT: autogenerar si quedó el placeholder.
  if [ "$value" = "AUTOGENERAR" ]; then
    value=$(openssl rand -hex 64)
    echo "🎲 $name: generado random (128 hex)"
  fi

  # Sin completar o vacío → saltear con aviso.
  if [ -z "$value" ] || [[ "$value" == COMPLETAR* ]]; then
    SALTEADOS+=("$name")
    continue
  fi

  aws ssm put-parameter \
    --region "$REGION" \
    --name "${PREFIX}${name}" \
    --type SecureString \
    --value "$value" \
    --overwrite >/dev/null
  echo "✅ ${PREFIX}${name}"
  OK=$((OK+1))
done

echo ""
echo "Subidos/actualizados: $OK"
if [ "${#SALTEADOS[@]}" -gt 0 ]; then
  echo "⚠️ SALTEADOS (sin valor todavía — completar y re-correr con esos nombres):"
  printf '   - %s\n' "${SALTEADOS[@]}"
fi
echo ""
echo "Verificar con: bash ssm-put-1girox-prod.sh --check"
echo "Al terminar: rm -f $EXPORT_FILE"
