⚜️ A Manifest of the Flake-Smith: The Nushell Binary Engine ⚜️

Johannes the Illuminator (Gemini) presents this compendium, which describes the
function and purpose of the `nushell-binary-engine` repository. This engine acts
as the **patrix** (a matrix or source, OED) for all self-contained Nushell
executables in your grand design.

---

🌟 I. Purpose and Philosophy

This repository solves the vexing riddle of creating a fully **portable**
Nushell script.

It is built upon the premise that a script's _content_ should be decoupled from
its _interpreter_. Thus, this engine utilizes Rust's power to embed the entire
Nushell runtime (`nu-engine`) within a single binary.

The result is a self-contained executable that will run with alacrity upon any
target system, requiring **neither** a pre-installed Nushell interpreter **nor**
the maintenance of a complex run-time environment.

---

🏗️ II. The Architecture of the Engine

The engine's sole output is a highly specialized Nix library function,
**`mkEmbeddedScript`**, designed to act as the Rust compiler's foreman.

### The Role of the Forge

When an external flake (such as the `quick-results` program) consumes this
repository, it invokes this function, passing two critical components:

1. **The Script Logic:** The `.nu` script content, which is injected into the
   Rust binary as a string.

2. **The Auxiliary Binaries:** A map of external helper tools (written in pure
   Rust, C++, etc.) whose **absolute Nix store paths** are injected into the
   final executable's environment variables.

|

| Component                   | Responsibility                                       | Delivery Method                                   |
| :-------------------------- | :--------------------------------------------------- | :------------------------------------------------ |
| Rust Kernel (`src/main.rs`) | Provides the generic interpreter and execution loop. | Consumed via `src = ./.;`                         |
| `mkEmbeddedScript`          | The Nix function that orchestrates the build.        | Exported via `lib.<system>`                       |
| Script Content              | The specific Nushell commands (the _what_).          | Injected via `RUSTC_ENV.NU_SCRIPT_CONTENT`        |
| Helper Binaries             | Specialized, external programs (the _how_).          | Injected via `RUSTC_ENV` (e.g., `NU_HELPER_PATH`) |

### Signature of `mkEmbeddedScript`

The function accepts the following, well-defined arguments:

|

| Argument                       | Type      | Description                                                                                      |
| :----------------------------- | :-------- | :----------------------------------------------------------------------------------------------- |
| The script: `scriptName`       | `String`  | The desired name of the final executable (e.g., `"quick-results"`).                              |
| The contents: `scriptContent`  | `String`  | The complete, unadulterated Nushell script text.                                                 |
| ExtraBinaries: `extraBinaries` | `AttrSet` | An **optional** set of environment variables pointing to external dependencies' Nix Store paths. |
| ExtraBinaries Cont.            | Cont.     | _E.g., `{ NU_HELPER_PATH = "\${./my-tool}/bin/tool"; }`_                                         |

---

🛠️ III. Usage and Consumption (The Quick-Start)

To utilize this engine, a consumer repository (the **Adept**) must declare this
repository as a flake input and then call the exported function.

### A. Declaring the Input (Example: `quick-results/flake.nix`)

The external repository must first establish a reference:

# The Consumer Flake's inputs

inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

# 🏆 Reference the engine repository

engine = { url = "github:gignsky/nushell-binary-engine"; inputs.nixpkgs.follows
= "nixpkgs"; }; };

### B. Invoking the Build Function

The consumer then executes the engine's function, demonstrating how to bind a
script and an auxiliary binary:

# The Consumer Flake's outputs

outputs = { self, nixpkgs, engine, ... }: let system = "x86_64-linux"; # 1.
Compile the external Rust tool locally (standard Nixpkgs method) helperBinary =
pkgs.rustPlatform.buildRustPackage { /* ... tool definition ... */ };

    # 2. Call the engine function to create the final, single binary
    quickResultsBinary = engine.lib.${system}.mkEmbeddedScript {
      scriptName = "quick-results";
      scriptContent = builtins.readFile ./quick-results.nu; # Load the script file

      # 3. Inject the helper tool's path into the binary's environment
      extraBinaries = {
        NU_HELPER_PATH = "${helperBinary}/bin/external-rust-tool";
      };
    };

in { packages.${system}.default = quickResultsBinary; };

### C. Script Interaction (`quick-results.nu`)

The embedded Nushell script accesses the helper tool via the injected
environment variable:

# Inside quick-results.nu

# The path is guaranteed to be correct and local to the closure

let tool_path = ($env.NU_HELPER_PATH);

# Execute the external tool using the absolute path

ls | $tool_path --filter-mode | get data
