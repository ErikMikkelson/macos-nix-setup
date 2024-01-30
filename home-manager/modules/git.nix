{ config, pkgs, lib, libs, ... }:
{
  programs.git = {
    enable = true;
    userName = "USERFULLNAME";
    userEmail = "USEREMAIL";

    extraConfig = {
      pull.rebase = false;
      push.default = "current";
      push.autoSetupRemote = true;

      init.defaultBranch = "main";

      github.user = "${config.home.username}";

      core.editor = "mvim -f";
      core.fileMode = false;
      core.ignorecase = false;
      core.excludesfile = "~/.gitignore";


    };
  };
}
