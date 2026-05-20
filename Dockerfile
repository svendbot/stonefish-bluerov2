FROM osrf/ros:jazzy-desktop

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      cmake \
      git \
      libglm-dev \
      libsdl2-dev \
      libfreetype-dev \
      python3-colcon-common-extensions \
      ros-jazzy-xacro \
      ros-jazzy-tf-transformations \
      # ArduPilot SITL build deps (subset of install-prereqs-ubuntu.sh,
      # no ARM cross-compile — only native SITL).
      python3-pip \
      python3-setuptools \
      python3-wheel \
      python3-future \
      python3-lxml \
      python3-ptyprocess \
      python3-pexpect \
      python3-numpy \
      python3-matplotlib \
      python3-scipy \
      python3-pyparsing \
      libtool \
      libtool-bin \
      pkg-config \
      ccache \
      libffi-dev \
      libssl-dev \
 && rm -rf /var/lib/apt/lists/*

# Stonefish core library — v1.3 tag is required for compatibility with the
# scenario files and launch wrapper in bvibhav/stonefish_bluerov2.
# Modern gcc no longer transitively includes <cstdint>, so v1.3 fails to
# compile uint64_t in Sample.h. Patch the common header.
WORKDIR /opt
RUN git clone --branch v1.3 https://github.com/patrykcieslak/stonefish.git \
 && sed -i '/^#include <string>/i #include <cstdint>' \
        stonefish/Library/include/StonefishCommon.h \
 && cmake -S stonefish -B stonefish/build -DCMAKE_BUILD_TYPE=Release \
 && cmake --build stonefish/build -j"$(nproc)" \
 && cmake --install stonefish/build \
 && ldconfig

# stonefish_ros2 v1.3 — also required for stonefish_simulator.launch.py
WORKDIR /opt/ros2_ws/src
RUN git clone --branch v1.3 https://github.com/patrykcieslak/stonefish_ros2.git

WORKDIR /opt/ros2_ws
RUN . /opt/ros/jazzy/setup.sh \
 && apt-get update \
 && rosdep update \
 && rosdep install --from-paths src --ignore-src -r -y \
 && colcon build --symlink-install \
 && rm -rf /var/lib/apt/lists/*

RUN echo 'source /opt/ros/jazzy/setup.bash'        >> /root/.bashrc \
 && echo 'source /opt/ros2_ws/install/setup.bash'  >> /root/.bashrc

# distrobox bind-mounts the host home, so /root/.bashrc is not in scope
# for the entering user. profile.d is system-wide and login-sourced.
RUN printf '%s\n' \
      '# Host env (e.g. Nix devShells) can leak its python3.13 ahead of the' \
      '# container python3.12 — prepend system bins so container tools win.' \
      'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:$PATH"' \
      'unset PYTHONPATH' \
      '# Nix shells set PYTHONNOUSERSITE=1 which hides ~/.local pip --user.' \
      'unset PYTHONNOUSERSITE' \
      '# pip --user lands here; ArduPilot Tools/autotest holds sim_vehicle.py.' \
      'export PATH="$HOME/.local/bin:$HOME/stonefish/ardupilot/Tools/autotest:$PATH"' \
      'source /opt/ros/jazzy/setup.bash' \
      'source /opt/ros2_ws/install/setup.bash' \
      > /etc/profile.d/stonefish-ros.sh \
 && chmod +x /etc/profile.d/stonefish-ros.sh

CMD ["bash"]
