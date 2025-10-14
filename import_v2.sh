#!/bin/bash
set -euo pipefail

################################
# DEFAULT VALUES (can be overridden by args)
################################
DEV_CONTEXT="dante"
PROD_CONTEXT="prod"
SELECTION_NAME="selector odag"
TEMPLATE_NAME="template"
LINK_NAME="dante"
SHEET_TITLE="My new sheet (1)"
BUTTON_QID="qpHx"
ODAG_TEMPLATE_FILE="odag_create_template.json"
DEBUG=false

################################
# PARSE COMMAND-LINE ARGUMENTS
################################
while [ $# -gt 0 ]; do
  case "$1" in
    --dev-context) DEV_CONTEXT="$2"; shift 2 ;;
    --prod-context) PROD_CONTEXT="$2"; shift 2 ;;
    --selection-name) SELECTION_NAME="$2"; shift 2 ;;
    --template-name) TEMPLATE_NAME="$2"; shift 2 ;;
    --link-name) LINK_NAME="$2"; shift 2 ;;
    --sheet-title) SHEET_TITLE="$2"; shift 2 ;;
    --button-id) BUTTON_QID="$2"; shift 2 ;; --template-file) ODAG_TEMPLATE_FILE="$2"; shift 2 ;;
    --debug) DEBUG=true; shift 1 ;;
    --help)
      echo "Usage: $0 [options]"
      echo
      echo "Options:"
      echo "  --dev-context <name>"
      echo "  --prod-context <name>"
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
      echo "Unknown option: $1"
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
  command -v "$1" >/dev/null 2>&1 || error_exit "Command '$1' not found."
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
log "Switching to development context: $DEV_CONTEXT"
qlik context use "$DEV_CONTEXT"

log "Exporting ODAG selection app: $SELECTION_NAME"
SEL_APP_ID=$(qlik app ls --quiet --name "$SELECTION_NAME" | awk '{print $1}')
[ -z "$SEL_APP_ID" ] && error_exit "No app found with name '$SELECTION_NAME'"
debug "Found selection app ID: $SEL_APP_ID"
qlik app export "$SEL_APP_ID" --output-file ./files/selection.qvf

log "Exporting ODAG template app: $TEMPLATE_NAME"
TMP_APP_ID=$(qlik app ls --quiet --name "$TEMPLATE_NAME" | awk '{print $1}')
[ -z "$TMP_APP_ID" ] && error_exit "No app found with name '$TEMPLATE_NAME'"
debug "Found template app ID: $TMP_APP_ID"
qlik app export "$TMP_APP_ID" --output-file ./files/template.qvf

log "Switching to production context: $PROD_CONTEXT"
qlik context use "$PROD_CONTEXT"

log "Importing selection.qvf"
APP=$(qlik app import --file files/selection.qvf --quiet)
[ -z "$APP" ] && error_exit "Failed to import selection.qvf"
debug "Imported selection app as ID: $APP"

log "Importing template.qvf"
TEMPLATE=$(qlik app import --file files/template.qvf --quiet)
[ -z "$TEMPLATE" ] && error_exit "Failed to import template.qvf"
debug "Imported template app as ID: $TEMPLATE"

log "Locating sheet with title: $SHEET_TITLE"
SHEET=$(qlik app object ls --app "$APP" --verbose --json |
  jq -r --arg title "$SHEET_TITLE" '.[] | select(.qType=="sheet" and .title==$title) | .qId')

[ -z "$SHEET" ] && error_exit "No sheet found with title '$SHEET_TITLE'"
debug "Found sheet ID: $SHEET"

log "Unpublishing sheet $SHEET"
qlik app object unpublish "$SHEET" --app "$APP"

log "Editing ODAG template file: $ODAG_TEMPLATE_FILE"
[ ! -f "$ODAG_TEMPLATE_FILE" ] && error_exit "File '$ODAG_TEMPLATE_FILE' not found."

TMPFILE=$(mktemp)
jq --arg sApp "$APP" \
   --arg tApp "$TEMPLATE" \
   --arg lName "$LINK_NAME" \
   '.name=$lName | .selectionApp=$sApp | .templateApp=$tApp' \
   "$ODAG_TEMPLATE_FILE" > "$TMPFILE"
mv "$TMPFILE" "$ODAG_TEMPLATE_FILE"

log "Creating ODAG link..."
ODAGLINKREF=$(qlik raw post /v1/odaglinks --body-file "$ODAG_TEMPLATE_FILE" -q)
[ -z "$ODAGLINKREF" ] && error_exit "Failed to create ODAG link"
debug "ODAG link reference: $ODAGLINKREF"

log "Retrieving sheet object data"
qlik app object properties "$SHEET" --app "$APP" > tmp_sheet_data.json

log "Retrieving button object data (QID: $BUTTON_QID)"
qlik app object properties "$BUTTON_QID" --app "$APP" > tmp_button_data.json

log "Updating button with ODAG reference"
TMPFILE=$(mktemp)
jq --arg odag "$ODAGLINKREF" \
   '.qMetaDef.odagLinkRef=$odag' \
   tmp_button_data.json > "$TMPFILE"
mv "$TMPFILE" tmp_button_data.json

log "Updating sheet navPoints"
TMPFILE=$(mktemp)
jq --arg odag "$ODAGLINKREF" --arg name "$LINK_NAME" \
   '.navPoints[0].odagLinkRefID=$odag | .navPoints[0].title=$name' \
   tmp_sheet_data.json > "$TMPFILE"
mv "$TMPFILE" tmp_sheet_data.json

log "Applying updated button object"
qlik app object set ./tmp_button_data.json --app "$APP"

log "Applying updated sheet object"
qlik app object set ./tmp_sheet_data.json --app "$APP"

log "Publishing sheet $SHEET"
qlik app object publish "$SHEET" --app "$APP"

log "Done! ✅"
