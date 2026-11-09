#!/usr/bin/env bash
# Confere se saiu versão nova do OpenBot e atualiza a loja.
# Só atualiza sozinho quando compose.yaml e seccomp.json oficiais não mudaram.
# Se mudaram, abre uma issue para revisão e não mexe em nada.
set -euo pipefail

APP="openbot-server"
IMAGE="ghcr.io/nightly-labs/openbot"
UPSTREAM="nightly-labs/openbot"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Upload pelo site do GitHub não marca scripts como executáveis. O Umbrel precisa disso no hook.
fixed=0
for f in "${APP}/hooks/pre-start" "${APP}/hooks/pre-uninstall" "${APP}/lib/prepare-data.sh" scripts/update-openbot.sh; do
  if [[ -f "${f}" && "$(git ls-files -s "${f}" | cut -c1-6)" != "100755" ]]; then
    git update-index --chmod=+x "${f}"
    fixed=1
  fi
done
if (( fixed )); then
  git commit -m "Marca scripts como executáveis"
  git push
fi

# Versão do app = versão do OpenBot, com sufixo -patch.N quando só o pacote muda
# (mesmo formato dos apps oficiais do Umbrel, por exemplo 0.22.5-patch.2).
# Sem mudar a versão, o Umbrel não entrega a correção a quem já instalou.
version_of() { sed -n 's/^version: "\(.*\)"$/\1/p' "$1"; }

if [[ "${GITHUB_EVENT_NAME:-}" == "push" && -n "${PUSH_BEFORE:-}" && ! "${PUSH_BEFORE}" =~ ^0+$ ]] \
   && git cat-file -e "${PUSH_BEFORE}^{commit}" 2>/dev/null; then
  changed="$(git diff --name-only "${PUSH_BEFORE}" HEAD -- "${APP}" | grep -v "^${APP}/umbrel-app.yml$" || true)"
  before_version="$(git show "${PUSH_BEFORE}:${APP}/umbrel-app.yml" 2>/dev/null | sed -n 's/^version: "\(.*\)"$/\1/p' || true)"
  now_version="$(version_of "${APP}/umbrel-app.yml")"
  if [[ -n "${changed}" && "${before_version}" == "${now_version}" ]]; then
    base="${now_version%%-patch.*}"
    n=0
    [[ "${now_version}" == *-patch.* ]] && n="${now_version##*-patch.}"
    patched="${base}-patch.$((n + 1))"
    sed -i -E "s#^version: \".*\"#version: \"${patched}\"#" "${APP}/umbrel-app.yml"
    echo "Pacote mudou sem troca de versão:"; echo "${changed}"
    git add "${APP}/umbrel-app.yml"
    git commit -m "Pacote: versão ${patched}"
    git push
  fi
fi

current="$(version_of "${APP}/umbrel-app.yml")"
current_base="${current%%-patch.*}"
tag="$(gh api "repos/${UPSTREAM}/releases/latest" --jq .tag_name)"
new="${tag#v}"

if [[ ! "${new}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Tag inesperada: ${tag}. Nada feito."; exit 0
fi
if [[ "${new}" == "${current_base}" ]]; then
  echo "OpenBot já na versão ${new} (pacote ${current})."; exit 0
fi
if [[ "$(printf '%s\n%s\n' "${current_base}" "${new}" | sort -V | tail -n 1)" != "${new}" ]]; then
  echo "A versão publicada (${new}) é mais antiga que a da loja (${current_base}). Nada feito."; exit 0
fi
echo "Nova versão: ${current} -> ${new}"

tmp="$(mktemp -d)"
curl -fsSL "https://raw.githubusercontent.com/${UPSTREAM}/${tag}/docker/compose.yaml" -o "${tmp}/compose.yaml"
curl -fsSL "https://raw.githubusercontent.com/${UPSTREAM}/${tag}/docker/seccomp.json" -o "${tmp}/seccomp.json"

changed=()
cmp -s "${tmp}/compose.yaml" upstream/compose.yaml || changed+=("docker/compose.yaml")
cmp -s "${tmp}/seccomp.json" "${APP}/seccomp.json" || changed+=("docker/seccomp.json")

if (( ${#changed[@]} > 0 )); then
  title="OpenBot v${new}: revisar mudanças em ${changed[*]}"
  if [[ -z "$(gh issue list --state open --search "\"${title}\" in:title" --json number --jq '.[].number')" ]]; then
    {
      echo "A versão v${new} mudou arquivos de implantação. A loja continua na v${current} até a revisão."
      echo
      echo "Notas: https://github.com/${UPSTREAM}/releases/tag/${tag}"
      echo
      echo '```diff'
      diff -u upstream/compose.yaml "${tmp}/compose.yaml" || true
      diff -u "${APP}/seccomp.json" "${tmp}/seccomp.json" || true
      echo '```'
    } > "${tmp}/body.md"
    gh issue create --title "${title}" --body-file "${tmp}/body.md"
  fi
  exit 0
fi

# A imagem é publicada depois da release. Se ainda não existe, tenta na próxima rodada.
if ! raw="$(docker buildx imagetools inspect --raw "${IMAGE}:${tag}" 2>/dev/null)"; then
  echo "Imagem ${IMAGE}:${tag} ainda não publicada."; exit 0
fi
for arch in amd64 arm64; do
  if ! jq -e --arg a "${arch}" '.manifests[] | select(.platform.os=="linux" and .platform.architecture==$a)' <<<"${raw}" >/dev/null; then
    echo "Imagem ${tag} sem linux/${arch}. Nada feito."; exit 0
  fi
done
digest="$(docker buildx imagetools inspect "${IMAGE}:${tag}" --format '{{json .Manifest}}' | jq -r .digest)"
[[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "Digest inválido: ${digest}"; exit 1; }

sed -i -E "s#(image: ${IMAGE}):[^@]+@sha256:[0-9a-f]{64}#\1:${tag}@${digest}#" "${APP}/docker-compose.yml"
sed -i -E "s#^version: \".*\"#version: \"${new}\"#" "${APP}/umbrel-app.yml"
sed -i -E "s#OpenBot v[0-9]+\.[0-9]+\.[0-9]+\. Notas da versão:#OpenBot v${new}. Notas da versão:#; s#releases/tag/v[0-9]+\.[0-9]+\.[0-9]+#releases/tag/${tag}#" "${APP}/umbrel-app.yml"

grep -q "${IMAGE}:${tag}@${digest}" "${APP}/docker-compose.yml" || { echo "Falha ao trocar a imagem."; exit 1; }
grep -q "^version: \"${new}\"" "${APP}/umbrel-app.yml" || { echo "Falha ao trocar a versão."; exit 1; }

git add "${APP}/docker-compose.yml" "${APP}/umbrel-app.yml"
git commit -m "OpenBot ${tag}"
git push
