#!/usr/bin/env bash
# =============================================================================
#  jcgDeploy.sh - justcreativegames.com tek komutla deploy (Ubuntu VPS + Docker)
#
#  Ne yapar:
#    1) Repoyu GitHub'dan ceker (ilk seferde clone, sonra pull)
#    2) Docker imajini build eder (nginx + statik dosyalar)
#    3) Eski container'i durdurup yenisini baslatir
#    4) Site cevap veriyor mu kontrol eder; vermiyorsa onceki surume geri doner
#
#  Kullanim:
#    Sunucuda    :  ./jcgDeploy.sh        (ilk seferde clone, sonra pull)
#    Baska repo  :  REPO_URL=... BRANCH=... PORT=... ./jcgDeploy.sh
#
#  Container yalnizca 127.0.0.1:PORT'u dinler. Alan adini sunucudaki mevcut
#  reverse proxy'den (nginx / caddy / traefik) bu porta yonlendir.
# =============================================================================
set -euo pipefail

# ----------------------------- AYARLAR --------------------------------------
# Kalici ayar icin: ~/.jcgDeploy.env dosyasina yaz (ornek:  NETWORK=npm_default)
if [ -f "$HOME/.jcgDeploy.env" ]; then . "$HOME/.jcgDeploy.env"; fi
REPO_URL="${REPO_URL:-https://github.com/mustafakemalkoseli/jcg_site.git}"
BRANCH="${BRANCH:-main}"
APP_DIR="${APP_DIR:-/opt/jcg_site}"      # repo sunucuda nereye inecek
NAME="${NAME:-jcg_site}"                 # container ve imaj adi
BIND="${BIND:-127.0.0.1}"                # disariya dogrudan acmak icin 0.0.0.0
PORT="${PORT:-8088}"                     # sunucuda bos bir port
NETWORK="${NETWORK:-}"                   # Nginx Proxy Manager vb. ile ayni docker agi (bos = yok)
# -----------------------------------------------------------------------------

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mHATA:\033[0m %s\n' "$*" >&2; exit 1; }

command -v git    >/dev/null || fail "git kurulu degil (sudo apt install git)."
command -v docker >/dev/null || fail "docker kurulu degil."
docker info >/dev/null 2>&1  || fail "docker'a erisilemiyor. 'sudo ./jcgDeploy.sh' ile calistir ya da kullaniciyi docker grubuna ekle."

# Script reponun icinden calistiriliyorsa o klasoru kullan
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/.git" ]; then APP_DIR="$SCRIPT_DIR"; fi

# ----------------------------- 1) KOD ----------------------------------------
if [ -d "$APP_DIR/.git" ]; then
  say "Guncelleniyor: $APP_DIR ($BRANCH)"
  git -C "$APP_DIR" fetch --prune origin "$BRANCH"
  # Deploy klasoru GitHub'daki halin birebir kopyasi olur (sunucuda elle yapilan degisiklikler silinir)
  git -C "$APP_DIR" checkout -q -B "$BRANCH" "origin/$BRANCH"
  git -C "$APP_DIR" reset -q --hard "origin/$BRANCH"
else
  [ -n "$REPO_URL" ] || fail "Ilk kurulum icin REPO_URL ver:  REPO_URL=git@github.com:KULLANICI/REPO.git ./jcgDeploy.sh"
  say "Klonlaniyor: $REPO_URL -> $APP_DIR"
  mkdir -p "$(dirname "$APP_DIR")"
  git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$APP_DIR"
fi
cd "$APP_DIR"
[ -f Dockerfile ] && [ -f index.html ] || fail "$APP_DIR icinde Dockerfile / index.html yok. Repo kok dizini site dosyalarini icermeli."
REV="$(git rev-parse --short HEAD)"

# ----------------------------- 2) BUILD --------------------------------------
say "Imaj build ediliyor: $NAME:$REV"
# onceki calisan imaji geri donus icin isaretle
if docker image inspect "$NAME:latest" >/dev/null 2>&1; then docker tag "$NAME:latest" "$NAME:previous"; fi
docker build --pull -t "$NAME:$REV" -t "$NAME:latest" .

# ----------------------------- 3) CALISTIR -----------------------------------
run_container() {  # $1 = imaj etiketi
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  local net=()
  if [ -n "$NETWORK" ]; then net=(--network "$NETWORK"); fi
  docker run -d --name "$NAME" --restart unless-stopped "${net[@]}" \
    -p "$BIND:$PORT:80" --label project="$NAME" "$NAME:$1" >/dev/null
}
healthy() {
  local i
  for i in $(seq 1 15); do
    if docker exec "$NAME" wget -q -O /dev/null http://127.0.0.1/ 2>/dev/null; then return 0; fi
    sleep 1
  done
  return 1
}

if [ -n "$NETWORK" ]; then docker network inspect "$NETWORK" >/dev/null 2>&1 || fail "Docker agi bulunamadi: $NETWORK  (docker network ls ile bak)"; fi
say "Container baslatiliyor: $NAME  ($BIND:$PORT -> 80${NETWORK:+, ag: $NETWORK})"
run_container latest

# ----------------------------- 4) KONTROL ------------------------------------
if healthy; then
  say "Tamam. Surum: $REV"
else
  docker logs --tail 30 "$NAME" || true
  if docker image inspect "$NAME:previous" >/dev/null 2>&1; then
    say "Yeni surum cevap vermedi, onceki surume donuluyor..."
    docker tag "$NAME:previous" "$NAME:latest"
    run_container latest
    healthy && fail "Yeni surum basarisiz oldu; onceki surum geri yuklendi." || fail "Geri donus de basarisiz. 'docker logs $NAME' ile bak."
  fi
  fail "Container cevap vermiyor. 'docker logs $NAME' ile bak."
fi

# eski, etiketsiz imajlari temizle (yalnizca bu projeninkiler)
docker image prune -f --filter "label=project=$NAME" >/dev/null 2>&1 || true

echo
docker ps --filter "name=^${NAME}$" --format '  {{.Names}}  {{.Status}}  {{.Ports}}'
echo "  Yerel test:  curl -I http://$BIND:$PORT/"
