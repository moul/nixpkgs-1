{ config, pkgs, lib, ... }:

let
  home_dir = "${config.home.homeDirectory}";
  profile_dir = "${config.home.profileDirectory}";
  spacemacsd = "${lib.cleanSource ../config/spacemacs}";
  btopd = "${lib.cleanSource ../config/btop}";
in
{
  # Import config broken out into files
  imports = [
    ./kitty.nix
    ./shells.nix
  ];

  xdg = {
    enable = true;
    configHome = "${home_dir}/.config";
    cacheHome = "${home_dir}/.cache";
    dataHome = "${home_dir}/.local/share";
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Some basics
    mosh # wrapper for `ssh` that better and not dropping connections
    unrar # extract RAR archives
    exa # fancy version of `ls`
    # stable.bandwhich # display current network utilization by process

    # pkgs silicon
    silicon.btop # fancy version of `top`
    silicon.tmate # instant terminal sharing
    silicon.fd # fancy version of `find`
    silicon.most
    silicon.parallel # runs commands in parallel
    silicon.socat
    silicon.less
    silicon.tree # list contents of directories in a tree-like format.
    silicon.coreutils
    silicon.jq
    silicon.ripgrep # better version of grep
    silicon.curl # transfer a URL
    silicon.wget # The non-interactive network downloader.

    # stable
    stable.procs # fancy version of `ps`

    # aspell
    silicon.aspell # interactive spell checker
    silicon.aspellDicts.fr
    silicon.aspellDicts.en
    silicon.aspellDicts.en-computers
    silicon.aspellDicts.en-science

    # antibody
    silicon.antibody

    # rustc
    silicon.rustc
    silicon.cargo

    # ruby
    (silicon.ruby_2_7.withPackages (ps: [
      ps.ffi-compiler
    ]))

    # js
    silicon.nodejs-16_x
    silicon.yarn

    # python
    (silicon.python39.withPackages (p: with p; [
      virtualenv
      pip
      mypy
      pylint
      yapf
      setuptools
    ]))
    silicon.pipenv

    # go
    # (silicon.go_1_17.overrideDerivation (oldAttrs: {
    #   buildInputs = oldAttrs.buildInputs ++ [ makeWrapper ];
    #   postConfigure = oldAttrs.postConfigure + "export GOROOT_FINAL=$out/share/go17";
    #   postInstall = ''
    #     export GOPATH=${home_dir}/.local/share/go/17
    #     export GOBIN=${home_dir}/.local/bin
    #     wrapProgram $out/bin/go \ --set GOPATH $GOPATH --set GOBIN $GOBIN
    #     # for file in $(ls $out/bin); do mv $out/bin/$file $out/bin/''${file}18; done
    #   '';
    # }))

    # preview go version
    (silicon.go_1_18.overrideDerivation (oldAttrs: {
      buildInputs = oldAttrs.buildInputs ++ [ makeWrapper ];
      postConfigure = oldAttrs.postConfigure + "export GOROOT_FINAL=$out/share/go18";
      postInstall = ''
        export GOPATH=${home_dir}/.local/share/go/18
        export GOBIN=${home_dir}/.local/bin
        wrapProgram $out/bin/go \
                     --set GOPATH $GOPATH \
                     --set GOBIN $GOBIN
        for file in $(ls $out/bin); do mv $out/bin/$file $out/bin/''${file}18; done
      '';
    }))

    # go tools
    silicon.gofumpt
    silicon.gopls # see overlay
    silicon.delve
    stable.golangci-lint
    # exclude bundle
    (silicon.gotools.overrideDerivation (oldAttrs: {
      excludedPackages = oldAttrs.excludedPackages ++ ["bundle"];
    }))

    # Useful nix related tools
    cachix # adding/managing alternative binary caches hosted by Cachix
    lorri # improve `nix-shell` experience in combination with `direnv`
    niv # easy dependency management for nix projects
    nix-prefetch
    nix-prefetch-git

    # Platform specific tools
  ] ++ lib.optionals stdenv.isDarwin [
    silicon.libffi
    silicon.libffi.dev
    silicon.cocoapods
  ] ++ lib.optionals stdenv.isLinux [
    docker
    docker-compose
  ];

  # Go Env
  programs.go = {
    enable = true;
    goPath = ".local/share/go/17";
    goBin = ".local/bin";
    package = pkgs.silicon.go_1_17;
  };

  # Additional Path
  home.sessionPath = [
    # local bin folder
    "${home_dir}/.local/bin"
    # npm bin folder
    "${config.xdg.dataHome}/node_modules/bin"
  ];

  # Additional env
  home.sessionVariables = {
    LC_ALL = "en_US.UTF-8";

    EDITOR = "${pkgs.emacsGcc}/bin/emacsclient -nw";

    # path
    PKG_CONFIG_PATH = "${profile_dir}/lib/pkgconfig";
    TERMINFO_DIRS = "${profile_dir}/share/terminfo";

    # flags
    CFLAGS="-I${profile_dir}/include";
    CPPFLAGS="-I${profile_dir}/include";
  };

  # lang
  home.language.base = "en_US.UTF-8";

  # manual
  manual.manpages.enable = true;

  programs.truecolor = {
    enable = true;
    useterm = "xterm-kitty";
    terminfo = "${pkgs.kitty.terminfo}/share/terminfo";
  };

  # Bat, a substitute for cat.
  # https://github.com/sharkdp/bat
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.bat.enable
  programs.bat = {
    enable = true;
    config = {
      style = "plain";
    };
  };

  # Direnv, load and unload environment variables depending on the current directory.
  # https://direnv.net
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.direnv.enable
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Zoxide, a faster way to navigate the filesystem
  # https://github.com/ajeetdsouza/zoxide
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.zoxide.enable
  programs.zoxide.enable = true;

  # emacs
  home.file.".emacs.d" = {
   source = pkgs.spacemacs;
   recursive = true;
  };

  home.file.".spacemacs.d" = {
   source = spacemacsd;
   recursive = true;
  };

  home.file."/.config/btop" = {
   source = btopd;
   recursive = true;
  };

  home.file.".npmrc" = with pkgs; {
    source = writeText "npmrc" ''
    prefix=${config.xdg.dataHome}/node_modules
    '';
  };

  programs.emacs = {
    enable = true;
    # package = pkgs.silicon.emacs;
    package = pkgs.emacsGcc;
  };

  # ssh
  programs.ssh = {
    enable = true;
    controlMaster = "auto";
    controlPath = "${config.xdg.cacheHome}/ssh-%u-%r@%h:%p";
    controlPersist = "1800";
    forwardAgent = true;
    serverAliveInterval = 60;
    hashKnownHosts = true;
  };

  # programs.gpg = {
  #   homedir = "${config.xdg.dataHome}/gnupg";
  #   enable = true;
  # };

  # link aspell config
  home.file.".aspell.config" = with pkgs; {
    source = writeText "aspell.conf" ''
    master en_US
    extra-dicts en-computers.rws en-science.rws fr.rws
    '';
  };

  # Git
  # https://rycee.gitlab.io/home-manager/options.html#opt-programs.git.enable
  # Aliases config imported in flake.
  programs.git ={
    enable = true;
    userEmail = "8671905+gfanton@users.noreply.github.com";
    userName = "gfanton";
    aliases = {
      d = "diff";
      lg = "log --graph --abbrev-commit --decorate --format=format:'%C(blue)%h%C(reset) - %C(green)(%ar)%C(reset) %s %C(italic)- %an%C(reset)%C(magenta bold)%d%C(reset)' --all";
      co = "checkout";
    };
    package = pkgs.buildEnv {
      name = "myGitEnv";
      paths = with pkgs.silicon.gitAndTools; [git gh tig];
    };
    delta.enable = true;
    lfs.enable = true;
    ignores = [
      "*~"
      "*.swp"
      "*#"
      ".#*"
      ".DS_Store"
    ];
    extraConfig = {
      github.user = "gfanton";
      core = {
        whitespace = "trailing-space,space-before-tab";
        editor = "em";
      };
      pull.rebase = true;
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };

  # This value determines the Home Manager release that your configuration is compatible with. This
  # helps avoid breakage when a new Home Manager release introduces backwards incompatible changes.
  #
  # You can update Home Manager without changing this value. See the Home Manager release notes for
  # a list of state version changes in each release.
  home.stateVersion = "20.09";
}
