{
  description = "SourceOS Linux realization root";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-apple-silicon = {
      url = "github:tpwrules/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lampstand-src = {
      url = "github:SocioProphet/lampstand";
      flake = false;
    };
    sourceos-syncd-src = {
      url = "github:SourceOS-Linux/sourceos-syncd";
      flake = false;
    };
    sourceos-boot-src = {
      url = "github:SourceOS-Linux/sourceos-boot";
      flake = false;
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-apple-silicon, sops-nix, lampstand-src, sourceos-syncd-src, sourceos-boot-src, nixos-generators }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: lib.genAttrs systems (system: f system);
    in {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);

      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in rec {
          meshd = pkgs.callPackage ./packages/mesh/meshd.nix { };
          meshd-linkd = pkgs.callPackage ./packages/mesh/meshd-linkd.nix { };
          meshd-exitd = pkgs.callPackage ./packages/mesh/meshd-exitd.nix { };
          bearbrowser = pkgs.callPackage ./packages/browser/bearbrowser.nix { };
          lampstand = pkgs.callPackage ./packages/search/lampstand.nix {
            inherit lampstand-src;
          };
          sourceos-syncd = pkgs.callPackage ./packages/sourceos-syncd/default.nix {
            inherit sourceos-syncd-src;
          };
          sourceos-boot = pkgs.callPackage ./packages/sourceos-boot/default.nix {
            inherit sourceos-boot-src;
          };

          # Public installer ISO, built natively per architecture.
          #   packages.x86_64-linux.sourceos-installer-iso  → x86_64 UEFI/BIOS ISO
          #   packages.aarch64-linux.sourceos-installer-iso → generic ARM64 UEFI ISO
          # (Apple Silicon uses the Asahi path, scripts/get-sourceos.sh — not this ISO.)
          sourceos-installer-iso = nixos-generators.nixosGenerate {
            inherit system;
            specialArgs = { self = self; };
            modules = [
              (if system == "aarch64-linux" then ./images/iso-aarch64.nix else ./images/iso-x86_64.nix)
            ];
            format = "install-iso";
          };

          default = meshd;
        } // lib.optionalAttrs (system == "x86_64-linux") (
          let
            syncdPkgImg = pkgs.callPackage ./packages/sourceos-syncd/default.nix { inherit sourceos-syncd-src; };
            bootPkgImg  = pkgs.callPackage ./packages/sourceos-boot/default.nix  { inherit sourceos-boot-src;  };
          in {
            # Pre-installed Desktop (GNOME) disk image — for the Agent-S GUI
            # test harness (boot + verify the desktop) and for cloud/VM use.
            sourceos-image-qcow2-desktop = nixos-generators.nixosGenerate {
              system = "x86_64-linux";
              specialArgs = { self = self; };
              modules = [
                self.nixosModules.desktop-gnome
                { services.getty.autologinUser = lib.mkDefault "sourceos";
                  users.users.sourceos.initialPassword = lib.mkDefault "sourceos"; }
              ];
              format = "qcow";
            };

            sourceos-image-qcow2-canary = nixos-generators.nixosGenerate {
              system = "x86_64-linux";
              specialArgs = { self = self; syncdPkg = syncdPkgImg; bootPkg = bootPkgImg; };
              modules = [
                sops-nix.nixosModules.sops
                self.nixosModules.sourceos-syncd
                ./images/canary-x86_64.nix
              ];
              format = "qcow";
            };
            sourceos-image-qcow2-stable = nixos-generators.nixosGenerate {
              system = "x86_64-linux";
              specialArgs = { self = self; syncdPkg = syncdPkgImg; bootPkg = bootPkgImg; };
              modules = [
                sops-nix.nixosModules.sops
                self.nixosModules.sourceos-syncd
                ./images/release-x86_64.nix
              ];
              format = "qcow";
            };
          }
        ));

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          workstationV0Names = [
            "git" "jq" "nixpkgs-fmt"
            "fzf" "atuin" "bat" "zoxide" "yazi" "eza" "gum" "direnv" "tldr" "fd" "ripgrep"
            "sd"
            "lazygit" "gh" "diff-so-fancy" "tig" "svu"
            "tmux" "sesh" "mprocs" "procs" "lazydocker" "k9s" "btop"
            "jnv" "gojq" "fx" "jless" "jqp"
            "dua" "dust" "kondo"
            "glow" "hyperfine" "entr" "curlie"
            "rclone" "rsync" "minio-client"
          ];

          haveAttr = n: builtins.hasAttr n pkgs;
          missing = lib.filter (n: !(haveAttr n)) workstationV0Names;
          presentPkgs = lib.filter (p: p != null) (map (n: if haveAttr n then pkgs.${n} else null) workstationV0Names);
          missingStr = lib.concatStringsSep " " missing;
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [ git jq nixpkgs-fmt ];
            shellHook = ''
              echo "SourceOS Linux development shell"
              echo "See docs/repository-layout.md, docs/agentplane-integration.md, and docs/mesh/README.md"
            '';
          };

          workstation-v0 = pkgs.mkShell {
            packages = presentPkgs ++ [ self.packages.${system}.lampstand ];
            shellHook = ''
              echo "SourceOS Workstation v0 dev shell"
              echo "See docs/workstation/README.md"
              if [ -n "${missingStr}" ]; then
                echo "NOTE: missing nixpkgs attrs (not added): ${missingStr}"
              fi
            '';
          };
        });

      nixosModules = {
        sourceos-syncd = import ./modules/nixos/sourceos-syncd/default.nix;
        # Public edition profiles. The installer (scripts/install-image.sh
        # --edition) composes one of these with a freshly generated
        # hardware-configuration.nix on the target — no per-machine config is
        # committed here. All build on profiles/base (no syncd/Katello/sops).
        desktop-gnome = import ./profiles/desktop-gnome/default.nix;  # Desktop edition (GNOME)
        server        = import ./profiles/server/default.nix;          # Server edition (headless)
        edge          = import ./profiles/edge/default.nix;            # Edge/appliance edition (mesh-ready)
      };

      nixosConfigurations = {
        builder-aarch64 =
          let
            pkgs-aarch64 = nixpkgs.legacyPackages.aarch64-linux;
            syncdPkg = pkgs-aarch64.callPackage ./packages/sourceos-syncd/default.nix {
              inherit sourceos-syncd-src;
            };
            bootPkg = pkgs-aarch64.callPackage ./packages/sourceos-boot/default.nix {
              inherit sourceos-boot-src;
            };
          in lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit self syncdPkg bootPkg; };
          modules = [
            nixos-apple-silicon.nixosModules.apple-silicon-support
            sops-nix.nixosModules.sops
            self.nixosModules.sourceos-syncd
            ./hosts/builder-aarch64/default.nix
          ];
        };

        canary-x86_64 =
          let
            pkgs-x86_64 = nixpkgs.legacyPackages.x86_64-linux;
            syncdPkg = pkgs-x86_64.callPackage ./packages/sourceos-syncd/default.nix {
              inherit sourceos-syncd-src;
            };
            bootPkg = pkgs-x86_64.callPackage ./packages/sourceos-boot/default.nix {
              inherit sourceos-boot-src;
            };
          in lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self syncdPkg bootPkg; };
          modules = [
            sops-nix.nixosModules.sops
            self.nixosModules.sourceos-syncd
            ./hosts/canary-x86_64/default.nix
          ];
        };

        stable-x86_64 =
          let
            pkgs-x86_64 = nixpkgs.legacyPackages.x86_64-linux;
            syncdPkg = pkgs-x86_64.callPackage ./packages/sourceos-syncd/default.nix {
              inherit sourceos-syncd-src;
            };
            bootPkg = pkgs-x86_64.callPackage ./packages/sourceos-boot/default.nix {
              inherit sourceos-boot-src;
            };
          in lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self syncdPkg bootPkg; };
          modules = [
            sops-nix.nixosModules.sops
            self.nixosModules.sourceos-syncd
            ./hosts/stable-x86_64/default.nix
          ];
        };

        exit-x86_64 =
          let
            pkgs-x86_64 = nixpkgs.legacyPackages.x86_64-linux;
            syncdPkg = pkgs-x86_64.callPackage ./packages/sourceos-syncd/default.nix {
              inherit sourceos-syncd-src;
            };
            bootPkg = pkgs-x86_64.callPackage ./packages/sourceos-boot/default.nix {
              inherit sourceos-boot-src;
            };
          in lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self syncdPkg bootPkg; };
          modules = [
            sops-nix.nixosModules.sops
            self.nixosModules.sourceos-syncd
            ./hosts/exit-x86_64/default.nix
          ];
        };
      };

      checks = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in lib.optionalAttrs (system == "x86_64-linux" || system == "aarch64-linux") {
          builder-aarch64-smoke =
            if system == "aarch64-linux"
            then import ./tests/builder-aarch64-contract.nix { inherit pkgs; }
            else pkgs.runCommand "builder-aarch64-smoke-skip" {} ''
              mkdir -p $out
            '';

          canary-x86_64-smoke =
            if system == "x86_64-linux"
            then import ./tests/canary-x86_64-contract.nix { inherit pkgs; }
            else pkgs.runCommand "canary-x86_64-smoke-skip" {} ''
              mkdir -p $out
            '';

          stable-x86_64-smoke =
            if system == "x86_64-linux"
            then import ./tests/stable-x86_64-contract.nix { inherit pkgs; }
            else pkgs.runCommand "stable-x86_64-smoke-skip" {} ''
              mkdir -p $out
            '';

          exit-x86_64-smoke =
            if system == "x86_64-linux"
            then import ./tests/exit-x86_64-contract.nix { inherit pkgs; }
            else pkgs.runCommand "exit-x86_64-smoke-skip" {} ''
              mkdir -p $out
            '';

          # ── Edition boot tests (Layer 1: deterministic QEMU boot, no LLM) ──
          # nixosTests only run on Linux; on other systems expose a skip stub.
          edition-desktop-boot =
            if system == "x86_64-linux" || system == "aarch64-linux"
            then import ./tests/editions/desktop-boot.nix { inherit pkgs self; }
            else pkgs.runCommand "edition-desktop-boot-skip" {} "mkdir -p $out";
          edition-server-boot =
            if system == "x86_64-linux" || system == "aarch64-linux"
            then import ./tests/editions/server-boot.nix { inherit pkgs self; }
            else pkgs.runCommand "edition-server-boot-skip" {} "mkdir -p $out";
          edition-edge-boot =
            if system == "x86_64-linux" || system == "aarch64-linux"
            then import ./tests/editions/edge-boot.nix { inherit pkgs self; }
            else pkgs.runCommand "edition-edge-boot-skip" {} "mkdir -p $out";

          mesh-module-contract = import ./tests/mesh-module-contract.nix { inherit pkgs; };
          mesh-runtime-contract = import ./tests/mesh-runtime-contract.nix { inherit pkgs; };
          mesh-package-contract = import ./tests/mesh-package-contract.nix { inherit pkgs; };
          mesh-host-runtime-contract = import ./tests/mesh-host-runtime-contract.nix { inherit pkgs; };
          sourceos-shell-module-contract = import ./tests/sourceos-shell-module-contract.nix { inherit pkgs; };
          sourceos-shell-pdf-stack-contract = import ./tests/sourceos-shell-pdf-stack-contract.nix { inherit pkgs; };

          meshd-package = self.packages.${system}.meshd;
          meshd-linkd-package = self.packages.${system}.meshd-linkd;
          meshd-exitd-package = self.packages.${system}.meshd-exitd;
          lampstand-package = self.packages.${system}.lampstand;
          sourceos-syncd-package = self.packages.${system}.sourceos-syncd;
          sourceos-boot-package = self.packages.${system}.sourceos-boot;
          sourceos-syncd-package-contract = import ./tests/sourceos-syncd-package-contract.nix { inherit pkgs; };
          sourceos-boot-package-contract = import ./tests/sourceos-boot-package-contract.nix { inherit pkgs; };
        });

      sourceos = {
        channels = [ "dev" "candidate" "stable" ];
        notes = "This flake is the Linux realization root. Control-plane semantics live in SocioProphet/agentplane and shared channel/capability schemas live in SocioProphet/socioprophet-agent-standards.";
      };
    };
}
