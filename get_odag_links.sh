#!/bin/bash
set -euo pipefail

################################
# DEFAULT VALUES (can be overridden by args)
################################
CONTEXT="dante"
STREAM="dante"
APP_NAME="selector odag"

#CONFIG VALUES
DATA_DIR="files"
CFG_DIR=".config"
TMP_DIR="tmp"


################################
# PARSE COMMAND-LINE ARGUMENTS
################################
while [ $# -gt 0 ]; do
  case "$1" in
    --context) CONTEXT="$2"; shift 2 ;;
    --stream) STREAM="$2"; shift 2 ;;
    --app-name) APP_NAME="$2"; shift 2 ;;
    --template-file) ODAG_TEMPLATE_FILE="$2"; shift 2 ;;
    --debug) DEBUG=true; shift 1 ;;
    --help)
      echo "Uso: $0 [options]"
      echo
      echo "Opções:"
      echo "  --context <name> # Nome dado ao contexto configurado de origem"
      echo "  --stream <name>  # ID do fluxo de origem"
      echo "  --app-name <app_name> # Nome do arquivo de seleção"
      echo "  --debug"
      echo "  --inloco # Não exporta, ja supõe os arquivos qvf exportados"
      echo "  --help"
      exit 0
      ;;
    *)
      echo "Opção desconhecida: $1"
      exit 1
      ;;
  esac
done

################################
# HELPER FUNCTIONS
################################
log() {
  echo "[INFO] $1"
}

debug() {
  if [ "$DEBUG" = true ]; then
    echo "[DEBUG] $1"
  fi
}

error_exit() {
  echo "[ERROR] $1" >&2
  exit 1
}

check_dep() {
  command -v "$1" >/dev/null 2>&1 || error_exit "Comando '$1' não encontrado."
}

################################
# CHECK DEPENDENCIES
################################
for dep in qlik jq; do
  check_dep "$dep"
done

################################
# MAIN PROCESS
################################
rm -rf $TMP_DIR/odags_ids.txt
qlik context use $CONTEXT

echo "Pegando os ids dos botões odags"
APP_ID=$(qlik app ls --quiet --name "$APP_NAME")
list="$(mktemp)"
# ODAG_BUTTON_ID=$(qlik app object ls --app "$APP_ID" | grep "odagapplink" | awk '{print $1}') > "$list"
qlik app object ls --app "$APP_ID" | grep "odagapplink" | awk '{print $1}' > "$list"
cat "$list" > $TMP_DIR/odag_buttons_id.txt

while IFS= read -r id; do
  qlik app object properties "$id" --app "$APP_ID" | jq -r '.qMetaDef.odagLinkRef' >> $TMP_DIR/ids.txt
done < "$list"

# ODAG_ID=$(qlik app object properties "$ODAG_BUTTON_ID" --app "$APP_ID" | jq '.qMetaDef.odagLinkRef')

echo "Completed"
