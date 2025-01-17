UNAME := $(shell uname)

# Channels
NIX_CHANNELS := nixpkgs nixos-stable nixpkgs-stable-darwin
HOME_CHANNELS := home-manager darwin
EMACS_CHANNELS := emacs-overlay
SPACEMACS_CHANNELS := spacemacs
ZSH_CHANNELS := fast-syntax-highlighting fzf-tab powerlevel10k
MISC_CHANNELS := android-nixpkgs flake-utils flake-compat


ifeq ($(UNAME), Darwin) # darwin rules
all:
	@echo "switch.osx_bootstrap"
	@echo "switch.macbook"
	@echo "switch.bot"

switch.bootstrap: result/sw/bin/darwin-rebuild
	./result/sw/bin/darwin-rebuild switch  --verbose --flake .#bootstrap
switch.macbook: result/sw/bin/darwin-rebuild
	./result/sw/bin/darwin-rebuild switch --verbose --flake .#macbook
switch.bot: result/sw/bin/darwin-rebuild
	./result/sw/bin/darwin-rebuild switch --verbose --flake .#bot

result/sw/bin/darwin-rebuild:
	NIXPKGS_ALLOW_UNFREE=1 nix build .#darwinConfigurations.bootstrap.system

endif # end osx


ifeq ($(UNAME), Linux) # linux rules

all:
	@echo "switch.cloud"

switch.cloud:
	nix build .#cloud.activationPackage
	./result/activate switch --verbose --flake .#bot

endif # end linux

clean:
	./result/sw/bin/nix-collect-garbage

fclean:
	@echo "/!\ require to be root"
	sudo ./result/sw/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations old
	./result/sw/bin/nix-collect-garbage -d
# Remove entries from /boot/loader/entries:
	sudo bash -c "cd /boot/loader/entries; ls | grep -v <current-generation-name> | xargs rm"


fast-update: update.nix update.zsh update.misc # fast update ignore emacs update
update: update.nix update.emacs update.spacemacs update.zsh update.misc
update.nix:; nix flake lock $(addprefix --update-input , $(NIX_CHANNELS))
update.emacs:; nix flake lock $(addprefix --update-input , $(EMACS_CHANNELS))
update.spacemacs:; nix flake lock $(addprefix --update-input , $(SPACEMACS_CHANNELS))
update.zsh:; nix flake lock $(addprefix --update-input ,$(ZSH_CHANNELS))
update.misc:; nix flake lock $(addprefix --update-input ,$(MISC_CHANNELS))
update.home:; nix flake lock $(addprefix --update-input , $(NIX_CHANNELS))

