#!/bin/bash
set -euo pipefail

################################
# DEFAULT VALUES (can be overridden by args)
################################
SRC_CONTEXT="dante"
DST_CONTEXT="prod"
SELECTION_NAME="selector odag"
TEMPLATE_NAME="template"
LINK_NAME="Hello World"
SHEET_TITLE="My new sheet (1)"
BUTTON_QID="qpHx"
ODAG_TEMPLATE_FILE="odag_create_template.json"
DEBUG=false

################################
# PARSE COMMAND-LINE ARGUMENTS
################################
while [ $# -gt 0 ]; do
  case "$1" in
    --src-context) SRC_CONTEXT="$2"; shift 2 ;;
    --dst-context) DST_CONTEXT="$2"; shift 2 ;;
    --selection-name) SELECTION_NAME="$2"; shift 2 ;;
    --template-name) TEMPLATE_NAME="$2"; shift 2 ;;
    --link-name) LINK_NAME="$2"; shift 2 ;;
    --sheet-title) SHEET_TITLE="$2"; shift 2 ;;
    --button-id) BUTTON_QID="$2"; shift 2 ;; --template-file) ODAG_TEMPLATE_FILE="$2"; shift 2 ;;
    --debug) DEBUG=true; shift 1 ;;
    --help)
      echo "Uso: $0 [options]"
      echo
      echo "Opções:"
      echo "  --src-context <name>"
      echo "  --dst-context <name>"
      echo "  --selection-name <app_name>"
      echo "  --template-name <app_name>"
      echo "  --link-name <string>"
      echo "  --sheet-title <title>"
      echo "  --button-id <qid>"
      echo "  --template-file <file>"
      echo "  --debug"
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
log "Mudando o contexto para fonte: $SRC_CONTEXT"
qlik context use "$SRC_CONTEXT"

log "Exportando ODAG selection app: $SELECTION_NAME"
SEL_APP_ID=$(qlik app ls --quiet --name "$SELECTION_NAME" | awk '{print $1}')
[ -z "$SEL_APP_ID" ] && error_exit "Nenhum aplicativo encontrado com nome: '$SELECTION_NAME'"
debug "Seleção encontrada app ID: $SEL_APP_ID"
qlik app export "$SEL_APP_ID" --output-file ./files/selection.qvf

log "Exportando ODAG template app: $TEMPLATE_NAME"
TMP_APP_ID=$(qlik app ls --quiet --name "$TEMPLATE_NAME" | awk '{print $1}')
[ -z "$TMP_APP_ID" ] && error_exit "Nenhum aplicativo encontrado com nome: '$TEMPLATE_NAME'"
debug "Template encontrado app ID: $TMP_APP_ID"
qlik app export "$TMP_APP_ID" --output-file ./files/template.qvf

log "Mudando o contexto para destino: $DST_CONTEXT"
qlik context use "$DST_CONTEXT"

log "Importando selection.qvf"
APP=$(qlik app import --file files/selection.qvf --quiet)
[ -z "$APP" ] && error_exit "Falha na importação de selection.qvf"
debug "App de seleção importado como ID: $APP"

log "Importando template.qvf"
TEMPLATE=$(qlik app import --file files/template.qvf --quiet)
[ -z "$TEMPLATE" ] && error_exit "Failed to import template.qvf"
debug "Template importado como ID: $TEMPLATE"

log "Procurando pasta com o nome: $SHEET_TITLE"
SHEET=$(qlik app object ls --app "$APP" --verbose --json |
  jq -r --arg title "$SHEET_TITLE" '.[] | select(.qType=="sheet" and .title==$title) | .qId')

[ -z "$SHEET" ] && error_exit "Nenhuma pasta encontrada com '$SHEET_TITLE'"
debug "Pasta encontrada com ID: $SHEET"

log "Despublicando a pasta de ID $SHEET"
qlik app object unpublish "$SHEET" --app "$APP"

log "Modificando o arquivo de template ODAG: $ODAG_TEMPLATE_FILE"
[ ! -f "$ODAG_TEMPLATE_FILE" ] && error_exit "Arquivo '$ODAG_TEMPLATE_FILE' não encontrado."

TMPFILE=$(mktemp)
jq --arg sApp "$APP" \
   --arg tApp "$TEMPLATE" \
   --arg lName "$LINK_NAME" \
   '.name=$lName | .selectionApp=$sApp | .templateApp=$tApp' \
   "$ODAG_TEMPLATE_FILE" > "$TMPFILE"
mv "$TMPFILE" "$ODAG_TEMPLATE_FILE"

log "Criando o link ODAG..."
ODAGLINKREF=$(qlik raw post /v1/odaglinks --body-file "$ODAG_TEMPLATE_FILE" -q)
[ -z "$ODAGLINKREF" ] && error_exit "ODAG link falhou na criação"
debug "O ID do link ODAG: $ODAGLINKREF"

log "Armazenando os dados da pasta"
qlik app object properties "$SHEET" --app "$APP" > tmp_sheet_data.json

log "Armazenando os dados do botão (QID: $BUTTON_QID)"
qlik app object properties "$BUTTON_QID" --app "$APP" > tmp_button_data.json

log "Modificando o botão com a nova referência do ODAG"
TMPFILE=$(mktemp)
jq --arg odag "$ODAGLINKREF" \
   '.qMetaDef.odagLinkRef=$odag' \
   tmp_button_data.json > "$TMPFILE"
mv "$TMPFILE" tmp_button_data.json

log "Modificando os navPoints da pasta"
TMPFILE=$(mktemp)
jq --arg odag "$ODAGLINKREF" --arg name "$LINK_NAME" \
   '.navPoints[0].odagLinkRefID=$odag | .navPoints[0].title=$name' \
   tmp_sheet_data.json > "$TMPFILE"
mv "$TMPFILE" tmp_sheet_data.json

log "Aplicando modificações no botão..."
qlik app object set ./tmp_button_data.json --app "$APP"

log "Aplicando modificação na pasta..."
qlik app object set ./tmp_sheet_data.json --app "$APP"

log "Publicando pasta $SHEET"
qlik app object publish "$SHEET" --app "$APP"

log "Pronto! ✅"
