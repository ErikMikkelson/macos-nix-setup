#!/bin/bash

# We don't need return codes for "$(command)", only stdout is needed.
# Allow `[[ -n "$(command)" ]]`, `func "$(command)"`, pipes, etc.
# shellcheck disable=SC2312

set -u

chomp() {
  printf "%s" "${1/"$'\n'"/}"
}

RL_CHECKOUT=/opt/nixpkgs
RL_REPO=https://github.com/risclog-solution/macos-nix-setup.git
CHMOD=("/bin/chmod")
MKDIR=("/bin/mkdir" "-p")
STAT_PRINTF=("stat" "-f")
PERMISSION_FORMAT="%A"
CHOWN=("/usr/sbin/chown")
CHGRP=("/usr/bin/chgrp")
USER="$(chomp "$(id -un)")"
export USER
CONFIG="/Users/$USER/.config/rlnixpkgs"
GROUP="admin"
TOUCH=("/usr/bin/touch")

unset HAVE_SUDO_ACCESS # unset this from the environment

mkdir -p "/Users/$USER/.config"

have_sudo_access() {
  if [[ ! -x "/usr/bin/sudo" ]]
  then
    return 1
  fi

  local -a SUDO=("/usr/bin/sudo")
  if [[ -n "${SUDO_ASKPASS-}" ]]
  then
    SUDO+=("-A")
  elif [[ -n "${NONINTERACTIVE-}" ]]
  then
    SUDO+=("-n")
  fi

  if [[ -z "${HAVE_SUDO_ACCESS-}" ]]
  then
    if [[ -n "${NONINTERACTIVE-}" ]]
    then
      "${SUDO[@]}" -l mkdir &>/dev/null
    else
      "${SUDO[@]}" -v && "${SUDO[@]}" -l mkdir &>/dev/null
    fi
    HAVE_SUDO_ACCESS="$?"
  fi

  if [[ -z "${HOMEBREW_ON_LINUX-}" ]] && [[ "${HAVE_SUDO_ACCESS}" -ne 0 ]]
  then
    abort "Need sudo access on macOS (e.g. the user ${USER} needs to be an Administrator)!"
  fi

  return "${HAVE_SUDO_ACCESS}"
}

execute() {
  if ! "$@"
  then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
  fi
}

abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [ -z "${BASH_VERSION:-}" ]
then
  abort "Bash is required to interpret this script."
fi

# Check if script is run with force-interactive mode in CI
if [[ -n "${CI-}" && -n "${INTERACTIVE-}" ]]
then
  abort "Cannot run force-interactive mode in CI."
fi

# Check if both `INTERACTIVE` and `NONINTERACTIVE` are set
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -n "${INTERACTIVE-}" && -n "${NONINTERACTIVE-}" ]]
then
  abort 'Both `$INTERACTIVE` and `$NONINTERACTIVE` are set. Please unset at least one variable and try again.'
fi

# string formatters
if [[ -t 1 ]]
then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"
  do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

warn() {
  printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$1")"
}

getc() {
  local save_state
  save_state="$(/bin/stty -g)"
  /bin/stty raw -echo
  IFS='' read -r -n 1 -d '' "$@"
  /bin/stty "${save_state}"
}

execute_sudo() {
  local -a args=("$@")
  if have_sudo_access
  then
    if [[ -n "${SUDO_ASKPASS-}" ]]
    then
      args=("-A" "${args[@]}")
    fi
    ohai "/usr/bin/sudo" "${args[@]}"
    execute "/usr/bin/sudo" "${args[@]}"
  else
    ohai "${args[@]}"
    execute "${args[@]}"
  fi
}

should_install_command_line_tools() {
  ! [[ -e "/Library/Developer/CommandLineTools/usr/bin/git" ]]
}

if ! [[ -d "/Applications/iTerm.app/" ]]
then
    ohai "Install iTerm2"
    curl https://iterm2.com/downloads/stable/iTerm2-3_4_16.zip -o ~/Downloads/iTerm2.zip
    unzip ~/Downloads/iTerm2.zip -d /Applications/
fi

if should_install_command_line_tools && test -t 0
then
  ohai "Installing the Command Line Tools (expect a GUI popup):"
  execute_sudo "/usr/bin/xcode-select" "--install"
  echo "Press any key when the installation has completed."
  getc
  execute_sudo "/usr/bin/xcode-select" "--switch" "/Library/Developer/CommandLineTools"
fi

if [ -d "$RL_CHECKOUT" ]
then
    ohai "Checkout dir $RL_CHECKOUT already exists. Updating."
    cd $RL_CHECKOUT && git checkout -- . && git pull
else
  ohai "Checkout dir $RL_CHECKOUT does not exist. Creating."
  execute_sudo "${MKDIR[@]}" "${RL_CHECKOUT}"
  execute_sudo "${CHOWN[@]}" "-R" "${USER}:${GROUP}" "${RL_CHECKOUT}"
  ohai "Cloning repository ${RL_REPO} into ${RL_CHECKOUT}:"
  git clone ${RL_REPO} ${RL_CHECKOUT}
fi

cd $RL_CHECKOUT

mkdir -p "/Users/$USER/.config/zsh/config.d/"
cp "config/p10k.zsh" "/Users/$USER/.config/zsh/config.d/"

if [[ -e "$CONFIG" ]]
then
    ohai "Read state from disk"
    source "$CONFIG"
else
    USERFULLNAME=""
    USEREMAIL=""
    GPGPUBKEY=""
    USERREPOSPASSWORD=""
    USEONEPASSWORDAGENT=""
fi

ohai "Change config to current user $USER"
sed -i -- "s/USERNAME/$USER/" flake.nix
sed -i -- "s/USERNAME/$USER/" darwin-configuration.nix

if ! [[ -n $USERFULLNAME ]]
then
    ohai "Enter your name (Firstname Lastname):"
    read USERFULLNAME
fi
sed -i -- "s/USERFULLNAME/$USERFULLNAME/" home-manager/modules/git.nix
sed -i -- "s/USERFULLNAME/$USERFULLNAME/" home-manager/modules/hg.nix

if ! [[ -n $USEREMAIL ]]
then
    ohai "Enter your company email address:"
    read USEREMAIL
fi
sed -i -- "s/USEREMAIL/$USEREMAIL/" home-manager/modules/git.nix
sed -i -- "s/USEREMAIL/$USEREMAIL/" home-manager/modules/hg.nix

if ! [[ -n $GPGPUBKEY ]]
then
    ohai "Enter you gpg public key:"
    read GPGPUBKEY
fi
if ! [[ $GPGPUBKEY ]]
then
    sed -i -- "s/SIGNINGKEY//" home-manager/modules/git.nix;
else
    sed -i -- "s/SIGNINGKEY/$GPGPUBKEY/" home-manager/modules/git.nix;
fi

if ! [[ -n $USERREPOSPASSWORD ]]
then
    ohai "Enter your password for repos.risclog.de:"
    read USERREPOSPASSWORD
fi
sed -i -- "s/USERREPOSPASSWORD/$USERREPOSPASSWORD/" home-manager/modules/hg.nix

if ! [[ -n $USEONEPASSWORDAGENT ]]
then
    ohai "Use 1Password 8 SSH agent? (y/n)"
    read USEONEPASSWORDAGENT
fi
if [[ $USEONEPASSWORDAGENT =~ ^[Yy]$ ]]
then
    ONEPASSWORD_AGENT='identityAgent = "\"${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";'
    ONEPASSWORD_AGENT=$(printf '%s\n' "$ONEPASSWORD_AGENT" | sed -e 's/[\/&]/\\&/g')
    sed -i -- "s/1PASSWORD_SSH_AGENT_CONFIG/$ONEPASSWORD_AGENT/" home-manager/modules/ssh.nix
else
    sed -i -- "s/1PASSWORD_SSH_AGENT_CONFIG//" home-manager/modules/ssh.nix
fi

echo "USERFULLNAME=\"$USERFULLNAME\"" > $CONFIG
echo "USEREMAIL=\"$USEREMAIL\"" >> $CONFIG
echo "GPGPUBKEY=\"$GPGPUBKEY\"" >> $CONFIG
echo "USERREPOSPASSWORD=\"$USERREPOSPASSWORD\"" >> $CONFIG
echo "USEONEPASSWORDAGENT=\"$USEONEPASSWORDAGENT\"" >> $CONFIG

if ! [[ -x "$(command -v nix-env)" ]]
then
    ohai "Installing nix"
    sh <(curl -L https://nixos.org/nix/install)
    source ~/.zshrc
fi
if ! [[ -x "$(command -v nix-env)" ]]
then
    ohai "Please restart terminal to finish Nix installation"
    exit 1
fi

if ! [[ -x "$(command -v home-manager)" ]]
then
    ohai "Installing home manager"
    nix-env -iA nixpkgs.nixFlakes
    nix-channel --add https://github.com/nix-community/home-manager/archive/release-21.11.tar.gz home-manager
    nix-channel --update
    mkdir -p "/Users/$USER/.config/nix/"
    echo "experimental-features = nix-command flakes" > "/Users/$USER/.config/nix/nix.conf"
    nix-env -e nix-2.9.1
    NIX_PATH="/Users/$USER/.nix-defexpr/channels:nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixpkgs:/nix/var/nix/profiles/per-user/root/channels" nix-shell '<home-manager>' -A install
fi

if ! [[ -x "$(command -v darwin-rebuild)" ]]
then
    ohai "Installing darwin-rebuild"
    nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
    ./result/bin/darwin-installer
    source ~/.zshrc
fi
if ! [[ -x "$(command -v darwin-rebuild)" ]]
then
    ohai "Please restart terminal to finish nix-darwin installation"
    exit 1
fi

ohai "Switching to new system configuration"
have_sudo_access
home-manager switch --flake .#rlmbp2022

cp darwin-configuration.nix /Users/$USER/.nixpkgs/
darwin-rebuild switch

if ! [ -d "/etc/local/postgres/data" ]
then
    execute_sudo "${MKDIR[@]}" "/etc/local/postgres/data"
    execute_sudo "${CHOWN[@]}" "-R" "${USER}:${GROUP}" "/etc/local/postgres"
    initdb /etc/local/postgres/data
fi

if ! [ -d "/etc/local/redis" ]
then
    execute_sudo "${MKDIR[@]}" "/etc/local/redis/db"
    execute_sudo "${CHOWN[@]}" "-R" "${USER}:${GROUP}" "/etc/local/redis"
    cp config/redis.conf /etc/local/redis/
fi

if ! [ -d "/etc/local/nginx" ]
then
    execute_sudo "${MKDIR[@]}" "/etc/local/nginx/servers"
    execute_sudo "${MKDIR[@]}" "/etc/local/nginx/logs"
    execute_sudo "${CHOWN[@]}" "-R" "${USER}:${GROUP}" "/etc/local/nginx"
    cp config/nginx.conf /etc/local/nginx/
    cp config/mime.types /etc/local/nginx/
fi

ohai "Installation successfull. Please close this window now."
open -a iTerm .
