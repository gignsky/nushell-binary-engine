{ pkgs
, # , inputs
  mkEmbeddedScript
, ...
}:
{
  default = pkgs.mkShell {
    name = "nushell-binary-engine-shell";

    # Pre-commit hooks are integrated via the git-hooks package
    # We rely on pre-commit.nix to set up the hooks, which will be available in the environment.

    packages = with pkgs; [
      # nix stuff
      nixd
      nixfmt-rfc-style
      wslu

      # rust stuff
      rustfmt
      clippy
      bacon
      # inputs.cargo-doc-live.packages.${pkgs.system}.default

      # utilities
      gitflow
      cowsay
      lolcat

      # Example: Including the default package in the shell
      mkEmbeddedScript
      {
        scriptName = "engine-test-binary";
        scriptContent = ''
          print "Shell is active."
        '';
      }
    ];

    shellHook = ''
      echo "welcome to the rust development environment for the nushell-binary-engine package" | ${pkgs.cowsay}/bin/cowsay | ${pkgs.lolcat}/bin/lolcat 2> /dev/null;
    '';
  };
}
