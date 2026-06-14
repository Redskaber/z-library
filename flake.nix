{
  description = "Z-Library desktop client packaged from upstream .deb";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      
      allowUnfree = system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    {
      packages = forAllSystems (system:
        let pkgs = allowUnfree system;
        in {
          default = pkgs.callPackage ./package.nix { };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/z-library";
        };
      });

      devShells = forAllSystems (system:
        let pkgs = allowUnfree system;
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [ dpkg nix-prefetch-url curl jq ];
          };
        });
    };
}
