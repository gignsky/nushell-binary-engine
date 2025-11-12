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
    { self
    , nixpkgs
    , systems
    , ...
    }@inputs:
    let
      lib = nixpkgs.lib; # Define lib here for use in transposition
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
          # FIX: Replacing cargoSha256 with cargoHash. This older attribute is often
          # more stable when dealing with complex internal dependency logic.
          # Nix will instruct you to use the correct hash for the project's dependencies.
          cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

          # FIX: RUSTC_ENV must be a single string, not an attribute set.
          # We serialize the attributes into "KEY=VALUE" pairs separated by spaces.
          RUSTC_ENV = lib.concatStringsSep " " (
            lib.mapAttrsToList (name: value: ''${name}="${value}"'') (
              extraBinaries // { NU_SCRIPT_CONTENT = scriptContent; }
            )
          );

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

    (
      let
        # 1. Generate the raw, system-indexed outputs
        perSystemOutputs = lib.genAttrs supportedSystems (
          system:
          let
            # 1. Initialize nixpkgs for the current system
            pkgs = import nixpkgs { inherit system; };

            # 2. Define the system-specific builder function
            mkFinalEngineBinary = mkEmbeddedScript pkgs;

            # 3. Call external modules for development tools
            devshellOutputs = pkgs.callPackage ./nix/modules/devshell.nix {
              inherit inputs pkgs;
              buildEngineBinary = mkFinalEngineBinary;
            };
            # NOTE: pre-commit.nix returns the hooks attribute set directly.
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
            # --- Standard Flake Outputs - Per System ---

            # The Library function for consumption by other flakes
            lib = {
              mkEmbeddedScript = mkFinalEngineBinary;
            };

            # Packages
            packages = {
              default = defaultPackage;
            };

            # Development Shells
            devShells = devshellOutputs;

            # Applications
            apps = {
              default = {
                type = "app";
                program = "${defaultPackage}/bin/engine-test-binary";
              };
            };

            # Git Hooks (The pre-commit output is included for completeness)
            pre-commit = preCommitHooks;
          }
        );

        # Get the names of the flake attributes we want to transpose (packages, devShells, etc.)
        # We assume the first system's output defines all the keys.
        outputKeys = lib.attrNames (lib.head (lib.attrValues perSystemOutputs));

      in
      # Manual Transposition using standard functions
      lib.genAttrs outputKeys (
        outputName: lib.mapAttrs (system: systemOutputs: systemOutputs.${outputName}) perSystemOutputs
      )
    );
}
