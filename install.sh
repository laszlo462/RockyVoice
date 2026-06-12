#!/usr/bin/env bash
# rocky-voice installer — fully self-contained.
# Installs the text skill for Claude Code and/or Hermes,
# then downloads rocky-tts/ into the current directory so each repo
# runs its own independent TTS server.
#
#   curl -fsSL https://raw.githubusercontent.com/Lagunaswift/RockyVoice/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Lagunaswift/RockyVoice/main/install.sh | bash -s -- --hermes

set -euo pipefail

REPO_RAW="${ROCKYVOICE_RAW:-https://raw.githubusercontent.com/Lagunaswift/RockyVoice/main}"
MODE="claude"

usage() {
  cat <<'EOF'
Usage: install.sh [--claude|--hermes|--all]

Default: --claude
  --claude   Install Claude Code skill to ~/.claude/skills/rocky-voice
  --hermes   Install Hermes skill to ~/.hermes/skills/creative/rocky-voice
  --all      Install both
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --claude) MODE="claude" ;;
    --hermes) MODE="hermes" ;;
    --all) MODE="all" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "rocky-voice: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

download() {
  local url="$1"
  local out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$out"
  else
    echo "rocky-voice: need curl or wget. Install one and re-run." >&2
    exit 1
  fi
}

# --- 1. Skill files ----------------------------------------------------------

install_claude() {
  local candidates=(
    "$HOME/.claude/skills"
    "$HOME/.config/claude/skills"
  )
  local dest=""
  for dir in "${candidates[@]}"; do
    if [ -d "$dir" ]; then
      dest="$dir"
      break
    fi
  done
  if [ -z "$dest" ]; then
    dest="$HOME/.claude/skills"
  fi

  mkdir -p "$dest/rocky-voice"
  echo "rocky-voice: installing Claude skill to $dest/rocky-voice"
  download "$REPO_RAW/rocky-voice/SKILL.md" "$dest/rocky-voice/SKILL.md"
}

install_hermes() {
  local hermes_home="${HERMES_HOME:-$HOME/.hermes}"
  local dest="$hermes_home/skills/creative/rocky-voice"
  mkdir -p "$dest"
  echo "rocky-voice: installing Hermes skill to $dest"
  download "$REPO_RAW/hermes/rocky-voice/SKILL.md" "$dest/SKILL.md"
}

case "$MODE" in
  claude) install_claude ;;
  hermes) install_hermes ;;
  all) install_claude; install_hermes ;;
esac

# --- 2. rocky-tts server -----------------------------------------------------

if [ -d "rocky-tts" ]; then
  echo "rocky-voice: rocky-tts/ already exists, updating files..."
else
  echo "rocky-voice: creating rocky-tts/ in current directory..."
  mkdir -p rocky-tts/public
fi

download "$REPO_RAW/rocky-tts/server.js"          "rocky-tts/server.js"
download "$REPO_RAW/rocky-tts/package.json"        "rocky-tts/package.json"
download "$REPO_RAW/rocky-tts/package-lock.json"   "rocky-tts/package-lock.json"
download "$REPO_RAW/rocky-tts/.env.example"        "rocky-tts/.env.example"
download "$REPO_RAW/rocky-tts/.gitignore"          "rocky-tts/.gitignore"
download "$REPO_RAW/rocky-tts/public/index.html"   "rocky-tts/public/index.html"
download "$REPO_RAW/rocky-tts/public/RockyVoice-James.wav" "rocky-tts/public/RockyVoice-James.wav"

# --- 3. .env ------------------------------------------------------------------

if [ ! -f "rocky-tts/.env" ]; then
  cp rocky-tts/.env.example rocky-tts/.env
  echo "rocky-voice: created rocky-tts/.env from template"
fi

# --- 4. npm install -----------------------------------------------------------

if command -v npm >/dev/null 2>&1; then
  echo "rocky-voice: installing dependencies..."
  (cd rocky-tts && npm install --silent)
else
  echo "rocky-voice: npm not found — run 'cd rocky-tts && npm install' manually."
fi

# --- 5. .gitignore ------------------------------------------------------------

add_gitignore() {
  local entry="$1"
  if [ -f ".gitignore" ]; then
    if ! grep -qxF "$entry" .gitignore; then
      echo "$entry" >> .gitignore
      echo "rocky-voice: added '$entry' to .gitignore"
    fi
  else
    echo "$entry" > .gitignore
    echo "rocky-voice: created .gitignore with '$entry'"
  fi
}

add_gitignore "rocky-tts/"
add_gitignore ".claude/settings.local.json"

# --- Done ---------------------------------------------------------------------

echo ""
echo "rocky-voice: done!"
echo ""
echo "Next steps:"
echo "  1. Edit rocky-tts/.env — add your Hume API key (platform.hume.ai)"
echo "  2. cd rocky-tts && npm start"
echo "  3. Open http://localhost:3333 and click Initialize"
echo "  4. Activate the Rocky skill in Claude Code and talk to space friend"
