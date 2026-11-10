#!/usr/bin/env bash
# ============================================================
# install.sh in einem frischen Container testen, wie auf einem
# neuen PC: Benutzer mit sudo, Repo nach ~/.config/nvim kopiert.
#
#   test/container-test.sh fedora     (fedora:44)
#   test/container-test.sh debian     (debian:13)
#   test/container-test.sh arch       (archlinux:latest, nur x86_64)
#   test/container-test.sh debian -i  danach Shell im Container
#
# Braucht podman. Nimmt den aktuellen Stand des Repos (auch nicht
# committete Änderungen), ohne .git und Sicherungen.
# ============================================================
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
case ${1:-} in
    fedora) IMAGE=registry.fedoraproject.org/fedora:44
            PREP="dnf install -y -q sudo git" ;;
    debian) IMAGE=docker.io/library/debian:13
            PREP="apt-get update -qq && apt-get install -y -qq sudo git >/dev/null" ;;
    # Das Image kennt nur geo/fastly.mirror.pkgbuild.com, die sind von
    # hier aus langsam und brechen ab. Schweizer Spiegel davor setzen.
    arch)   IMAGE=docker.io/library/archlinux:latest
            PREP='{ printf "Server = https://%s/archlinux/\$repo/os/\$arch\n" mirror.init7.net pkg.adfinis.com mirror.puzzle.ch; cat /etc/pacman.d/mirrorlist; } > /tmp/ml && mv /tmp/ml /etc/pacman.d/mirrorlist && pacman -Syu --noconfirm --needed sudo git >/dev/null' ;;
    *) echo "Aufruf: $0 fedora|debian|arch [-i]" >&2; exit 2 ;;
esac
SHELL_AFTER=${2:-}

# Repo-Kopie ohne .git und *.bak*
SRC=$(mktemp -d)
trap 'rm -rf "$SRC"' EXIT
tar -C "$REPO" --exclude=.git --exclude='*.bak*' -cf - . | tar -C "$SRC" -xf -

TEST='
set -e
nvim --version | head -1
ls ~/.local/share/nvim/mason/packages | sort > /tmp/vorher
echo "--- Start mit Java-Datei, Fehler in :messages?"
mkdir -p /tmp/p && cd /tmp/p
printf "class A { }\n" > A.java
nvim --headless A.java "+sleep 3" "+redir! > /tmp/msg | silent messages | redir END" +qa
if grep -iE "error|fehler" /tmp/msg; then exit 1; fi
echo "--- Mason: fehlt etwas aus mason.txt?"
grep -v "^#" ~/.config/nvim/mason.txt | sort > /tmp/soll
ls ~/.local/share/nvim/mason/packages | sort > /tmp/ist
if comm -23 /tmp/soll /tmp/vorher | grep .; then echo "fehlt nach install.sh"; exit 1; fi
if comm -23 /tmp/soll /tmp/ist | grep .; then echo "fehlt nach Start"; exit 1; fi
echo "TEST OK"
'

podman run --rm ${SHELL_AFTER:+-it} -v "$SRC:/src:ro,Z" "$IMAGE" bash -c "
set -e
$PREP
useradd -m -s /bin/bash t
echo 't ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/t
su - t -c 'mkdir -p ~/.config && cp -r /src ~/.config/nvim && ~/.config/nvim/install.sh --no-font'
su - t -c '$TEST'
[ -n '$SHELL_AFTER' ] && exec su - t || true
"
