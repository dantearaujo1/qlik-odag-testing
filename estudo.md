POST /api/v1/odaglinks

# Requisição

{
  "id": "",
  "name": "ODAG REST",
  "templateApp": "db5f7e80-cabd-4a7a-949e-bf76169fdaef",
  "rowEstExpr": "COUNT(1)",
  "privileges": [],
  "properties": {
    "rowEstRange": [
      {
        "context": "*",
        "highBound": 100
      }
    ],
    "genAppLimit": [
      {
        "context": "User_*",
        "limit": 5
      }
    ],
    "appRetentionTime": [
      {
        "context": "User_*",
        "retentionTime": "P1D"
      }
    ],
    "publishTo": [],
    "targetSheet": [
      {
        "context": "User_*",
        "sheetId": "mfNGpa"
      }
    ],
    "overrideGenAppLimit": [
      {
        "context": "User_*",
        "overrideGenAppLimit": false
      }
    ]
  },
  "tags": [],
  "selectionApp": "c6a6765a-6acf-41c1-be3f-22ab683a6fde"
}

# Resposta

{
  "bindings": [
    {
      "formatting": {
        "delimiter": ",",
        "quote": "'"
      },
      "range": {},
      "selectAppParamName": "field_Customer",
      "selectAppParamType": "Field",
      "selectionStates": "SO",
      "templateAppVarName": "field_Customer"
    }
  ],
  "createdDate": "2025-10-11T19:46:29.000Z",
  "id": "68eab4152e7e71d78d4a4df7",
  "modifiedByUser": {
    "id": "68e9678beb03e385f672c956",
    "name": "Dante Araujo",
    "subject": "auth0|a18345108a73eb2be12bcc910704adccca3d8c2a114a1adcd7410a643f612038",
    "tenantid": "iFX8J-TrWqGVK9Bz*QioTE_PvRFHitFI"
  },
  "modifiedDate": "0001-01-01T00:00:00.000Z",
  "name": "ODAG",
  "owner": {
    "id": "68e9678beb03e385f672c956",
    "name": "Dante Araujo",
    "subject": "auth0|a18345108a73eb2be12bcc910704adccca3d8c2a114a1adcd7410a643f612038",
    "tenantid": "iFX8J-TrWqGVK9Bz_QioTE_PvRFHitFI"
  },
  "privileges": null,
  "properties": {
    "appOpenMethod": null,
    "appRetentionTime": [
      {
        "context": "User*_",
        "retentionTime": "P1D"
      }
    ],
    "disable": null,
    "genAppLimit": [
      {
        "context":"User\__",
        "limit": 5
      }
    ],
    "genAppName": [
      {
        "context": "_",
        "formatString": "{0}*{1}{2}{3}*{4}{5}{6}",
        "params": [
          "templateAppName",
          "curYear",
          "curMonth",
          "curDay",
          "curHr",
          "curMin",
          "curSec"
        ]
      }
    ],
    "limitPolicy": null,
    "menuLabel": null,
    "overrideGenAppLimit": [
      {
        "context":"User\__",
        "overrideGenAppLimit": false
      }
    ],
    "rowEstRange": [
      {
        "context": "*",
        "highBound": 100
      }
    ],
    "targetSheet": [
      {
        "context": "User_*",
        "sheetId": "mfNGpa",
        "sheetName": "mfNGpa"
      }
    ]
  },
  "rowEstExpr": "COUNT(1)",
  "status": "active",
  "templateApp": {
    "id": "3cf3280b-dff0-4639-bf5b-eb2b7e96f208",
    "name": "template"
  },
  "templateAppChartObjects": null
}

### Headers
Cookie no header:

AWSALB=qFYx7v0nXxkd85CNJbW82a5m/VWkyW/vIAbLIutzDCRqd36iFMbOwhn8AtCz1ki3vVzP1PbNZzvIi7GHTaVIEpxSEngl1GNOnOv83g0l2q8z4MQxNNbWKnUHWrwW; AWSALBCORS=qFYx7v0nXxkd85CNJbW82a5m/VWkyW/vIAbLIutzDCRqd36iFMbOwhn8AtCz1ki3vVzP1PbNZzvIi7GHTaVIEpxSEngl1GNOnOv83g0l2q8z4MQxNNbWKnUHWrwW; eas.uaid=Mkzp39LUxS14kZX7yUwCCVWOEN4MuN9_.bFkSLgywH2U5pWlNS69OX9TeBPRhiST_GV6pENrIAF-s0CeYctgNuMhKee-U4_6JYjoC4PYa2C4PE0pm49exow; eas.sid=MOjw8Stf5wY4BBhlmhk6221urXyECvBL; eas.sid.sig=Jbm3Dx8hHRD4u6tCHhnHwgFdnzusqO2-CEki3UZNtrKU0qI-KnPS1NXr6rxkulsN_BV2LGe9HQPXYZn3BRhyxA; _csrfToken=i7yqsjNT-qSDvclSRwLmMYXr_4_nzFrFuDRM; _csrfToken.sig=6D1ioHUNvEp5GgpUMxS7HAqkZVoN4Nm9HnrXuQjp4nJqd_z16YtWbktIGtG_hzkQj9GnQK11mKQ8CzBakepk3A; Content-Security-Policy-Status=fetched

CSRF Token no header:
qlik-csrf-token
	i7yqsjNT-qSDvclSRwLmMYXr_4_nzFrFuDRM


Voce pode passar o Bearer TOken (API Key) na requisição


# Editar ODAG button no painel

GET https://8d1m74ejjtwuto3.us.qlikcloud.com/api/v1/odagapps?appType=template


{"data":[{"id":"3ee5ccd5-2005-4edc-ad7d-da9a49f5700d","name":"odag"},{"id":"3cf3280b-dff0-4639-bf5b-eb2b7e96f208","name":"template"}]}
