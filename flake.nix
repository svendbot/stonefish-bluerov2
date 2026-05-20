{
  description = "Stonefish dev environment: distrobox + podman";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          distrobox
          podman
          podman-compose
          slirp4netns
          fuse-overlayfs
          conmon
          tmux
        ];

        # On NixOS, rootless podman also needs system-level config:
        #   virtualisation.podman.enable = true;
        #   virtualisation.podman.dockerCompat = true;  # optional: docker CLI alias
        # Without that, subuid/subgid mappings and the storage driver
        # won't be wired up and `podman run` will fail.
        shellHook = ''
          echo "distrobox $(distrobox --version 2>/dev/null | head -1)"
          echo "podman    $(podman --version)"
        '';
      };
    };
}
