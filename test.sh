#!/bin/sh

  curl -v -L --ntlm --negotiate -u ":" --insecure https://v220d002003.prevnet/qrs/app\?xrfkey\=0123456789abcdef --header "x-qlik-xrfkey: 0123456789abcdef" --header "User-Agent: Windows" -c "tmp/cookie.txt"
