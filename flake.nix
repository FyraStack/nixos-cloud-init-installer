{
  description = "Minimal x86_64 NixOS cloud image for Proxmox with cloud-init";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05"; # Change me on NixOS upgrades!
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      nixosConfiguration = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
        ];
      };
      cfg = nixosConfiguration.config;
      imageName = "nixos-cloud-proxmox-${cfg.system.nixos.label}-x86_64";
    in
    {
      nixosConfigurations = {
        x86_64 = nixosConfiguration;
      };

      packages.${system} =
        let
          makeQcow2 =
            {
              compressed ? false,
              nameSuffix ? "",
            }:
            pkgs.runCommand "${imageName}${nameSuffix}.qcow2"
              {
                nativeBuildInputs = [
                  pkgs.findutils
                  pkgs.qemu-utils
                ];
              }
              ''
                mkdir -p $out
                raw_image=$(find ${cfg.system.build.cloudImage} -type f -name '*.img' -print -quit)

                if [ -z "$raw_image" ]; then
                  echo "Could not find raw cloud image in ${cfg.system.build.cloudImage}" >&2
                  exit 1
                fi

                qemu-img convert -f raw -O qcow2 ${nixpkgs.lib.optionalString compressed "-c"} "$raw_image" "$out/${imageName}${nameSuffix}.qcow2"

                mkdir -p $out/nix-support
                echo "file qcow2-image $out/${imageName}${nameSuffix}.qcow2" > $out/nix-support/hydra-build-products
              '';
        in
        rec {
          qcow2 = makeQcow2 { };
          qcow2-compressed = makeQcow2 {
            compressed = true;
            nameSuffix = "-compressed";
          };

          vma = cfg.system.build.VMA;
          default = qcow2;
        };

      formatter.${system} = pkgs.nixfmt;
    };
}
