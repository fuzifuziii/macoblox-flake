{
  description = "MacOBlox git - Run the macOS Roblox client on Linux through Darling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    darling-nix = {
      url = "github:nixie-dev/darling-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, darling-nix, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      
      darling-pkg = darling-nix.packages.${system}.darling;

      pythonEnv = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "macoblox-git";
        version = "0.21patch1-r176.25595a4";

        src = pkgs.fetchFromGitHub {
          owner = "aubree-lat";
          repo = "MacOBlox";
          rev = "25595a49ed682a81b2ae2314327cf828ef8aff0a";
          hash = "sha256-HBFVCjtOmUW3ZBx6FGRO/99PK8wluvIlZFP7eE3sRgc="; 
        };

        nativeBuildInputs = with pkgs; [
          git
          makeWrapper
          pythonEnv
          gobject-introspection
        ];

        buildInputs = with pkgs; [
          darling-pkg
          clang
          lld
          unzip
          pipewire
          gtk4
          libadwaita
          webkitgtk_6_0
          gsettings-desktop-schemas
          gdk-pixbuf
          graphene
          harfbuzz
          pango
          cairo
          fribidi
        ];

        installPhase = ''
          runHook preInstall

          local share="$out/share/macoblox"
          mkdir -p "$share"
          cp -r --no-preserve=ownership launcher branding frameworks build_debug_shim.sh ./*.c ./*.m "$share/"
          rm -f "$share/launcher/install.sh"
          
          ${pythonEnv}/bin/python -m compileall -q -d /share/macoblox/launcher "$share/launcher"

          mkdir -p "$out/bin"
          cp "$share/launcher/macoblox-launcher" "$out/bin/macoblox"
          patchShebangs "$out/bin/macoblox"

          for size in 16 22 24 32 48 64 128 256 512; do
            mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
            cp "branding/icons/macoblox-$size.png" \
              "$out/share/icons/hicolor/''${size}x''${size}/apps/macoblox.png"
          done

          mkdir -p "$out/share/applications"
          cp packaging/wtf.aubree.MacOBlox.desktop "$out/share/applications/"
          cp packaging/wtf.aubree.MacOBlox.URI.desktop "$out/share/applications/"
          cp packaging/macoblox-roblox-window.desktop "$out/share/applications/"
          cp packaging/wtf.aubree.MacOBlox.Studio.desktop "$out/share/applications/"
          
          mkdir -p "$out/share/mime/packages"
          cp packaging/wtf.aubree.MacOBlox.xml "$out/share/mime/packages/"

          mkdir -p "$out/share/licenses/macoblox-git"
          cp LICENSE "$out/share/licenses/macoblox-git/"

          runHook postInstall
        '';

        postInstall = ''
          substituteInPlace "$out/share/applications/wtf.aubree.MacOBlox.desktop" \
            --replace-fail "Name=Mac O’ Blox" "Name=MacOBlox (Mac O' Blox)" \
            --replace-fail "Keywords=roblox;darling;" "Keywords=macoblox;roblox;darling;game;"
        '';

        postFixup = ''
          wrapProgram "$out/bin/macoblox" \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.clang pkgs.lld pkgs.unzip darling-pkg ]} \
            --prefix PYTHONPATH : "$out/share/macoblox/launcher" \
            --prefix GI_TYPELIB_PATH : ${pkgs.lib.makeSearchPathOutput "lib" "lib/girepository-1.0" [
              pkgs.gobject-introspection pkgs.gdk-pixbuf pkgs.graphene pkgs.harfbuzz
              pkgs.pango pkgs.cairo pkgs.fribidi pkgs.gtk4 pkgs.libadwaita pkgs.webkitgtk_6_0
            ]} \
            --prefix XDG_DATA_DIRS : "${pkgs.lib.makeSearchPath "share" [
              pkgs.gsettings-desktop-schemas pkgs.gtk4 pkgs.libadwaita
            ]}:$out/share"
        '';

        meta = with pkgs.lib; {
          description = "Run the macOS Roblox client on Linux through Darling";
          homepage = "https://github.com/aubree-lat/MacOBlox";
          license = licenses.mit;
          platforms = platforms.linux;
        };
      };

      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.macoblox;
        in {
          options.programs.macoblox = {
            enable = mkEnableOption "MacOBlox (run macOS Roblox through Darling)";
            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.default;
              description = "The MacOBlox package to use.";
            };
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };
    };
}
