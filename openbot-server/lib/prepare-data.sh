#!/usr/bin/env bash
# Roda sem privilégio (UID 1000), chamado por hooks/pre-start.
# Sem argumento: prepara pastas e faz backup quando a versão muda.
# Com --firewall-ok: registra a versão e marca o status como pronto.
set -euo pipefail
umask 077

APP_DIR="${APP_DATA_DIR:?}"
DATA="${APP_DIR}/data/openbot"
BACKUPS="${APP_DIR}/data/backups"
STATUS="${APP_DIR}/data/status"
KEEP_BACKUPS=2

VERSION="$(sed -n 's/^version: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "${APP_DIR}/umbrel-app.yml" | head -n 1)"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

write_status() {
  local state="$1" message="$2" firewall="$3" last_backup count
  last_backup="$(ls -1t "${BACKUPS}"/openbot-data-*.tar.gz 2>/dev/null | head -n 1 || true)"
  count="$(find "${BACKUPS}" -maxdepth 1 -name 'openbot-data-*.tar.gz' 2>/dev/null | wc -l)"
  umask 022
  cat > "${STATUS}/status.json.tmp" <<EOF
{
  "version": "${VERSION}",
  "started_at": "${NOW}",
  "state": "${state}",
  "message": "${message}",
  "last_backup": "${last_backup##*/}",
  "backups": ${count},
  "firewall": "${firewall}"
}
EOF
  mv "${STATUS}/status.json.tmp" "${STATUS}/status.json"
}

if [[ "${1:-}" == "--firewall-ok" ]]; then
  echo "${VERSION}" > "${STATUS}/last-version"
  write_status "ok" "Iniciado" "ativo"
  (umask 022; cat /proc/sys/kernel/random/boot_id > "${STATUS}/firewall-ok")
  exit 0
fi

mkdir -p "${DATA}" "${BACKUPS}"
(umask 022; mkdir -p "${STATUS}")
chmod 755 "${STATUS}"

LAST_VERSION="$(cat "${STATUS}/last-version" 2>/dev/null || true)"
if [[ -n "${LAST_VERSION}" && "${LAST_VERSION}" != "${VERSION}" && -n "$(ls -A "${DATA}")" ]]; then
  need_kb="$(du -sk "${DATA}" | cut -f1)"
  free_kb="$(df -Pk "${BACKUPS}" | awk 'NR==2 {print $4}')"
  if (( free_kb < need_kb * 12 / 10 + 1048576 )); then
    write_status "erro" "Sem espaço para o backup antes de atualizar de ${LAST_VERSION} para ${VERSION}. O OpenBot não foi iniciado." "pendente"
    exit 1
  fi
  file="${BACKUPS}/openbot-data-v${LAST_VERSION}-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
  tar --numeric-owner -czf "${file}.partial" -C "${DATA}" .
  gzip -t "${file}.partial"
  mv "${file}.partial" "${file}"
  ls -1t "${BACKUPS}"/openbot-data-*.tar.gz | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
fi

write_status "iniciando" "Aplicando firewall" "pendente"
