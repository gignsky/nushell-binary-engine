{ inputs
, pkgs
, system
, ...
}:
let
  inherit system;
  preCommitHooks = inputs.git-hooks.lib.${system}.mkHooks {
    inherit pkgs;
    settings = {
      hooks = {
        # Nix formatting and linting
        nixpkgs-fmt.enable = true;
        statix.enable = true;
        deadnix = {
          enable = true;
          excludes = [ "nix/modules/template.nix" ];
        };

        # Rust formatting and linting
        rustfmt.enable = true;

        # File cleanup
        end-of-file-fixer.enable = true;
      };
    };
  };
in
preCommitHooks
