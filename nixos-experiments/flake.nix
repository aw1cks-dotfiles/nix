{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    deploy-rs.url = "github:serokell/deploy-rs";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      deploy-rs,
      ...
    }@inputs:
    let
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      isVmBuild = builtins.getEnv "NIX_VM_BUILD" == "1";
      mkSystem = import ./modules/lib/mksystem.nix {
        inherit nixpkgs inputs;
      };
    in rec {
      nixosConfigurations = {
        dazhbog = mkSystem "dazhbog" {
          system = "aarch64-linux";
          user   = "alex";
          disko  = true;
          inherit isVmBuild;
        };
        dziewanna = mkSystem "dziewanna" {
          system = "x86_64-linux";
          user   = "alex";
          disko  = true;
          inherit isVmBuild;
        };
        nixosvirt01 = mkSystem "nixosvirt01" {
          system = "x86_64-linux";
          user   = "alex";
          disko  = true;
          inherit isVmBuild;
        };
      };

      packages =
        let
          mkImagePackage = machineName: systemConfig:
            (systemConfig.pkgs.runCommand "${machineName}-image.raw" {
              script = systemConfig.config.system.build.diskoImagesScript;
            } ''
              ${systemConfig.pkgs.bash}/bin/bash $script --build-memory 16384
              mv ${machineName}.raw $out
            '');
        in
        {
          x86_64-linux = nixpkgs.lib.mapAttrs (name: config: mkImagePackage name config) nixosConfigurations;
          aarch64-linux = nixpkgs.lib.mapAttrs (name: config: mkImagePackage name config) nixosConfigurations;
        };

      apps =
        let
          mkTestVmApp = machineName: systemConfig: hostPkgs: {
            type = "app";
            program = "${(import ./apps/test-vm/default.nix {
              pkgs = systemConfig.pkgs;
              config = systemConfig.config;
              hostPkgs = hostPkgs;
              machineName = machineName;
            })}/bin/test-image";
          };

          mkMakeImageApp = machineName: hostPkgs: {
            type = "app";
            program = "${(import ./apps/make-image/default.nix {
              hostPkgs = hostPkgs;
              machineName = machineName;
            })}/bin/make-image";
          };

          mkAppsForHost = hostPkgs: (
            nixpkgs.lib.mapAttrs' (name: config: {
              name = name;
              value = mkTestVmApp name config hostPkgs;
            }) nixosConfigurations
            //
            nixpkgs.lib.mapAttrs' (name: config: {
              name = "make-image-${name}";
              value = mkMakeImageApp name hostPkgs;
            }) nixosConfigurations
          );
        in
        {
          x86_64-linux = (mkAppsForHost nixpkgs.legacyPackages.x86_64-linux) // { default = self.apps.x86_64-linux.nixosvirt01; };
          aarch64-linux = (mkAppsForHost nixpkgs.legacyPackages.aarch64-linux) // { default = self.apps.aarch64-linux.dazhbog; };
        };

      devShells = {
        x86_64-linux = pkgs.mkShell {
          packages = with pkgs; [ deploy-rs.packages.x86_64-linux.default just ];
        };
        aarch64-linux = pkgs.mkShell {
          packages = with pkgs; [ deploy-rs.packages.aarch64-linux.default just ];
        };
      };

      deploy = let
        mkDeploy = machine: {
          hostname = machine.config.networking.hostName;
          sshUser = "alex";
          sshPort = 222;
          fastConnection = true;
          remoteBuild = true;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.${machine.pkgs.system}.activate.nixos self.nixosConfigurations.${machine.config.networking.hostName};
          };
        };
      in {
        nodes = builtins.map (name: mkDeploy self.nixosConfigurations.${name}) (builtins.attrNames self.nixosConfigurations);
      };

      debug = nixpkgs.lib.mapAttrs (name: value: { isVmBuild = value.config.my.system.isVmBuild; }) nixosConfigurations;
    };
}
