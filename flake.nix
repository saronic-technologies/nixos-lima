{
  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
    # nixpkgs-unstable is used only for lima in the devShell; the stable nixpkgs
    # version is outdated and approaching end-of-life.
    nixpkgs-unstable.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*";
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      determinate,
      ...
    }:
    let
      lib = nixpkgs.lib;

      devSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      pkgsFor = system: nixpkgs.legacyPackages.${system};
      pkgsUnstableFor = system: nixpkgs-unstable.legacyPackages.${system};

      makeImage =
        system: nixosSystem:
        import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          pkgs = pkgsFor system;
          config = nixosSystem.config;
          inherit lib;
          format = "qcow2-compressed";
          partitionTableType = "efi";
        };

      mkNixosConfig =
        {
          system,
          withDeterminate ? false,
        }:
        lib.nixosSystem {
          inherit system;
          modules = lib.optionals withDeterminate [ determinate.nixosModules.default ] ++ [
            self.nixosModules.lima
            { services.lima.enable = true; }
            ./image.nix
          ];
        };
    in
    {
      packages = {
        aarch64-linux = {
          nixos-image = makeImage "aarch64-linux" self.nixosConfigurations.nixos-aarch64;
          nixos-determinate-image = makeImage "aarch64-linux" self.nixosConfigurations.nixos-determinate-aarch64;
        };
        x86_64-linux = {
          nixos-image = makeImage "x86_64-linux" self.nixosConfigurations.nixos-x86_64;
          nixos-determinate-image = makeImage "x86_64-linux" self.nixosConfigurations.nixos-determinate-x86_64;
        };
      };

      devShells = lib.genAttrs devSystems (system: {
        default =
          let
            pkgs = pkgsFor system;
            pkgsUnstable = pkgsUnstableFor system;
          in
          pkgs.mkShell {
            packages = [
              pkgs.qemu
              # withAdditionalGuestAgents bundles guest agent binaries for both
              # aarch64 and x86_64, needed to serve the correct binary to each VM.
              (pkgsUnstable.lima.override { withAdditionalGuestAgents = true; })
            ];
          };
      });

      nixosConfigurations = {
        nixos-aarch64 = mkNixosConfig { system = "aarch64-linux"; };
        nixos-x86_64 = mkNixosConfig { system = "x86_64-linux"; };
        nixos-determinate-aarch64 = mkNixosConfig {
          system = "aarch64-linux";
          withDeterminate = true;
        };
        nixos-determinate-x86_64 = mkNixosConfig {
          system = "x86_64-linux";
          withDeterminate = true;
        };
      };

      nixosModules.lima = {
        imports = [ ./lima.nix ];
      };

      formatter = lib.genAttrs devSystems (system: (pkgsFor system).nixfmt);
    };
}
