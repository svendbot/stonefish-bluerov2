#!/usr/bin/env bash
# Run *inside the distrobox* (distrobox enter stonefish-jazzy) on first setup.
# Idempotent — safe to re-run.
set -euo pipefail

# Strip leaked host Nix paths so python3/pip resolve to the container's.
# PYTHONNOUSERSITE leaks from the Nix devShell and hides ~/.local/lib/pythonX.Y;
# unset it so the --user pip installs below are actually importable.
PATH="$(printf %s "$PATH" | tr ':' '\n' | grep -v '^/nix/' | paste -sd:)"
export PATH
unset PYTHONPATH PYTHONHOME PYTHONNOUSERSITE

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARDUPILOT_DIR="$HERE/ardupilot"
WS_DIR="$HERE/ws"

if [ ! -d "$ARDUPILOT_DIR/.git" ]; then
  echo "ERROR: $ARDUPILOT_DIR not found. Clone it on the host first:"
  echo "  cd $HERE && git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git"
  exit 1
fi

# 1. ArduPilot Python tooling (MAVProxy + pymavlink). Use --user so it lands
#    in the bind-mounted host home, not in the ephemeral container.
#    python3-wxgtk4.0 is required by MAVProxy's `--map` module.
echo "==> installing python3-wxgtk4.0 (apt, needed by MAVProxy map module)"
sudo apt-get install -y python3-wxgtk4.0
echo "==> installing MAVProxy / pymavlink (user pip)"
# Pin numpy <2 — the system cv2 (4.6) was compiled against numpy 1.x, and
# MAVProxy pulls in numpy as a dep. Without the pin, pip grabs numpy 2.x and
# `import cv2` crashes, which silently disables the map module.
pip install --user --break-system-packages 'numpy<2' MAVProxy pymavlink
pip install --user --break-system-packages 'empy==3.3.4'

# 2. PATH for ~/.local/bin and ArduPilot Tools/autotest is set by the
#    image's /etc/profile.d/stonefish-ros.sh — nothing to do at the host
#    level (the host ~/.bashrc is a read-only home-manager symlink anyway).
export PATH="$HOME/.local/bin:$ARDUPILOT_DIR/Tools/autotest:$PATH"

# 3. Build ArduSub SITL (native).
echo "==> waf configure --board sitl"
( cd "$ARDUPILOT_DIR" && ./waf configure --board sitl )
echo "==> waf sub  (this is the slow one — ~10 min first time)"
( cd "$ARDUPILOT_DIR" && ./waf sub )

# 4. Add the PHILL location used by the integration repo's launch.
LOC_FILE="$ARDUPILOT_DIR/Tools/autotest/locations.txt"
if ! grep -q '^PHILL=' "$LOC_FILE"; then
  echo "==> appending PHILL location"
  # Ensure the file ends with a newline before appending.
  [ -s "$LOC_FILE" ] && [ "$(tail -c1 "$LOC_FILE")" != "" ] && echo "" >> "$LOC_FILE"
  echo 'PHILL=56.026930,-3.385670,0,0' >> "$LOC_FILE"
fi

# 5. Build the overlay colcon workspace.  ROS setup files reference unset
#    vars (e.g. AMENT_TRACE_SETUP_FILES), so disable -u while sourcing.
echo "==> colcon build (stonefish_bluerov2 overlay)"
set +u
source /opt/ros/jazzy/setup.bash
source /opt/ros2_ws/install/setup.bash
set -u
( cd "$WS_DIR" && colcon build --symlink-install )

cat <<EOF

==========================================================================
 SITL setup done. Two terminals to run the simulation:

   Terminal 1 (SITL):
     distrobox enter stonefish-jazzy
     sim_vehicle.py -v ArduSub --model JSON --map -L PHILL -m --streamrate=-1

   Terminal 2 (Stonefish + bridge):
     distrobox enter stonefish-jazzy
     source ~/stonefish/ws/install/setup.bash
     ros2 launch stonefish_bluerov2 bluerov2_sim.py

 Then open QGroundControl on the host, set vehicle frame to "Vectored-6DOF".
==========================================================================
EOF
