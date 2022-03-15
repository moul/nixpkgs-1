{
  description = "gfanton dotfiles";

  inputs = {
    # channel
    nixpkgs = { url = "github:nixos/nixpkgs/master"; };
    nixpkgs-master = { url = "github:nixos/nixpkgs/master"; };
    nixpkgs-stable-darwin = { url = "github:nixos/nixpkgs/nixpkgs-20.09-darwin"; };
    nixos-stable = { url = "github:nixos/nixpkgs/nixos-20.09"; };

    # flake
    flake-utils = { url = "github:numtide/flake-utils"; };
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };

    darwin = { url = "github:LnL7/nix-darwin"; inputs.nixpkgs.follows = "nixpkgs"; };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    android-nixpkgs = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:tadfisher/android-nixpkgs";
    };

    # emacs
    spacemacs = { url = "github:syl20bnr/spacemacs/develop"; flake = false; };
    emacs-overlay =  { url = "github:nix-community/emacs-overlay"; };

    # zsh_plugins
    fast-syntax-highlighting = { url = "github:zdharma-continuum/fast-syntax-highlighting"; flake = false; };
    fzf-tab = { url = "github:Aloxaf/fzf-tab"; flake = false; };
    powerlevel10k = { url = "github:romkatv/powerlevel10k"; flake = false; };
  };

  outputs = { self, nixpkgs, darwin, home-manager, flake-utils, emacs-overlay, android-nixpkgs, ... }@inputs:
    let
      defaultSystems = flake-utils.lib.defaultSystems;
      nixpkgsConfig = { system }: with inputs; {
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
        overlays = self.overlays ++ [
          (
            final: prev:
            let
              x86system = if system == "aarch64-darwin" then "x86_64-darwin" else system;
              nixpkgs-stable = if system == "x86_64-darwin" then nixpkgs-stable-darwin else nixos-stable;
            in
              {
                stable = nixpkgs-stable.legacyPackages.${x86system};
                master = nixpkgs-master.legacyPackages.${system};
                silicon = nixpkgs.legacyPackages.${system};
              }
          )
        ];
      };

      homeManagerConfig = with self.homeManagerModules; {
          imports = [
            ./home
            misc.truecolor
            programs.mykitty
            programs.kitty.extras
            programs.zsh.antibody
            android-nixpkgs.hmModule
          ];
      };

      linuxCommonConfig = with self.homeManagerModules; {
        imports = [
          ./home
          misc.truecolor
          programs.mykitty
          programs.kitty.extras
          programs.zsh.antibody
          android-nixpkgs.hmModule
          ./linux
        ];
      };

      nixDarwinCommonModules = { system, user }: [
        # Include extra `nix-darwin`
        self.darwinModules.services.emacsd
        self.darwinModules.security.pam
        # Main `nix-darwin` config
        ./darwin
        # `home-manager` module
        home-manager.darwinModules.home-manager
        {
          nixpkgs = nixpkgsConfig { system = system; };
          # Hack to support legacy worklows that use `<nixpkgs>` etc.
          nix.nixPath = { nixpkgs = "$HOME/nixpkgs/nixpkgs.nix"; };
          # `home-manager` config
          users.users.${user}.home = "/Users/${user}";
          home-manager.useGlobalPkgs = true;
          home-manager.users.${user} = homeManagerConfig;
        }
      ];

    in
    {
      darwinConfigurations = {
        # Minimal configuration to bootstrap systems
        bootstrap = darwin.lib.darwinSystem {
          modules = [ ./darwin/bootstrap.nix {
            nixpkgs = nixpkgsConfig { system = "x86_64-darwin"; };
          } ];
        };

        macbook = darwin.lib.darwinSystem {
          modules = nixDarwinCommonModules { system = "aarch64-darwin"; user = "gfanton"; } ++ [
            {
              networking.computerName = "guicp";
              networking.hostName = "ghost";
              networking.knownNetworkServices = [
                "Wi-Fi"
                "USB 10/100/1000 LAN"
              ];
            }
          ];
        };

        bot = darwin.lib.darwinSystem {
          modules = nixDarwinCommonModules { system = "x86_64-darwin"; user = "gfantonbot"; } ++ [
            {
              networking.computerName = "guibot";
              networking.hostName = "gbot";
              networking.knownNetworkServices = [
                "Wi-Fi"
                "USB 10/100/1000 LAN"
              ];
            }
          ];
        };
      };

      cloud = home-manager.lib.homeManagerConfiguration {
	      system = "x86_64-linux";
	      homeDirectory = "/home/gfanton";
	      username = "gfanton";
	      configuration = {
	        imports = [ linuxCommonConfig ];
	        nixpkgs = nixpkgsConfig { system = "x86_64-linux"; };
	      };
       };

      darwinModules = {
        security.pam = import ./darwin/modules/security/pam.nix;
        services.emacsd = import ./darwin/modules/services/emacsd.nix;
      };

      homeManagerModules = {
        misc.truecolor = import ./home/modules/misc/truecolor.nix;
        programs.kitty.extras = import ./home/modules/programs/kitty/extras.nix;
        programs.mykitty = import ./home/modules/programs/kitty;
        programs.zsh.antibody = import ./home/modules/programs/antibody.nix;
      };

      overlays = with inputs; [
        (android-nixpkgs.overlay)
        (
          final: prev: {
            # pkgs
            spacemacs = inputs.spacemacs;
            emacs = final.silicon.emacs;
            emacsGcc = (import emacs-overlay final prev).emacsGcc;
            zsh = final.silicon.zsh;
            kitty = final.silicon.kitty.overrideDerivation (oldAttrs: {
              CFLAGS = if prev.stdenv.isDarwin
                       then "-Wno-deprecated-declarations -arch arm64 -target arm64-apple-macos11"
                       else "";
            });

            # inputs
            android-sdk = (import android-nixpkgs) { inherit pkgs; };

            # stable release (usually package here are broken upstream)
            cachix = final.stable.cachix;

            # zsh plugins
            zsh-plugins.fast-syntax-highlighting = inputs.fast-syntax-highlighting;
            zsh-plugins.fzf-tab = inputs.fzf-tab;
            zsh-plugins.powerlevel10k = inputs.powerlevel10k;
          }
        )
        # Other overlays that don't depend on flake inputs.
      ] ++ map import ((import ./lsnix.nix) ./overlays);
    } // flake-utils.lib.eachSystem defaultSystems (system: {
      legacyPackages = import nixpkgs {
        inherit system;
        inherit (nixpkgsConfig { system = system; }) config overlays;
      };
    });
}
