# stonefish

BlueROV2 + ArduSub SITL on the [Stonefish](https://github.com/patrykcieslak/stonefish)
underwater simulator, running ROS 2 Jazzy inside a
[distrobox](https://distrobox.it/) container on a NixOS host.

The container image pins Stonefish and `stonefish_ros2` to **v1.3** because
that is what the [`stonefish_bluerov2`](https://github.com/bvibhav/stonefish_bluerov2)
integration repo (scenarios + launch wrapper + UDP bridge) is built against.


## Prerequisites

NixOS host with rootless podman enabled in the system config:

```nix
virtualisation.podman.enable = true;
virtualisation.podman.dockerCompat = true;  # optional
```

Then on the host:

```sh
nix develop                      # distrobox + podman + tmux in PATH
```

## Setup

```sh
# 1. Build the image
podman build -t localhost/stonefish:jazzy .

# 2. Clone the things the image does not bake in
git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git
git clone https://github.com/bvibhav/stonefish_bluerov2.git ws/src/stonefish_bluerov2

# 3. Download QGroundControl.AppImage into qgc/
#    https://github.com/mavlink/qgroundcontrol/releases

# 4. Create the distrobox
distrobox assemble create --file distrobox.ini

# 5. Build SITL + colcon overlay inside the box (slow first time, ~10 min)
distrobox enter stonefish-jazzy -- ~/stonefish/setup-sitl.sh
```

## Running

```sh
./run-sim.sh                                       # tmux: SITL (left) + Stonefish bridge (right)
distrobox enter stonefish-jazzy -- ~/stonefish/qgc.sh   # separate terminal
```

In QGroundControl, set the vehicle frame to **Vectored-6DOF**.

Detach the tmux session with `Ctrl-b d`; reattach by re-running `./run-sim.sh`.
Tear it all down with `tmux kill-session -t stonefish`.

## Notes

- The `/etc/profile.d/stonefish-ros.sh` profile script inside the image
  scrubs `PYTHONPATH` and prepends the container `PATH` to defeat
  Nix devShell env leakage from the host.
- SITL ↔ bridge link is UDP port 9012 (BlueROV2). 9002 is the BlueBoat port.
- Stonefish v1.3 is missing a `<cstdint>` include; the Dockerfile patches
  `StonefishCommon.h` before building.
