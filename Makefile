DEFAULT_GOAL: update

.PHONY: update
update:
# unfortunately, NixGL with nvidia drivers requires an impure build
	home-manager switch --impure --flake .

.PHONY: clean
clean:
	nix-collect-garbage -d
