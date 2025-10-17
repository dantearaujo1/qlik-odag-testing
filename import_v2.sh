#!/bin/bash
set -euo pipefail

################################
# DEFAULT VALUES (can be overridden by args)
################################
SRC_CONTEXT="dante"
DST_CONTEXT="prod"
SRC_STREAM="dante"
DST_STREAM="dante"
SELECTION_NAME="selector odag"
TEMPLATE_NAME="template"
LINK_NAME="ODAG HELLO"
SHEET_TITLE="Sheet"
BUTTON_QID="kjscey"
ODAG_TEMPLATE_FILE="odag_create_template.json"
DEBUG=false
INLOCO=false
SRC_ENV="cloud"
DST_ENV="cloud"
STREAM="aaec8d41-5201-43ab-809f-3063750dfafd"
SERVER="v220d002003.prevnet"

#CONFIG VALUES
DATA_DIR="files"
CFG_DIR=".config"
TMP_DIR="tmp"

# SESSION CURL REQUEST INFORMATION
COOKIE="X-Qlik-Session=15f4027e-5f0c-45f0-8a20-77e8efdeb6eb" # A forma é igual tem nos cookies do navegador X-Qlik-Session=xxxxxxxxx
XRFKEY="ZkmESpgNhziutMmb"

################################
# PARSE COMMAND-LINE ARGUMENTS
################################
while [ $# -gt 0 ]; do
  case "$1" in
    --src-context) SRC_CONTEXT="$2"; shift 2 ;;
    --dst-context) DST_CONTEXT="$2"; shift 2 ;;
    --src-stream) SRC_STREAM="$2"; shift 2 ;;
    --dst-stream) SRC_STREAM="$2"; shift 2 ;;
    --selection-name) SELECTION_NAME="$2"; shift 2 ;;
    --template-name) TEMPLATE_NAME="$2"; shift 2 ;;
    --link-name) LINK_NAME="$2"; shift 2 ;;
    --sheet-title) SHEET_TITLE="$2"; shift 2 ;;
    --button-id) BUTTON_QID="$2"; shift 2 ;;
    --template-file) ODAG_TEMPLATE_FILE="$2"; shift 2 ;;
    --dst-env) DST_ENV="$2"; shift 2 ;;
    --src-env) SRC_ENV="$2"; shift 2 ;;
    --debug) DEBUG=true; shift 1 ;;
    --inloco) INLOCO=true; shift 1 ;;
    --help)
      echo "Uso: $0 [options]"
      echo
      echo "Opções:"
      echo "  --src-context <name> # Nome dado ao contexto configurado de origem"
      echo "  --src-env <name> # Ambiente onde estão os dados de origem"
      echo "  --dst-context <name> # Nome dado ao contexto configurado de destino"
      echo "  --src-stream <name>  # ID do fluxo de origem"
      echo "  --dst-stream <name>  # ID do fluxo de destino"
      echo "  --dst-env <name>  # Local do servidor [cloud|windows]"
      echo "  --selection-name <app_name> # Nome do arquivo de seleção"
      echo "  --template-name <app_name> # Nome do arquivo de template"
      echo "  [--link-name <string>] # Nome dado ao Link ODAG CRiado"
      echo "  --sheet-title <title> # Nome da pasta de trabalho do botão"
      echo "  --button-id <qid> # ID do botão que quer deixar configurado"
      echo "  --template-file <file> # Nome do arquivo de template de requisição do ODAG"
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
if [[ "$INLOCO" = false ]]; then
  log "*Modo de importação com dados da nuvem*"
  log "Mudando o contexto para fonte: $SRC_CONTEXT"
  qlik context use "$SRC_CONTEXT"

  log "Exportando ODAG selection app: $SELECTION_NAME"
  SEL_APP_ID=$(qlik app ls --quiet --name "$SELECTION_NAME" | awk '{print $1}')
  [ -z "$SEL_APP_ID" ] && error_exit "Nenhum aplicativo encontrado com nome: '$SELECTION_NAME'"
  debug "Seleção encontrada app ID: $SEL_APP_ID"
  if [[ $SRC_ENV = "cloud" ]]; then
    qlik app export "$SEL_APP_ID" --output-file $DATA_DIR/selection.qvf
  else
    qlik qrs app export create "$SEL_APP_ID" --output-file $DATA_DIR/selection.qvf --insecure
  fi

  log "Exportando ODAG template app: $TEMPLATE_NAME"
  TMP_APP_ID=$(qlik app ls --quiet --name "$TEMPLATE_NAME" | awk '{print $1}')
  [ -z "$TMP_APP_ID" ] && error_exit "Nenhum aplicativo encontrado com nome: '$TEMPLATE_NAME'"
  debug "Template encontrado app ID: $TMP_APP_ID"

  if [[ $SRC_ENV = "cloud" ]]; then
    qlik app export "$TMP_APP_ID" --output-file $DATA_DIR/template.qvf
  else
    qlik qrs app export create "$TMP_APP_ID" --output-file $DATA_DIR/template.qvf --insecure
  fi
else
  log "*Modo de importação com dados locais*"
fi

log "Mudando o contexto para destino: $DST_CONTEXT"

qlik context use "$DST_CONTEXT"
if [[ $DST_ENV = "windows" ]]; then
  # qlik context login --insecure
  echo "Jumping"
fi

log "Importando template.qvf"
if [[ $DST_ENV = "cloud" ]]; then
  TEMPLATE=$(qlik app import --file $DATA_DIR/template.qvf --quiet)
else
  TEMPLATE=$(qlik qrs app upload create --file $DATA_DIR/template.qvf --quiet --insecure --name automation-test-template --keepdata)
  qlik qrs app reload $TEMPLATE --insecure
fi
[ -z "$TEMPLATE" ] && error_exit "Failed to import template.qvf"
debug "Template importado como ID: $TEMPLATE"

log "Importando selection.qvf"
if [[ $DST_ENV = "cloud" ]]; then
  APP=$(qlik app import --file $DATA_DIR/selection.qvf --quiet)
else
  APP=$(qlik qrs app upload create --file $DATA_DIR/selection.qvf --quiet --insecure --name automation-test --keepdata)
  qlik qrs app reload $APP --insecure
fi
[ -z "$APP" ] && error_exit "Falha na importação de selection.qvf"
debug "App de seleção importado como ID: $APP"


log "Procurando pasta com o nome: $SHEET_TITLE"
SHEET=$(qlik app object ls --app "$APP" --verbose --insecure --json |
  jq -r --arg title "$SHEET_TITLE" '.[] | select(.qType=="sheet" and .title==$title) | .qId')

[ -z "$SHEET" ] && error_exit "Nenhuma pasta encontrada com '$SHEET_TITLE'"
debug "Pasta encontrada com ID: $SHEET"

if [[ $DST_ENV = "cloud" ]]; then
  log "Despublicando a pasta de ID $SHEET"
  qlik app object unpublish "$SHEET" --app "$APP"
else
  # qlik qrs app object unpublish "$SHEET" --insecure
  debug "Pulamos a etapa de despublicação"
fi

log "Modificando o arquivo de template ODAG: $ODAG_TEMPLATE_FILE"
[ ! -f "$ODAG_TEMPLATE_FILE" ] && error_exit "Arquivo '$ODAG_TEMPLATE_FILE' não encontrado."

TMPFILE=$(mktemp)
jq --arg sApp "$APP" \
   --arg tApp "$TEMPLATE" \
   --arg lName "$LINK_NAME" \
   '.name=$lName | .selectionApp=$sApp | .templateApp=$tApp' \
   "$ODAG_TEMPLATE_FILE" > "$TMPFILE"
mv "$TMPFILE" "$ODAG_TEMPLATE_FILE"

debug $(cat $ODAG_TEMPLATE_FILE)

log "Criando o link ODAG..."
if [[ $DST_ENV = "cloud" ]]; then
  ODAGLINKREF=$(qlik raw post /v1/odaglinks --body-file "$ODAG_TEMPLATE_FILE" -q)
else

  curl -v -L --ntlm --negotiate -u x-qlik-xrfkey: 0123456789abcdef" --header "User-Agent: Windows" -c "tmp/cookie.txt"

  COOKIE=$(grep 'X-Qlik-Session' $TMP_DIR/cookie.txt | awk '{print $7}'))

  ODAGLINKREF=$(curl --location -k --request POST "https://$SERVER/api/odag/v1/links?xrfkey=${XRFKEY}" \
      -H "Cookie: ${COOKIE}" \
      -H "X-Qlik-Xrfkey:${XRFKEY}" \
      -H "Content-Type: application/json" \
      --data @odag_create_template.json | jq -r '.objectDef.id')
fi

[ "$ODAGLINKREF" = ""] && error_exit "ODAG link falhou na criação"
debug "O ID do link ODAG: $ODAGLINKREF"

log "Armazenando os dados da pasta"
if [[ $DST_ENV = "cloud" ]]; then
  qlik app object properties "$SHEET" --app "$APP" > $TMP_DIR/tmp_sheet_data.json
else
  qlik app object properties "$SHEET" --app "$APP" > $TMP_DIR/tmp_sheet_data.json --insecure
fi

log "Armazenando os dados do botão (QID: $BUTTON_QID)"
if [[ $DST_ENV = "cloud" ]]; then
  qlik app object properties "$BUTTON_QID" --app "$APP" > $TMP_DIR/tmp_button_data.json
else
  qlik app object properties "$BUTTON_QID" --app "$APP" > $TMP_DIR/tmp_button_data.json --insecure
fi

log "Modificando o botão com a nova referência do ODAG"
TMPFILE=$(mktemp)
jq --arg odag "$ODAGLINKREF" \
   '.qMetaDef.odagLinkRef=$odag' \
   $TMP_DIR/tmp_button_data.json > "$TMPFILE"
mv "$TMPFILE" $TMP_DIR/tmp_button_data.json

log "Modificando os navPoints da pasta"
TMPFILE=$(mktemp)
jq --arg odag "$ODAGLINKREF" --arg name "$LINK_NAME" \
   '.navPoints[0].odagLinkRefID=$odag | .navPoints[0].title=$name' \
   $TMP_DIR/tmp_sheet_data.json > "$TMPFILE"
mv "$TMPFILE" $TMP_DIR/tmp_sheet_data.json

log "Aplicando modificações no botão..."
if [[ $DST_ENV = "cloud" ]]; then
  qlik app object set $TMP_DIR/tmp_button_data.json --app "$APP"
else
  # qlik qrs app object unpublish "$SHEET" --insecure
  qlik app object set $TMP_DIR/tmp_button_data.json --app "$APP" --insecure
fi

log "Aplicando modificação na pasta..."
if [[ $DST_ENV = "cloud" ]]; then
  qlik app object set $TMP_DIR/tmp_sheet_data.json --app "$APP"
else
  qlik app object set $TMP_DIR/tmp_sheet_data.json --app "$APP" --insecure
fi

if [[ $DST_ENV = "cloud" ]]; then
  log "Publicando pasta $SHEET"
  qlik app object publish "$SHEET" --app "$APP"
else
  log "Publicando app $APP no fluxo: $(qlik qrs stream get $STREAM --insecure | jq '.name')"
  qlik qrs app publish $APP --stream $STREAM --insecure
fi

log "Pronto! ✅"
