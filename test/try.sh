#!/usr/bin/env bash
# ============================================================
# Container zum Ausprobieren von install.sh von Hand.
#
#   test/try.sh fedora                        (fedora:44)
#   test/try.sh debian ~/Dokumente/assertj    (debian:13)
#
# - Benutzer mit gleicher UID wie auf dem Host und sudo ohne Passwort
# - dieses Repo als Kopie in ~/.config/nvim (auch nicht committete
#   Änderungen), install.sh startet man selbst
# - ein Projektordner (optional) unter /work/<name>, mit Schreibzugriff:
#   Maven/jdtls schreiben target/ usw. in den echten Ordner
#
# Der Container bleibt bestehen (Name nvim-try-<distro>). Nochmals
# aufrufen öffnet wieder eine Shell darin. Weg damit:
#   podman rm -f nvim-try-fedora
# ============================================================
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DISTRO=${1:-}
PROJ=${2:-}
case $DISTRO in
    fedora) IMAGE=registry.fedoraproject.org/fedora:44
            PREP="dnf install -y -q sudo git procps-ng" ;;
    debian) IMAGE=docker.io/library/debian:13
            PREP="apt-get update -qq && apt-get install -y -qq sudo git procps >/dev/null" ;;
    *) sed -n '2,18p' "$0"; exit 2 ;;
esac
NAME=nvim-try-$DISTRO
U=$(id -un)
UG="$(id -u):$(id -g)"

if ! podman container exists "$NAME"; then
    MOUNT=()
    if [ -n "$PROJ" ]; then
        PROJ=$(realpath "$PROJ")
        MOUNT=(-v "$PROJ:/work/$(basename "$PROJ")")
    fi
    echo "Erstelle $NAME ($IMAGE) …"
    # keep-id: gleiche UID wie auf dem Host, damit der Projektordner
    # beschreibbar ist. label=disable: SELinux-Labels des Ordners auf dem
    # Host nicht umschreiben (das täte :Z).
    podman run -d --name "$NAME" --hostname "$NAME" \
        --userns=keep-id --user root --security-opt label=disable \
        "${MOUNT[@]}" "$IMAGE" sleep infinity >/dev/null
    podman exec "$NAME" bash -c "$PREP"
    # keep-id legt den Benutzer mit Home / und /bin/sh an
    podman exec "$NAME" bash -c "
        sed -i 's|^$U:.*|$U:*:$UG:$U:$HOME:/bin/bash|' /etc/passwd
        echo '$U ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$U
        mkdir -p $HOME/.config
        cp -r /etc/skel/. $HOME/
        chown -R $UG $HOME"
    podman cp "$REPO/." "$NAME:$HOME/.config/nvim"
    podman exec "$NAME" chown -R "$UG" "$HOME/.config/nvim"
    echo
    echo "Im Container:  ~/.config/nvim/install.sh --no-font"
    [ -n "$PROJ" ] && echo "Projekt:       cd /work/$(basename "$PROJ") && nvim ."
    echo "Verlassen mit exit, der Container läuft weiter."
    echo
fi

podman start "$NAME" >/dev/null
exec podman exec -it --user "$UG" -w "$HOME" "$NAME" bash -l
