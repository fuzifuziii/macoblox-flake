{
  description = "MacOBlox git - Запуск macOS-клиента Roblox на Linux через Darling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # darling-nix.url = "github:nixie-dev/darling-nix"; # Раскомментируйте при использовании оверлея
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        # overlays = [ inputs.darling-nix.overlays.default ];
      };
      
      # Окружение Python с гарантированно установленным pygobject3 (модуль 'gi')
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
          makeWrapper       # Для ручного контроля над wrapProgram
          pythonEnv
          gobject-introspection
        ];

        buildInputs = with pkgs; [
          # darling # Раскомментируйте, когда добавите оверлей для darling
          clang
          lld
          unzip
          pipewire
          gtk4
          libadwaita
          webkitgtk_6_0
          gsettings-desktop-schemas
          # Полная цепочка зависимостей для typelib GTK4:
          gdk-pixbuf        # <-- Критически важно: предоставляет GdkPixbuf-2.0
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
          
          # Компиляция Python-файлов лаунчера
          ${pythonEnv}/bin/python -m compileall -q -d /share/macoblox/launcher "$share/launcher"

          mkdir -p "$out/bin"
          cp "$share/launcher/macoblox-launcher" "$out/bin/macoblox"

          runHook postInstall
        '';

        # Выполняем обертку строго после установки всех файлов
        postFixup = ''
          # 1. Заменяем shebang на наш pythonEnv
          patchShebangs "$out/bin/macoblox"
          
          # 2. Явно и прозрачно задаем ВСЕ необходимые переменные окружения
          wrapProgram "$out/bin/macoblox" \
            --prefix PATH : ${pkgs.lib.makeBinPath [
              pkgs.clang
              pkgs.lld
              pkgs.unzip
            ]} \
            --prefix PYTHONPATH : "$out/share/macoblox/launcher" \
            --prefix GI_TYPELIB_PATH : ${pkgs.lib.makeSearchPathOutput "lib" "lib/girepository-1.0" [
              pkgs.gobject-introspection
              pkgs.gdk-pixbuf
              pkgs.graphene
              pkgs.harfbuzz
              pkgs.pango
              pkgs.cairo
              pkgs.fribidi
              pkgs.gtk4
              pkgs.libadwaita
              pkgs.webkitgtk_6_0
            ]} \
            --prefix XDG_DATA_DIRS : "${pkgs.lib.makeSearchPath "share" [
              pkgs.gsettings-desktop-schemas
              pkgs.gtk4
              pkgs.libadwaita
            ]}:$out/share"
        '';

        meta = with pkgs.lib; {
          description = "Запуск macOS-клиента Roblox на Linux через Darling";
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
            enable = mkEnableOption "MacOBlox (запуск macOS Roblox через Darling)";
            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.default;
              description = "Пакет MacOBlox для использования.";
            };
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };
    };
}
