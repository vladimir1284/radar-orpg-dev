#!/bin/bash
# PID 1 for the ORPG production container: start the RPG, stay alive, shut it down cleanly on SIGTERM.
source "$HOME/.bash_profile"

# Client: must resolve to this host; the container hostname changes unless --hostname is pinned.
sed -i "s/^Client: .*/Client: $(hostname)/" "$HOME/.rssd.conf"

INFRA='^(entrypoint.sh|bash|sleep|ps|grep|rssd|mrpg|owr_server|nds)$'

shutdown() {
    mrpg -p -v shutdown
    # mrpg only sends the command; wait (max 25s) until the op processes exit. Infra daemons stay up.
    for _ in $(seq 1 50); do
        ps -e -o comm= | grep -qvE "$INFRA" || break
        sleep 0.5
    done
    exit 0
}
trap shutdown TERM INT

mrpg -p -v startup > "$HOME/startup.log" 2>&1
cat "$HOME/startup.log"

sleep infinity &
wait $!
