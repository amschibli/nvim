#!/usr/bin/env bash
# ============================================================
# Neovim mit dieser Config auf Fedora oder Debian einrichten.
#
#   git clone git@github.com:amschibli/nvim.git ~/.config/nvim
#   ~/.config/nvim/install.sh
#
# Mehrfach ausführbar: Was schon da ist, wird übersprungen.
#
#   --no-packages  keine Systempakete (kein sudo), nur Rest
#   --no-tools     Plugins, Mason und Treesitter nicht vorab
#                  installieren (passiert dann beim ersten Start)
#   --no-font      keine Nerd Font
# ============================================================
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
NVIM_MIN=0.12.0
TS_MIN=0.26.1   # nvim-treesitter (Branch main)
BIN=$HOME/.local/bin
OPT=$HOME/.local/opt
PACKAGES=true TOOLS=true FONT=true

for a in "$@"; do
    case $a in
        --no-packages) PACKAGES=false ;;
        --no-tools) TOOLS=false ;;
        --no-font) FONT=false ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "Unbekannte Option: $a" >&2; exit 2 ;;
    esac
done

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNUNG: %s\033[0m\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
# ver_ge 0.12.6 0.12.0 → wahr
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

case $(uname -m) in
    x86_64) ARCH_NVIM=x86_64 ARCH_LG=x86_64 ARCH_TS=x64 ;;
    aarch64|arm64) ARCH_NVIM=arm64 ARCH_LG=arm64 ARCH_TS=arm64 ;;
    *) echo "Architektur $(uname -m) nicht unterstützt" >&2; exit 1 ;;
esac

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
    *" fedora "*) DISTRO=fedora ;;
    *" debian "*|*" ubuntu "*) DISTRO=debian ;;
    *) echo "Nur Fedora und Debian/Ubuntu unterstützt (gefunden: $ID)" >&2; exit 1 ;;
esac

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO=sudo

mkdir -p "$BIN" "$OPT"
export PATH="$BIN:$PATH"

# --- 1. Systempakete -----------------------------------------
if $PACKAGES; then
    log "Systempakete ($DISTRO)"
    if [ $DISTRO = fedora ]; then
        P=(git ripgrep fd-find gcc make unzip gzip tar curl
           python3 wl-clipboard fontconfig tree-sitter-cli
           java-25-openjdk-devel postgresql mysql)
        # Neovim aus Fedora reicht (44: 0.12.x)
        P+=(neovim)
        have node || P+=(nodejs npm)
        $SUDO dnf install -y --skip-unavailable "${P[@]}"
    else
        # build-essential statt gcc: ohne Recommends fehlen sonst
        # die C-Header (libc6-dev) für die Treesitter-Parser
        P=(git ripgrep fd-find build-essential unzip gzip tar curl
           ca-certificates xz-utils python3 python3-venv
           wl-clipboard fontconfig
           postgresql-client default-mysql-client)
        have node || P+=(nodejs npm)
        $SUDO apt-get update
        # jdtls braucht Java 21+, 25 wenn vorhanden
        if apt-cache show openjdk-25-jdk >/dev/null 2>&1; then
            P+=(openjdk-25-jdk)
        else
            P+=(openjdk-21-jdk)
        fi
        $SUDO env DEBIAN_FRONTEND=noninteractive \
            apt-get install -y --no-install-recommends "${P[@]}"
    fi
fi

# Debian nennt fd «fdfind»
if ! have fd && have fdfind; then
    ln -sf "$(command -v fdfind)" "$BIN/fd"
fi

# --- 2. Neovim (Debian hat nur 0.10) -------------------------
nvim_ver() { nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true; }
if ! have nvim || ! ver_ge "$(nvim_ver)" $NVIM_MIN; then
    log "Neovim von GitHub (System: $(nvim_ver || true), braucht $NVIM_MIN+)"
    T=nvim-linux-$ARCH_NVIM
    curl -fL --progress-bar -o "$OPT/$T.tar.gz" \
        "https://github.com/neovim/neovim/releases/latest/download/$T.tar.gz"
    rm -rf "$OPT/nvim"
    tar -xzf "$OPT/$T.tar.gz" -C "$OPT"
    mv "$OPT/$T" "$OPT/nvim"
    rm "$OPT/$T.tar.gz"
    ln -sf "$OPT/nvim/bin/nvim" "$BIN/nvim"
    hash -r
fi
echo "Neovim $(nvim_ver): $(command -v nvim)"

# --- 3. lazygit (nicht in Fedora/Debian) ---------------------
if ! have lazygit; then
    log "lazygit von GitHub"
    V=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
        | grep -Po '"tag_name": *"v\K[^"]+')
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v$V/lazygit_${V}_linux_$ARCH_LG.tar.gz" \
        | tar -xz -C "$BIN" lazygit
fi

# --- 4. tree-sitter-CLI (Debian: fehlt oder zu alt) -----------
ts_ver() { tree-sitter --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true; }
if ! have tree-sitter || ! ver_ge "$(ts_ver)" $TS_MIN; then
    log "tree-sitter-CLI von GitHub"
    curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$ARCH_TS.gz" \
        | gunzip > "$BIN/tree-sitter"
    chmod +x "$BIN/tree-sitter"
    hash -r
fi

# --- 5. Nerd Font --------------------------------------------
if $FONT && have fc-list; then
    if fc-list | grep -qi "JetBrainsMono Nerd"; then
        echo "Nerd Font schon da"
    else
        log "JetBrainsMono Nerd Font"
        F=$HOME/.local/share/fonts/JetBrainsMono
        mkdir -p "$F"
        curl -fL --progress-bar \
            https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz \
            | tar -xJ -C "$F"
        fc-cache -f >/dev/null
        echo "Im Terminal die Schrift «JetBrainsMono Nerd Font» einstellen."
    fi
fi

# --- 6. Config an ihren Platz --------------------------------
log "Config"
CFG=$HOME/.config/nvim
if [ "$(readlink -f "$CFG" 2>/dev/null)" != "$REPO" ]; then
    if [ -e "$CFG" ]; then
        echo "$CFG gibt es schon und ist nicht dieses Repo ($REPO)." >&2
        echo "Wegschieben (mv $CFG $CFG.bak) und neu starten." >&2
        exit 1
    fi
    mkdir -p "$HOME/.config"
    ln -s "$REPO" "$CFG"
    echo "$CFG → $REPO"
fi
# markdownlint ausserhalb von Neovim mit denselben Regeln
[ -e "$HOME/.markdownlint-cli2.yaml" ] \
    || ln -s "$CFG/.markdownlint-cli2.yaml" "$HOME/.markdownlint-cli2.yaml"

# --- 7. Plugins, Mason, Treesitter ---------------------------
# Ein einziger Aufruf: Nach dem Klonen starten Plugins schon eigene
# Installationen, die ein vorzeitiges :qa abbrechen würde.
if $TOOLS; then
    log "Plugins (lazy-lock.json), Mason, Treesitter – ein paar Minuten"
    nvim --headless "+Lazy! restore" \
        "+luafile $CFG/scripts/headless-setup.lua"
fi

# --- Fertig --------------------------------------------------
log "Fertig"
if ! bash -lc 'case ":$PATH:" in *":$HOME/.local/bin:"*) exit 0;; esac; exit 1'; then
    warn "~/.local/bin ist in einer neuen Shell nicht im PATH."
    echo "In ~/.bashrc ergänzen: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
if ! java -version 2>&1 | grep -qE 'version "(2[1-9]|[3-9][0-9])'; then
    warn "java ist nicht Version 21+ – jdtls (Java-LSP) startet so nicht."
fi
echo "Neovim starten: nvim  ·  Prüfen: :checkhealth"
