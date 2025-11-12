{
  description = "Core engine for building self-contained Nushell binaries (nushell-binary-engine).";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default"; # Used for iterating over supported architectures

    # Dev tools
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      flake = false;
    };

    # NOTE: The 'flake-parts' input has been removed to resolve the structural error.
  };

  outputs =
    {
      #self
      nixpkgs
    , systems
    , ...
    }@inputs:
    let
      supportedSystems = import systems;

      # The Core Engine Function (takes pkgs set, returns the builder function)
      mkEmbeddedScript =
        pkgs:
        { scriptName
        , scriptContent
        , extraBinaries ? { }
        ,
        }:
        pkgs.rustPlatform.buildRustPackage rec {
          pname = scriptName;
          version = "0.1.0";

          src = ./.;

          RUSTC_ENV = extraBinaries // {
            NU_SCRIPT_CONTENT = scriptContent;
          };

          RUSTFLAGS = [ "-C target-feature=+crt-static" ];
          cargoBuildFlags = [ "--release" ];
          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; [ openssl.dev ];

          meta = with pkgs.lib; {
            description = "A self-contained binary running an embedded Nushell script: ${scriptName}.";
            homepage = "https://example.com";
            license = licenses.mit;
          };
        };

    in

    nixpkgs.lib.genAttrs supportedSystems (
      system:
      let
        # 1. Initialize nixpkgs for the current system (This one correctly calls the function)
        pkgs = import nixpkgs { inherit system; };

        # 2. Define the system-specific builder function
        mkFinalEngineBinary = mkEmbeddedScript pkgs;

        # 3. Call external modules for development tools
        devshellOutputs = pkgs.callPackage ./nix/modules/devshell.nix {
          inherit inputs pkgs;
          buildEngineBinary = mkFinalEngineBinary;
        };
        preCommitHooks = pkgs.callPackage ./nix/modules/pre-commit.nix {
          inherit inputs pkgs;
        };

        # 4. Define the test package (used as the default package and app)
        defaultPackage = mkFinalEngineBinary {
          scriptName = "engine-test-binary";
          scriptContent = ''
            let result = 100 | math sqrt;
            print $"Engine Test Successful! Result of sqrt(100) is: ($result)";
          '';
        };

      in
      {
        # --- Standard Flake Outputs ---

        # The Library function for consumption by other flakes
        lib.mkEmbeddedScript = mkFinalEngineBinary;

        # Packages
        packages = {
          default = defaultPackage;
        };

        # Development Shells
        devShells = devshellOutputs;

        # Applications
        apps.default = {
          type = "app";
          program = "${defaultPackage}/bin/engine-test-binary";
        };

        # Git Hooks (The pre-commit output is included for completeness)
        pre-commit = preCommitHooks;
      }
    );
}
