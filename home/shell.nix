{
  config,
  lib,
  desktop ? false,
  ...
}:
let
  palette = import (if desktop then ./omarchy-palette.nix else ./palette.nix);
  # Shared by bash and zsh — the set from the Arch ~/.zshrc.
  shellAliases = {
    # eza-based listings
    ls = "eza --group-directories-first --icons";
    ll = "eza -lh --group-directories-first --icons";
    la = "eza -lah --group-directories-first --icons";
    lt = "eza --tree --icons";
    lla = "ls -lha";
    l = "ls -CF"; # see NOTE below
    cat = "bat --paging=never";

    grep = "grep --color=auto";

    # Finding things (see the Super+/ cheat sheet)
    ff = "fd"; # files and folders by name, recursive
    fd1 = "fd -d 1"; # same, current directory only
    fdd = "fd -t d"; # folders only
    ft = "rg"; # text inside files, recursive
    ft1 = "rg --max-depth 1"; # same, current directory only
    fz = "fd | fzf"; # pick a file interactively
    df = "df -h";
    du = "du -h -c";
    free = "free -h";

    c = "clear";
    q = "exit";
    ".." = "cd ..";
    "..." = "cd ../..";
    neofetch = "fastfetch";

    n = "nvim .";
    note = "cd ~/Documents/obsidian && nvim .";
    audio-notes = "${config.home.homeDirectory}/repos/audio-notes/audio-notes";
    an = "${config.home.homeDirectory}/repos/audio-notes/audio-notes";

    pwdc = "pwd | wl-copy";
    cdo = ''pwd | xargs -I{} echo "cd {} && opencode" | wl-copy'';
    cdc = ''pwd | xargs -I{} echo "cd {} && claude" | wl-copy'';
    cdd = ''pwd | xargs -I{} echo "cd {}" | wl-copy'';
  };
in
{
  ##########################################################################
  ## zsh — the login shell (registered + selected in hosts/common.nix).
  ##
  ## Ported from the Arch ~/.zshrc, which was deliberately framework-free (no
  ## oh-my-zsh / zinit): it sourced two plugins by hand from /usr/share. Those
  ## paths don't exist on NixOS, so the equivalent Home Manager options are
  ## used instead — HM sources zsh-syntax-highlighting last, which is the load
  ## order that plugin requires.
  ##
  ## Not carried over from the Arch .zshrc, on purpose:
  ##   - `. "$HOME/.local/bin/env"`      — rustup/uv shim; those come from
  ##                                        home.packages here.
  ##
  ## The Arch `export PATH=$HOME/.npm-global` IS carried over — see the npm
  ## section at the bottom of this file for why it is still needed here.
  ##########################################################################
  programs.zsh = {
    enable = true;
    enableCompletion = true; # replaces the manual `autoload -Uz compinit`
    autocd = true; # setopt AUTO_CD — bare `dir` means `cd dir`
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreAllDups = true; # HIST_IGNORE_ALL_DUPS
      ignoreSpace = true; # HIST_IGNORE_SPACE
      share = true; # SHARE_HISTORY
      append = true; # INC_APPEND_HISTORY
      # path defaults to $HOME/.zsh_history, same as the Arch config.
    };

    initContent = ''
      # Completion behaviour from the Arch .zshrc.
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive

      # fif — live text search in files: type to re-run ripgrep, Enter opens
      # the match in nvim at that line. A function because it needs arguments.
      fif() {
        local rg='rg --column --line-number --no-heading --color=always --smart-case'
        fzf --ansi --disabled --query "$1" --delimiter : \
          --bind "start:reload:$rg {q} || true" \
          --bind "change:reload:sleep 0.1; $rg {q} || true" \
          --preview 'bat --color=always {1} --highlight-line {2}' \
          --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
          --bind 'enter:become(nvim {1} +{2})'
      }

      # Machine-local overrides / secrets. Untracked and optional, so the
      # guard keeps a fresh machine working before the file exists.
      [ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
    '';
  };

  # Ctrl-R / Ctrl-T / Alt-C and **<Tab> completion. Replaces sourcing
  # /usr/share/fzf/{key-bindings,completion}.zsh by hand.
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    # Ctrl-T and fzf's default list come from fd (fast, skips .git).
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    colors =
      if desktop then
        { }
      else
        {
          "bg" = palette.background;
          "bg+" = palette.surface;
          "fg" = palette.muted;
          "fg+" = palette.text;
          "hl" = palette.accent;
          "hl+" = palette.accent;
          "border" = palette.border;
          "prompt" = palette.accent;
          "pointer" = palette.accent;
          "marker" = palette.green;
          "spinner" = palette.teal;
          "info" = palette.muted;
        };
  };

  # `z`/`zi` frecency jumping — replaces `eval "$(zoxide init zsh)"`.
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # bash stays enabled: it is not the login shell, but plenty of scripts and
  # `bash -lc` invocations still expect a configured bash.
  programs.bash.enable = true;

  # One alias set for both shells, matching the Arch ~/.zshrc.
  #
  # NOTE: `l` is inherited verbatim from the Arch config, where `ls` is an eza
  # alias — shells re-expand the first word, so `l` becomes `eza … -CF` and
  # eza has no `-C`. It was equally broken on Arch; kept for parity rather
  # than silently changed. Use `ll`/`la` instead, or redefine `l` here.
  programs.bash.shellAliases = shellAliases;
  programs.zsh.shellAliases = shellAliases;

  # Desktop prompts read the selected theme through the standard config path.
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = lib.mkIf (!desktop) (
      (lib.importTOML ./starship.toml)
      // {
        palette = "jade";
        palettes.jade = {
          s1 = palette.base;
          s2 = palette.surface;
          text = palette.text;
          muted = palette.muted;
          dim = palette.dim;
          cyan = palette.accent;
          blue = palette.blue;
          green = palette.green;
          red = palette.urgent;
          amber = palette.warning;
        };
      }
    );
  };

  # Existing shells can retain STARSHIP_CONFIG pointing here after a rebuild.
  # Follow the state link so their next prompt uses the current palette too.
  xdg.configFile."starship.toml" = lib.mkIf desktop {
    source = config.lib.file.mkOutOfStoreSymlink "${config.localTheme.currentDir}/starship.toml";
  };

  ##########################################################################
  ## npm global prefix.
  ##
  ## nixpkgs' npm defaults its prefix to its own store path, which is
  ## read-only — so `npm install -g <pkg>` dies with EACCES. The declarative
  ## package list stays the source of truth for anything nixpkgs carries, but
  ## a few tools have no nixpkgs package at all (OpenCLI, @jackwener/opencli,
  ## pulled in by ~/repos/claude-config/install.sh). Give npm a writable
  ## prefix and put its bin dir on PATH so those installs work.
  ##########################################################################
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  }
  // lib.optionalAttrs desktop {
    FZF_DEFAULT_OPTS_FILE = "${config.localTheme.currentDir}/fzf-options";
  };
  home.sessionPath = [
    "${config.home.homeDirectory}/.npm-global/bin"
    # uv tool installs (agent-reach, etc.) land here.
    "${config.home.homeDirectory}/.local/bin"
  ];
}
