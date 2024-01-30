{ config, pkgs, libs, ... }:
{

  # https://github.com/nix-community/nix-direnv#via-home-manager
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  home.packages = with pkgs; [
    mkcert
    binutils
    jdk11.out
    zsh
    oh-my-zsh
    zsh-powerlevel10k
    zsh-syntax-highlighting
    zsh-history-substring-search
    wget
    bat
    python39Packages.pipx

    yarn
  ];
}
