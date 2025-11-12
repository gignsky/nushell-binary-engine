{
  description = "Core engine for building self-contained Nushell binaries (nushell-binary-engine).";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
    systems.url = "github:nix-systems/default";
    rust-flake = {
      url = "github:juspay/rust-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Dev tools
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake/f6ce9481df9aec739e4e06b67492401a5bb4f0b1";
    cargo-doc-live.url = "github:srid/cargo-doc-live/b09d5d258d2498829e03014931fc19aed499b86f";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      flake = false;
    };

    # # personal repos
    # gigdot = {
    #   url = "github:gignsky/dotfiles";
    #   flake = true;
    # };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      # See ./nix/modules/*.nix for the modules that are imported here.
      # Conditionally exclude template.nix during flake checks
      imports =
        with builtins;
        let
          allModules = attrNames (readDir ./nix/modules);
          # Skip template.nix if NIX_SKIP_TEMPLATE is set (useful for flake check)
          filteredModules =
            if (getEnv "NIX_SKIP_TEMPLATE" != "") then
              filter (fn: fn != "template.nix") allModules
            else
              allModules;
        in
        map (fn: ./nix/modules/${fn}) filteredModules;

      # ⚜️ Integration of the Core Engine Logic via perSystem ⚜️
      # This block defines the reusable library function and a default test application.
      perSystem =
        { config, pkgs, ... }:
        let
          # ⚜️ The Core Engine Function ⚜️
          # This function accepts the desired binary name and the script content as a string.
          mkEmbeddedScript =
            { scriptName, scriptContent }:
            pkgs.rustPlatform.buildRustPackage rec {
              pname = scriptName;
              version = "0.1.0";

              # The source directory containing Cargo.toml and src/
              src = ./.;

              # The CRITICAL step: Inject the script content into the Rust binary
              # at compile time via an environment variable.
              RUSTC_ENV = {
                NU_SCRIPT_CONTENT = scriptContent;
              };

              # Standard build settings
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
        {
          # 1. Export the build function in the 'lib' attribute for easy access by other flakes
          lib = {
            inherit mkEmbeddedScript;
          };

          # 2. Provide a default example package for testing the engine repo itself
          packages.example = mkEmbeddedScript {
            scriptName = "engine-test-binary";
            # A simple test script (note the use of '' for multiline Nix strings)
            scriptContent = ''
              # The embedded Nushell code to verify engine functionality
              let result = 100 | math sqrt;
              print $"Engine Test Successful! Result of sqrt(100) is: ($result)";
            '';
          };

          # 3. Define a simple command to run the package
          apps.default = {
            type = "app";
            # Reference the package via the flake-parts config
            program = "${config.packages.example}/bin/engine-test-binary";
          };
        };
    };
}
