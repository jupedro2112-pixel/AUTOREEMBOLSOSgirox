#!/bin/bash
# ============================================================================
# ssm-put-autoreemb.sh — Sube los 21 parámetros SSM de la página AUTOREEMBOLSOS
# a /autoreemb1girox/prod/ — EN LA CUENTA VIEJA (Lautarobaezaws2026, sa-east-1).
#
# Mismo esquema que la página nardo (/nardo1girox/prod/): path SEPARADO del
# /1girox/prod/ del entorno en producción. El entorno EB de esta app lleva la
# env property SSM_PATH=/autoreemb1girox/prod/ (loadSecrets.js lee de ahí).
#
# ⚠️ NUNCA commitear/pushear este archivo con valores reales: EL REPO ES
#    PÚBLICO. Se edita local, se usa, y listo.
#
# CÓMO SE USA:
#   1. En CloudShell: correr ssm-export-1girox.sh y tener ssm-export.json
#      (los valores compartidos se leen SOLOS de ahí — misma cuenta).
#   2. EDITAR este archivo y completar la sección "COMPLETAR" (los valores
#      propios de esta página). Si esta app es la MISMA que corre en Render,
#      usar los MISMOS valores que están en Render → Environment
#      (MONGODB_URI, JWT_SECRET, ADMIN_*, etc.) para que apunte a la misma
#      base y las sesiones/credenciales coincidan.
#   3. CloudShell de la cuenta VIEJA (sa-east-1) → Actions → Upload file →
#      subir ESTE script Y ssm-export.json (los dos al mismo directorio).
#   4. Subir TODO:            bash ssm-put-autoreemb.sh
#      Subir/corregir UNO(s): bash ssm-put-autoreemb.sh GIROX_API_KEY
#      Ver qué quedó:         bash ssm-put-autoreemb.sh --check
#   5. Al terminar: rm ssm-export.json
#
#   Re-correrlo es SEGURO: usa --overwrite y escribe SOLO bajo
#   /autoreemb1girox/prod/ — jamás toca el /1girox/prod/ vivo (hay un guard
#   que aborta si el prefijo fuera ese). Los parámetros sin completar se
#   SALTEAN con aviso (se puede subir por tandas).
# ============================================================================
set -euo pipefail

REGION="sa-east-1"
PREFIX="/autoreemb1girox/prod/"
EXPORT_FILE="ssm-export.json"
# La cuenta nueva (Maiteabigailsosaaws) NO se usa: si la CloudShell es esa,
# abortamos. La correcta es la VIEJA (Lautarobaezaws2026).
CUENTA_DESCARTADA="220282357357"

# ============================================================================
# COMPLETAR — los 21 valores
# (entre comillas SIMPLES; si un valor tiene comilla simple, avisar y se ajusta)
# ============================================================================

# --- Se COPIAN IGUAL del /1girox/prod/ — se leen SOLOS de ssm-export.json ---
ANTHROPIC_API_KEY='DEL_EXPORT'
FIREBASE_SERVICE_ACCOUNT_JSON_BASE64='DEL_EXPORT'
GIROX_API_URL='https://api-1gx.com/api/v1'
GIROX_NETWIN_SCOPE='casino'
AWS_REGION='sa-east-1'
SMS_MASIVO_PASSWORD='DEL_EXPORT'
# Misma cuenta AWS → las keys de SNS del export sirven tal cual.
AWS_ACCESS_KEY_ID='DEL_EXPORT'
AWS_SECRET_ACCESS_KEY='DEL_EXPORT'

# --- PROPIOS DE ESTA PÁGINA (si ya corre en Render: copiar de Render → Environment) ---
MONGODB_URI='COMPLETAR_misma_uri_que_Render'  # con el nombre de base incluido
# Redis: misma cuenta → se puede reusar el ElastiCache existente con OTRA base
# lógica. Ocupadas: /0 (vipcargas vieja), /1 (NUEVOgirox), /2 (nardo).
# Esta página va con /3. Con DB distinta los Socket.IO adapters no se cruzan.
REDIS_URL='COMPLETAR_rediss://ENDPOINT-EXISTENTE:6379/3'
PUBLIC_BASE_URL='COMPLETAR_https://dominio-de-esta-pagina'
ADMIN_HOST='COMPLETAR_url-del-entorno.sa-east-1.elasticbeanstalk.com'
ALLOWED_ORIGINS='COMPLETAR'  # https://EB-URL,http://EB-URL,https://dominio,https://www.dominio — MINÚSCULAS y con esquema
GIROX_API_KEY='COMPLETAR_o_misma_que_Render_si_aplica'
GIROX_PLAY_URL='COMPLETAR_url_de_juego'
HGCASH_API_TOKEN='COMPLETAR'
HGCASH_WEBHOOK_SECRET='COMPLETAR_del_dashboard_hgcash'
JWT_SECRET='COMPLETAR_mismo_que_Render_o_AUTOGENERAR'
JWT_REFRESH_SECRET='COMPLETAR_mismo_que_Render_o_AUTOGENERAR'
ADMIN_USERNAME='ignite1000'
ADMIN_PASSWORD='COMPLETAR_misma_que_Render'

# (OMITIDOS, igual que en nardo: META_PIXEL_ID, META_CAPI_ACCESS_TOKEN,
#  FBADS_WEBHOOK_TOKEN, FBADS_WEBHOOK_URL)

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

# GUARD 1 — jamás escribir sobre el path del entorno VIVO.
if [ "$PREFIX" = "/1girox/prod/" ]; then
  echo "❌ ABORTADO: el prefijo es /1girox/prod/ (el entorno en PRODUCCIÓN). Esta página va en /autoreemb1girox/prod/."
  exit 1
fi

# GUARD 2 — cuenta: esto va en la cuenta VIEJA (Lautarobaezaws2026).
CUENTA_ACTUAL=$(aws sts get-caller-identity --query Account --output text)
if [ "$CUENTA_ACTUAL" = "$CUENTA_DESCARTADA" ]; then
  echo "❌ ABORTADO: esta CloudShell es de la cuenta NUEVA ($CUENTA_ACTUAL, Maiteabigailsosaaws) — esta página va en el Amazon VIEJO (Lautarobaezaws2026)."
  exit 1
fi
echo "✅ Cuenta $CUENTA_ACTUAL (verificá que sea la VIEJA: Lautarobaezaws2026) — región $REGION — prefijo $PREFIX"

# Lector del export: devuelve el valor del parámetro o vacío si no está.
_from_export() {
  local name="$1"
  [ -f "$EXPORT_FILE" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg n "/1girox/prod/${name}" \
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
      *) echo "❌ '$name' no es uno de los 21 parámetros de esta página."; exit 1 ;;
    esac
  done
else
  SUBIR=("${PARAMS[@]}")
fi

OK=0; SALTEADOS=()
for name in "${SUBIR[@]}"; do
  value="${!name}"

  # DEL_EXPORT: leerlo del ssm-export.json (mismo directorio).
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
echo "Verificar con: bash ssm-put-autoreemb.sh --check"
echo "Al terminar: rm -f $EXPORT_FILE"
