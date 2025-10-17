# Qlik Sense Enterprise client-managed

## Conectar using curl
```bash
curl -v -L --ntlm --negotiate -u "DTPMSHOM\dante.clementino" --insecure https://servidor/qrs/app\?xrfkey\=0123456789abcdef --header "x-qlik-xrfkey: 0123456789abcdef" --header "User-Agent: Windows" -c tmp/cookie.txt
```

passar a senha e os cookies serão armazenados em um arquivo chamado cookie.txt

context = dev-client

This is how to use qlik-cli with Qlik Sense Enterprise client-managed repository API (QRS)

[ Qlik-cli with QSE ](https://qlik.dev/toolkits/qlik-cli/qlik-cli-qrs-get-started/)
[ Connecting using Microsoft Windows authentication ](https://help.qlik.com/en-US/sense-developer/May2025/Subsystems/RepositoryServiceAPI/Content/Sense_RepositoryServiceAPI/RepositoryServiceAPI-Example-Connect-cURL-Windows.htm)
[ Qlik-cli set up SaaS ](https://qlikcentral.com/2024/04/26/qlik-cli-qlik-saas-set-up/)

# API REST END POINTS
## Criar botão ODAG

https://v220d002003.prevnet/api/odag/v1/links?xrfkey=3qtoKCYpvDHRi5oo

### Body

```json
{
    "id":"",
    "name":"ODAG",
    "templateApp":"087584a6-82fd-4657-98c7-72aed98c7df4",
    "rowEstExpr":"SUM(QT_TAREFAS)",
    "privileges":[],
    "properties":{
        "rowEstRange":[
            {"context":"*","highBound":500000}
        ],
        "genAppLimit":[
            {"context":"User_*","limit":5}
        ],
        "appRetentionTime":[
            {"context":"User_*","retentionTime":"P1D"}
        ],
        "publishTo":[],
        "targetSheet":[
            {"context":"User_*","sheetId":""}
        ],
        "overrideGenAppLimit":[
            {"context":"User_*","overrideGenAppLimit":false}
        ]
    },
    "tags":[],
    "selectionApp":"73414317-6cf8-48e7-8472-36894ece7b68"
}
```


### Nos headers aparece

Cookie X-Qlik-Session=f97bdeba-72cb-42c7-ba15-84a3ccb8a5cd
x-qlik-xrfkey 3qtoKCYpvDHRi5oo

### Após criar o botão ODAG esse POST Request é chamado

https://v220d002003.prevnet/api/odag/v1/apps/73414317-6cf8-48e7-8472-36894ece7b68/selAppLinkUsages?xrfkey=3qtoKCYpvDHRi5oo

