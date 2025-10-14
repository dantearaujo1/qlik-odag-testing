#!/bin/sh
echo "Entrando no contexto de desenvolvimento"
qlik context use dante # I called dante but you can change
# TODO: make name be dynamic
echo "Exportando o arquivo de filtro do ODAG"
qlik app export $(qlik app ls --quiet --name "selector odag") --output-file ./files/selection.qvf
# TODO: make name be dynamic
echo "Exportando o arquivo template do ODAG"
qlik app export $(qlik app ls --quiet --name "template") --output-file ./files/template.qvf
qlik context use prod # Can use prod or homolog, you can choose

APP=$(qlik app import --file files/selection.qvf --quiet) # pega o id da importação

TEMPLATE=$(qlik app import --file files/template.qvf --quiet) # pega o id da importação

# TODO: make title be dynamic
SHEET=$(qlik app object ls --app $APP --verbose --json | jq -r '.[] | select(.qType=="sheet" and .title=="My new sheet (1)") | .qId')

echo "Deixando privado..."
qlik app object unpublish $SHEET --app $APP

echo "Editando o template do ODAG..."
# TODO: make name be dynamic
jq --arg selectionApp "$APP" --arg templateApp "$TEMPLATE" --arg linkName "dante" '.name = $linkName | .selectionApp = $selectionApp | .templateApp = $templateApp' odag_create_template.json > tmp.json && rm -rf odag_create_template.json && mv tmp.json odag_create_template.json

echo "Preparando para criação do ODAG LINK"
ODAGLINKREF=$(qlik raw post /v1/odaglinks --body-file odag_create_template.json -q)
echo "ODAG LINK criado!"
echo "Identificando os dados da pasta"
qlik app object properties $SHEET --app $APP > tmp_sheet_data.json
echo "Identificando os dados do botão com o ODAG"
# TODO: make button id to be dynamic
qlik app object properties qpHx --app $APP > tmp_button_data.json

echo "Alterando os dados internos.."
jq --arg odag "$ODAGLINKREF" '.qMetaDef.odagLinkRef = $odag' tmp_button_data.json > tmp_button_result_data.json && rm -rf tmp_button_data.json && mv tmp_button_result_data.json tmp_button_data.json

jq --arg odag "$ODAGLINKREF" --arg name "dante" '.navPoints[0].odagLinkRefID = $odag | .navPoints[0].title = $name' tmp_sheet_data.json > tmp_sheet_result_data.json && rm -rf tmp_sheet_data.json && mv tmp_sheet_result_data.json tmp_sheet_data.json

echo "Enviando e configurando os botões"
qlik app object set ./tmp_button_data.json --app $APP
qlik app object set ./tmp_sheet_data.json --app $APP
echo "Publicando.."
qlik app object publish $SHEET --app $APP
echo "Import com sucesso"
