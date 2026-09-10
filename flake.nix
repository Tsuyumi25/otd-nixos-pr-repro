{
  description = "Pinned NixOS integration harness for OpenTabletDriver PR #4672 and HidSharpCore PR #31";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    otd-src = {
      url = "github:Tsuyumi25/OpenTabletDriver/3339730d0e469978d29324bf94acf242ceec74a1";
      flake = false;
    };

    hidsharp-src = {
      url = "github:Tsuyumi25/HIDSharpCore/34667a671f96e52a2cf2c93c9ac263634085a368";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      otd-src,
      hidsharp-src,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      makePackages =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          hidSharpCore = pkgs.callPackage ./packages/hidsharpcore.nix {
            src = hidsharp-src;
          };
          opentabletdriver = pkgs.callPackage ./packages/opentabletdriver.nix {
            src = otd-src;
            inherit hidSharpCore;
          };
        in
        {
          inherit hidSharpCore opentabletdriver;
          default = opentabletdriver;
        };
    in
    {
      packages = forAllSystems makePackages;

      checks = forAllSystems (system: {
        package = self.packages.${system}.default;
      });

      overlays.default = final: _prev: {
        opentabletdriver = final.callPackage ./packages/opentabletdriver.nix {
          src = otd-src;
          hidSharpCore = final.callPackage ./packages/hidsharpcore.nix {
            src = hidsharp-src;
          };
        };
      };

      nixosModules.default =
        { pkgs, ... }:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          assertions = [
            {
              assertion = builtins.hasAttr system self.packages;
              message = "otd-nixos-pr-repro supports only x86_64-linux and aarch64-linux";
            }
          ];

          hardware.opentabletdriver = {
            enable = true;
            package = self.packages.${system}.default;
          };
        };
    };
}
