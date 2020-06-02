#!/usr/bin/env bash

# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_ROOT=$(dirname "${BASH_SOURCE[0]}")/..

DIFFROOT="${SCRIPT_ROOT}/_examples"
TMP_DIFFROOT="${SCRIPT_ROOT}/_tmp/_examples"
_tmp="${SCRIPT_ROOT}/_tmp"

cleanup() {
  rm -rf "${_tmp}"
}
trap "cleanup" EXIT SIGINT

cleanup

mkdir -p "${TMP_DIFFROOT}"
cp -a "${DIFFROOT}"/* "${TMP_DIFFROOT}"

"${SCRIPT_ROOT}/hack/update-codegen.sh"
echo "diffing ${DIFFROOT} against freshly generated codegen"
ret=0
diff -Naupr "${DIFFROOT}" "${TMP_DIFFROOT}" || ret=$?

if [[ -n "${OPENSHIFT_CI:-}" ]]; then
  # cp -a is not compatible with running in a non-privileged openshift
  # container (https://github.com/openshift/release/issues/1584).
  # It's safe to revert to index when running in CI since no user
  # changes are at risk of being lost.
  git checkout "${SCRIPT_ROOT}"
else
  cp -a "${TMP_DIFFROOT}"/* "${DIFFROOT}"
fi

if [[ $ret -eq 0 ]]
then
  echo "${DIFFROOT} up to date."
else
  echo "${DIFFROOT} is out of date. Please run hack/update-codegen.sh"
  exit 1
fi

# smoke test
echo "Smoke testing _example by compiling..."
go build "./${SCRIPT_ROOT}/_examples/crd/..."
go build "./${SCRIPT_ROOT}/_examples/apiserver/..."
go build "./${SCRIPT_ROOT}/_examples/MixedCase/..."
go build "./${SCRIPT_ROOT}/_examples/HyphenGroup/..."
