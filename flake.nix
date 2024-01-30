# Based on https://github.com/nix-community/home-manager#nix-flakes
{
  description = "Home Manager flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, ... } @ inputs: {
    homeConfigurations = {
      rlmbp2022 = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        modules = [
          ./home-manager/modules/home-manager.nix
          ./home-manager/modules/common.nix
          ./home-manager/modules/zsh.nix
          ./home-manager/mac.nix
          {
            home = {
              username = "USERNAME";
              homeDirectory = "/Users/USERNAME";
              stateVersion = "23.11";
            };
          }
        ];
      };

    };
  };
}

