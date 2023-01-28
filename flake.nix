{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, fenix, flake-utils, naersk, nixpkgs }:
    (flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        deps = with pkgs; [
          xorg.libX11
          xorg.libXinerama
          xorg.xmodmap
        ];

        devToolchain = fenix.packages.${system}.stable;

        harness = ((naersk.lib.${system}.override {
          inherit (fenix.packages.${system}.minimal) cargo rustc;
        }).buildPackage {
          name = "harness";
          src = ./.;
          buildInputs = deps;
          postFixup = ''
            patchelf --set-rpath "${pkgs.lib.makeLibraryPath deps}" $out/bin/harness
          '';

          GIT_HASH = self.shortRev or "dirty";
        });
      in
      rec {
        # `nix build`
        packages = {
          inherit harness;
          default = harness;
        };

        # `nix run`
        apps = {
          harness = flake-utils.lib.mkApp {
            drv = packages.harness;
          };
          default = apps.harness;
        };

        # `nix develop`
        devShells.default = pkgs.mkShell
          {
            buildInputs = deps ++ [ pkgs.pkg-config pkgs.systemd pkgs.glib pkgs.cairo pkgs.pango pkgs.libinput];
            nativeBuildInputs = with pkgs; [
              gnumake
              (devToolchain.withComponents [
                "cargo"
                "clippy"
                "rust-src"
                "rustc"
                "rustfmt"
              ])
              fenix.packages.${system}.rust-analyzer
            ];
          };
      })) // {
      overlay = final: prev: {
        harness = self.packages.${final.system}.harness;
      };
    };
}
