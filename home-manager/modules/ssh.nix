{ config, pkgs, lib, libs, ... }:
{
  programs.ssh = {
    enable = true;

    matchBlocks = {
        "*" = {
            forwardAgent = true;
            serverAliveInterval = 15;
            serverAliveCountMax = 3;
            extraOptions = {
              identityAgent = "\"${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
              strictHostKeyChecking = "no";
            };
        };
        "flyingcircus-jump-host" = {
            hostname = "clxstagc00.fe.rzob.fcio.net";
            user = "${config.home.username}";
        };
        "*.fcio.net" = {
            proxyJump = "flyingcircus-jump-host";
        };
        "*.gocept.net" = {
            proxyJump = "flyingcircus-jump-host";
        };
        "kravag* clx* claimx* risclog*" = {
            proxyJump = "flyingcircus-jump-host";
        };
    };
  };
}

