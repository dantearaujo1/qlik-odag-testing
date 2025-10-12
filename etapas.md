# Configurando os ambientes

## Qlik Sense Cloud

- Um usuário capaz de exportar, importar, editar apps
- Ter role de desenvolvedor: Administration -> manage users -> grant developer role
- Atualizar a pagina -> API Keys -> Generate New
- Copia a chave para alguma lugar seguro

## Qlik CLI (Command Line Interface)


## Passo a passo

### Cli

#### Após a primeira vez importado e com o odag configurado você pode automatizar com esse procedimento:

- Configurar os dois ambientes no qlik-cli atraves do qlik context
- Descobrir o id do botão com o configurado
- Descobrir o id do link do botão com o odag [odagLinkRef]

```bash
qlik context use dev
qlik app export id_app --output-file nome_do_arquivo_view.qvf
qlik app export id_app2 --output-file nome_do_arquivo_template.qvf
qlik context use prod
qlik app import --file  nome_do_arquivo_view.qvf [--name "Nome do aplicativo"] --appId id_app
qlik app object properties obj_id --app ["Nome do aplicativo"] >> button.json
# swap data
qlik app object set swapped_file --app ["Nome do aplicativo"]

```
