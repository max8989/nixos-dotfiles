{ config, lib, ... }:
let
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

  # Starship prompt. The complex Catppuccin-Mocha starship.toml (nerd-font
  # glyphs, palettes) is imported as-is via importTOML — pure (the file lives in
  # the flake) and lossless, which hand-transcribing the unicode glyphs is not.
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = lib.importTOML ./starship.toml;
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
  home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  home.sessionPath = [
    "${config.home.homeDirectory}/.npm-global/bin"
    # uv tool installs (agent-reach, etc.) land here.
    "${config.home.homeDirectory}/.local/bin"
  ];
}
