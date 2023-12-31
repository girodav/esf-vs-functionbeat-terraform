#!/bin/sh
# Reference https://github.com/PacoVK/terraform-aws-functionbeat
set -uox pipefail

eval "$(jq -er '@sh "VERSION=\(.version)
                    ENABLED_FUNCTION=\(.enabled_function)
                    CONFIG_FILE=\(.config_file)"')"

SYSTEM="$(uname | awk '{print tolower($0)}')"
FUNCTION_BEAT_URL=https://artifacts.elastic.co/downloads/beats/functionbeat/functionbeat-"${VERSION}"-"${SYSTEM}"-x86_64.tar.gz

DESTINATION=functionbeat-"${VERSION}"-"${SYSTEM}"-x86_64

export BEAT_STRICT_PERMS=false
export ENABLED_FUNCTION="${ENABLED_FUNCTION}"

if [ ! -d "${DESTINATION}" ]; then
  curl -s "${FUNCTION_BEAT_URL}" > "${DESTINATION}".tar.gz
  tar xzvf "${DESTINATION}".tar.gz > /dev/null
  rm -rf "${DESTINATION}".tar.gz
fi

cp -f "${CONFIG_FILE}" "${DESTINATION}"/functionbeat.yml

# shellcheck disable=SC2164
cd "${DESTINATION}"
./functionbeat -v -e package --output ./../"${DESTINATION}-release".zip

# shellcheck disable=SC2103
cd ..
rm -rf "${DESTINATION}"

jq -M -c -n --arg destination "${DESTINATION}-release.zip" '{"filename": $destination}'