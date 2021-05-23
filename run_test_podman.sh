#!/bin/bash

set -ex

IMAGE="${1:-ghcr.io/amezin/gnome-shell-pod-34-xsession:master}"

POD=$(podman run --rm --cap-add=SYS_NICE --cap-add=IPC_LOCK -td "${IMAGE}")

down () {
    podman kill $POD
}

trap down INT TERM EXIT

podman exec ${POD} systemctl is-system-running --wait

do_in_pod() {
    podman exec --user gnomeshell --workdir /home/gnomeshell ${POD} set-env.sh "$@"
}

podman cp ddterm@amezin.github.com.shell-extension.zip ${POD}:/home/gnomeshell/
do_in_pod enable-extension.sh ddterm@amezin.github.com.shell-extension.zip

do_in_pod wait-dbus-interface.sh -d org.gnome.Shell -o /org/gnome/Shell/Extensions/ddterm -i com.github.amezin.ddterm.Extension -t 10
sleep 1

exit_code=0
do_in_pod gdbus call --session --timeout 300 --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/ddterm --method com.github.amezin.ddterm.Extension.RunTest || exit_code=$?

if (( exit_code )); then
    do_in_pod journalctl --user -n 25
fi

podman cp ${POD}:/run/Xvfb_screen0 .
convert xwd:Xvfb_screen0 Xvfb_screen0.png

exit $exit_code