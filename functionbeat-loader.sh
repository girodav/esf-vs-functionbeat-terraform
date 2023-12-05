#!/bin/bash

set -uo pipefail

eval "$(jq -er '@sh "VERSION=\(.version)
                    CONFIG_FILE=\(.config_file)"')"

CLONED_FOLDER="functionbeat-repo-raw"
DESTINATION=functionbeat-"${VERSION}"
GIT_REPO="https://github.com/aspacca/beats.git"

function download() {
  git clone --depth 1 --branch "${VERSION}" "${GIT_REPO}" "${CLONED_FOLDER}"
  mkdir -v -p "${DESTINATION}"
  cp -f "${CONFIG_FILE}" "${DESTINATION}"/functionbeat.yml
} &>/dev/null

function create_package_zip() {
  # shellcheck disable=SC2164
  cd "${CLONED_FOLDER}"
  go get -v -u ./...
  go mod tidy
  make mage
  # shellcheck disable=SC2164
  cd x-pack/functionbeat
  mage build
  # shellcheck disable=SC2164
  cd provider/aws
  cp functionbeat-aws ../../../../../"${DESTINATION}"/bootstrap
  # shellcheck disable=SC2164
  cd ../../../../../"${DESTINATION}"/
  zip ../"${DESTINATION}"-release.zip bootstrap
  zip ../"${DESTINATION}"-release.zip "${CONFIG_FILE}"
  # shellcheck disable=SC2103
  cd ..
  rm -rf "${CLONED_FOLDER}"
  rm -rf "${DESTINATION}"
} &>/dev/null

download
create_package_zip

jq -M -c -n --arg destination "${DESTINATION}-release.zip" '{"filename": $destination}'