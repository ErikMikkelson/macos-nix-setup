{ config, pkgs, lib, libs, ... }:
{
  programs.zsh = {
    enable = true;
    shellAliases = {
    };
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "macos" ];
      theme = "robbyrussell";
      extraConfig = ''
        export LANG=de_DE.UTF-8
        export PIP_REQUIRE_VIRTUALENV=1
        export PATH=${config.home.homeDirectory}/.local/bin:$PATH

        HISTORY_SUBSTRING_SEARCH_PREFIXED=1

        # Load seperated config files
        for conf in "$HOME/.config/zsh/config.d/"*.zsh; do
          source "''${conf}"
        done
        unset conf

        bindkey "$terminfo[kcuu1]" history-substring-search-up
        bindkey "$terminfo[kcud1]" history-substring-search-down
        bindkey '^[[A' history-substring-search-up

        export LDFLAGS="-L${config.home.homeDirectory}/.nix-profile/lib"
        export CFLAGS="-I${config.home.homeDirectory}/.nix-profile/include"
        export LD_LIBRARY_PATH="${config.home.homeDirectory}/.nix-profile/lib"
      '';
    };
    zplug = {
      enable = true;
      plugins = [
        { name = "zsh-users/zsh-autosuggestions"; }
        { name = "zsh-users/zsh-syntax-highlighting"; }
        { name = "zsh-users/zsh-history-substring-search"; }
        { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; }
      ];
    };
  };
}

