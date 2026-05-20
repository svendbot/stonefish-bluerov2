#!/usr/bin/env bash
# Launch SITL + Stonefish bridge in a tmux session on the host.
# Each pane re-enters the distrobox to run its command.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOX="stonefish-jazzy"
SESSION="stonefish"

ARDUSUB_BIN="$HERE/ardupilot/build/sitl/bin/ardusub"
WS_SETUP="$HERE/ws/install/setup.bash"

if [ ! -x "$ARDUSUB_BIN" ]; then
  echo "ERROR: $ARDUSUB_BIN not built. Run setup first:"
  echo "  distrobox enter $BOX -- ~/stonefish/setup-sitl.sh"
  exit 1
fi

if [ ! -f "$WS_SETUP" ]; then
  echo "ERROR: $WS_SETUP missing. Run setup first:"
  echo "  distrobox enter $BOX -- ~/stonefish/setup-sitl.sh"
  exit 1
fi

# Reattach if the session is already up.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "==> session '$SESSION' already running — attaching"
  exec tmux attach -t "$SESSION"
fi

# Host tmux leaks $TMUX into the box; ArduPilot's run_in_terminal_window.sh
# then tries `tmux new-window` against the host socket from inside the
# container, which silently fails and ardusub never launches.  Unset it so
# RiTW falls through to the "log to /tmp/ArduSub.log" path.
SITL_CMD='unset TMUX; sim_vehicle.py -v ArduSub --model JSON --map -L PHILL -A "--sim-port-out=9012" -m --streamrate=-1'
BRIDGE_CMD='source ~/stonefish/ws/install/setup.bash && ros2 launch stonefish_bluerov2 bluerov2_sim.py'

# Pane 0: SITL.  Pane 1: Stonefish + bridge.
tmux new-session -d -s "$SESSION" -n sim \
  "distrobox enter $BOX -- bash -lc '$SITL_CMD; echo; echo \"[SITL exited — press any key]\"; read -n1'"

# Give SITL a head start so the bridge has something to talk to.
sleep 2

tmux split-window -h -t "$SESSION:sim" \
  "distrobox enter $BOX -- bash -lc '$BRIDGE_CMD; echo; echo \"[bridge exited — press any key]\"; read -n1'"

tmux select-layout -t "$SESSION:sim" even-horizontal
tmux select-pane -t "$SESSION:sim.0"

cat <<EOF
==========================================================================
 tmux session '$SESSION' started.
   Left pane:  SITL (sim_vehicle.py)
   Right pane: Stonefish + ardusim_patch bridge

 tmux quick keys (prefix = Ctrl-b):
   Ctrl-b o     switch pane          Ctrl-b z   zoom current pane
   Ctrl-b d     detach (leaves it running)
   Ctrl-b [     scrollback (q to exit)

 Reattach:    ~/stonefish/run-sim.sh   (or: tmux attach -t $SESSION)
 Tear down:   tmux kill-session -t $SESSION

 QGroundControl is separate — run ~/stonefish/qgc.sh inside the box
 (or via:  distrobox enter $BOX -- ~/stonefish/qgc.sh ).
==========================================================================
EOF

exec tmux attach -t "$SESSION"
