{ config, pkgs, ... }:
let
  # Osaka Jade uses this exact extension in Omarchy. It is not in nixpkgs.
  oceanGreen = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      publisher = "jovejonovski";
      name = "ocean-green";
      version = "1.1.2";
      hash = "sha256-sUNjnzqXya23Uieg8RLcEfnxiX0ImZ6CIjFtSJ66vM4=";
    };
    meta.license = pkgs.lib.licenses.mit;
  };
  flexokiLight = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      publisher = "shadesOfBuntu";
      name = "flexoki-light";
      version = "1.0.0";
      hash = "sha256-//y9uvIUGGDEhd8inDHvNy2e1IKNx6hSfO9sxNOTcUE=";
    };
    # The upstream VSIX does not declare a license.
    meta.license = pkgs.lib.licenses.unfree;
  };
  whiteManifest = pkgs.writeText "omarchy-white-package.json" (
    builtins.toJSON {
      name = "omarchy-white";
      displayName = "Omarchy White";
      description = "Omarchy's White palette rendered with its editor template";
      publisher = "local";
      version = "1.0.0";
      license = "MIT";
      engines.vscode = "^1.70.0";
      categories = [ "Themes" ];
      contributes.themes = [
        {
          label = config.localTheme.palettes.white.vscodeTheme;
          uiTheme = "vs";
          path = "./themes/white.json";
        }
      ];
    }
  );
  # White has no upstream vscode.json; Omarchy uses its generated theme.
  whiteVscode = pkgs.vscode-utils.buildVscodeExtension {
    pname = "local-omarchy-white";
    version = "1.0.0";
    vscodeExtPublisher = "local";
    vscodeExtName = "omarchy-white";
    vscodeExtUniqueId = "local.omarchy-white";
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/$installPrefix/themes"
      cp ${whiteManifest} "$out/$installPrefix/package.json"
      cp ${config.localTheme.themeDirs.white}/vscode-theme.json "$out/$installPrefix/themes/white.json"
      cp ${./files/omarchy/LICENSE} "$out/$installPrefix/LICENSE"
      runHook postInstall
    '';
    meta.license = pkgs.lib.licenses.mit;
  };
in
{
  # Desktop-only: the server imports shell.nix but not this module.
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "active";
      theme_background = false;
      truecolor = true;
      rounded_corners = true;
    };
    themes.active = config.lib.file.mkOutOfStoreSymlink "${config.localTheme.currentDir}/btop.theme";
  };

  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = [
        pkgs.vscode-extensions.enkia.tokyo-night
        pkgs.vscode-extensions.catppuccin.catppuccin-vsc
        pkgs.vscode-extensions.jdinhlife.gruvbox
        pkgs.vscode-extensions.arcticicestudio.nord-visual-studio-code
        oceanGreen
        flexokiLight
        whiteVscode
      ];
    };
  };

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.localTheme.currentDir}/vscode-settings.json";
}
