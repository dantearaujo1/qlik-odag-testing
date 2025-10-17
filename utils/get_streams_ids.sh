#!/bin/sh
FILE=$1

echo $(cat $FILE | jq '.data | map({key: .attributes.name, value: .id}) | from_entries')
