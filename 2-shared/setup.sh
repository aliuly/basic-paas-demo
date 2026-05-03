#!/bin/sh
#
# Call set-up scripts in the right order
#
set -euf
( set -o pipefail 2>/dev/null ) && set -o pipefail

: "${ELB_ID:?not set — run this script via krun}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
for i in \
      grafana-ingress \
      http-redir \
      asm \
      asm-console
do
  echo "$i"
  echo ====================
  ${SCRIPT_DIR}/setup/$i
  rc=$?
  echo "Return code: $rc"
done
