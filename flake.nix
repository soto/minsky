{
  description = "pyminsky - Python interface to the Minsky economics modeling software";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = pkgs.lib;
          python = pkgs.python3;
        in
        {
          # ==================================================================
          # pyminsky -- the Python C extension wrapping the Minsky engine
          # ==================================================================
          pyminsky = python.pkgs.buildPythonPackage {
            pname = "pyminsky";
            version = "3.0.0-unstable-2026-02-13";
            format = "other";

            # fetchFromGitHub with fetchSubmodules to ensure ecolab,
            # RavelCAPI, and exprtk submodules are included.
            # builtins.path / self do NOT follow gitlinks, so submodule
            # directories end up empty in the Nix store.
            src = pkgs.fetchFromGitHub {
              owner = "highperformancecoder";
              repo = "minsky";
              rev = "20e6d2d0f0cd19699da7423d7ef5746fe7084f6e";
              hash = "sha256-ZImaBaS4U2fuDCdaI2bmCGwTRYb7dgBcxmsUoWUgxtE=";
              fetchSubmodules = true;
            };

            # ---- Build-time-only dependencies ----
            nativeBuildInputs = [
              pkgs.gnumake
              pkgs.pkg-config
              pkgs.which
              pkgs.coreutils
            ] ++ lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.cctools
            ];

            # ---- Runtime/link-time dependencies ----
            # These libraries end up linked into pyminsky.so and must be
            # present both at build time and at runtime.
            buildInputs = [
              pkgs.boost
              pkgs.gsl
              pkgs.cairo
              pkgs.pango
              pkgs.librsvg
              pkgs.openssl
              pkgs.readline
              pkgs.ncurses
              pkgs.libclipboard
              pkgs.glib
              pkgs.zlib
            ] ++ lib.optionals pkgs.stdenv.isLinux [
              pkgs.xorg.libxcb
              pkgs.xorg.libX11
            ] ++ lib.optionals pkgs.stdenv.isDarwin [
              pkgs.pixman
              pkgs.libffi
              pkgs.libiconv
            ];

            # ------------------------------------------------------------------
            # Phase: unpack -- verify submodule presence
            # ------------------------------------------------------------------
            postUnpack = ''
              for subdir in \
                "$sourceRoot/ecolab/Makefile" \
                "$sourceRoot/ecolab/classdesc/classdesc.cc" \
                "$sourceRoot/ecolab/classdesc/json5_parser/json5_parser/json5_parser.h" \
                "$sourceRoot/ecolab/graphcode/graphcode.h" \
                "$sourceRoot/RavelCAPI/Makefile" \
                "$sourceRoot/RavelCAPI/civita/Makefile" \
                "$sourceRoot/exprtk/exprtk.hpp"
              do
                if [ ! -f "$subdir" ]; then
                  echo "ERROR: required file not found: $subdir"
                  echo "Ensure all git submodules are recursively initialised."
                  exit 1
                fi
              done
            '';

            # ------------------------------------------------------------------
            # Phase: patch -- adapt the Make-based build for the Nix sandbox
            # ------------------------------------------------------------------
            postPatch = ''
              # ================================================================
              # 1. Pre-create ecolab/include/Makefile.config
              # ================================================================
              # EcoLab normally auto-detects available libraries by probing the
              # filesystem and pkg-config. Under Nix we know exactly what is
              # available, so we write the config directly.
              cat > ecolab/include/Makefile.config <<EOFCONFIG
              GNUSL=1
              CAIRO=1
              PANGO=1
              READLINE=1
              ZLIB=1
              GCC=1
              EOFCONFIG
              sed -i"" -e "s/^[[:space:]]*//" ecolab/include/Makefile.config

              # ================================================================
              # 2. Prevent the ecolab Makefile from regenerating Makefile.config
              # ================================================================
              # The rule at line 269 of ecolab/Makefile fires a configure-like
              # script to create Makefile.config. We replace its body with a
              # no-op so it doesn't overwrite our config.
              python3 -c "
              import re
              with open('ecolab/Makefile', 'r') as f:
                  content = f.read()
              # Match from the rule target to the next non-indented line or EOF
              pattern = r'(\\\$\(ECOLAB_HOME\)/\\\$\(MCFG\):)\n(\t[^\n]*\n)+'
              replacement = r'\1\n\t@echo \"Nix: using pre-created Makefile.config\"\n'
              content = re.sub(pattern, replacement, content)
              with open('ecolab/Makefile', 'w') as f:
                  f.write(content)
              "

              # Make the include optional so missing config doesn't fatal
              sed -i"" -e "s|include \$(ECOLAB_HOME)/include/Makefile.config|-include \$(ECOLAB_HOME)/include/Makefile.config|" ecolab/include/Makefile

              # ================================================================
              # 3. Fix hardcoded compilers
              # ================================================================
              sed -i"" -e "s|^CC=gcc|CC?=cc|" -e "s|^CPLUSPLUS=g++|CPLUSPLUS?=c++|" ecolab/classdesc/Makefile

              sed -i"" \
                -e "s|^      CPLUSPLUS=g++|      CPLUSPLUS?=c++|" \
                -e "s|^    CC=gcc|    CC?=cc|" \
                -e "s|^    CPP=g++ -E|    CPP=\$(CPLUSPLUS) -E|" \
                ecolab/include/Makefile

              # ================================================================
              # 4. Remove hardcoded FHS paths
              # ================================================================
              substituteInPlace ecolab/include/Makefile \
                --replace-warn '-isystem /usr/local/include -isystem /opt/local/include -isystem /opt/local/include/db48 -isystem /usr/X11R6/include' "" \
                --replace-warn '-L /opt/local/lib/db48' ""

              substituteInPlace Makefile \
                --replace-warn '-L/opt/local/lib/db48' ""

              substituteInPlace RavelCAPI/Makefile \
                --replace-warn '-isystem /usr/local/include -isystem /opt/local/include' ""

              substituteInPlace RavelCAPI/civita/Makefile \
                --replace-warn 'FLAGS+=-isystem /usr/local/include -isystem /opt/local/include' ""
              substituteInPlace RavelCAPI/civita/Makefile \
                --replace-warn '-I$(HOME)/usr/include -I/usr/local/include' ""

              substituteInPlace ecolab/classdesc/Makefile \
                --replace-warn 'FLAGS=-g -I. -I/usr/include/tirpc' 'FLAGS=-g -I.'

              # ================================================================
              # 5. Fix macOS-specific compilation rules
              # ================================================================
              ${lib.optionalString pkgs.stdenv.isDarwin ''
                substituteInPlace Makefile \
                  --replace-warn 'g++ -ObjC++ $(FLAGS) -I/opt/local/include' '$(CPLUSPLUS) -ObjC++ $(FLAGS)'
                substituteInPlace ecolab/Makefile \
                  --replace-warn 'g++ -ObjC++ -DMAC_OSX_TK -I/opt/local/include' '$(CPLUSPLUS) -ObjC++ -DMAC_OSX_TK'
              ''}

              # ================================================================
              # 6. Disable -Werror
              # ================================================================
              substituteInPlace Makefile \
                --replace-warn 'FLAGS+=-Werror' '# FLAGS+=-Werror  # disabled for Nix build'

              # ================================================================
              # 7. Prevent impure git describe in RavelCAPI
              # ================================================================
              substituteInPlace RavelCAPI/Makefile \
                --replace-warn 'RAVELRELEASE=$(shell git describe)' 'RAVELRELEASE=nix-build'

              # ================================================================
              # 8. Patch arch and sw_vers usage in top-level Makefile
              # ================================================================
              substituteInPlace Makefile \
                --replace-warn 'ARCH=$(shell arch)' 'ARCH=${if pkgs.stdenv.isAarch64 then "arm64" else "x86_64"}'

              ${lib.optionalString pkgs.stdenv.isDarwin ''
                sed -i"" -e '/MACOSX_MIN_VERSION=.*sw_vers/c\MACOSX_MIN_VERSION=14.0' Makefile
              ''}

              # ================================================================
              # 9. Remove -lxcb -lX11 on macOS (X11 not needed/available)
              # ================================================================
              ${lib.optionalString pkgs.stdenv.isDarwin ''
                sed -i"" -e "s/-lxcb -lX11//" Makefile
              ''}

              # ================================================================
              # 10. Remove cp pyminsky.so gui-js/build/ (dir doesn't exist
              # and we don't need it for the pyminsky-only build)
              # ================================================================
              ${lib.optionalString pkgs.stdenv.isDarwin ''
                sed -i"" -e "/cp pyminsky.so gui-js/d" Makefile
              ''}

            '';

            # ------------------------------------------------------------------
            # Phase: configure -- GNU Make, no configure step
            # ------------------------------------------------------------------
            dontConfigure = true;

            # ------------------------------------------------------------------
            # Phase: build -- compile pyminsky.so
            # ------------------------------------------------------------------
            buildPhase = ''
              runHook preBuild

              # Prevent the Makefile from searching for Node.js
              export HAVE_NODE=

              make -j''${NIX_BUILD_CORES:-4} \
                CPLUSPLUS="c++" \
                CC="cc" \
                LINK="c++" \
                GCC=1 \
                FPIC=1 \
                NOWERROR=1 \
                OBS=1 \
                pyminsky.so

              runHook postBuild
            '';

            # ------------------------------------------------------------------
            # Phase: check
            # ------------------------------------------------------------------
            doCheck = false;  # Tests require xvfb and full GUI infrastructure

            # ------------------------------------------------------------------
            # Phase: install
            # ------------------------------------------------------------------
            installPhase = ''
              runHook preInstall

              local sitePackages="$out/lib/${python.libPrefix}/site-packages"
              mkdir -p "$sitePackages"
              cp pyminsky.so "$sitePackages/"

              runHook postInstall
            '';

            meta = {
              description = "Python interface to the Minsky economics modeling software";
              longDescription = ''
                pyminsky provides Python bindings to Minsky, a system dynamics
                program with additional features for handling monetary flows.
                It allows scripting Minsky models, running simulations, and
                exporting data from Python.
              '';
              homepage = "https://github.com/highperformancecoder/minsky";
              license = lib.licenses.gpl3Plus;
              platforms = lib.platforms.unix;
              maintainers = [];
            };
          };

          default = self.packages.${system}.pyminsky;
        }
      );

      # ==================================================================
      # Development shell
      # ==================================================================
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = pkgs.lib;
          python = pkgs.python3;
        in
        {
          default = pkgs.mkShell {
            name = "minsky-dev";

            nativeBuildInputs = [
              pkgs.gnumake
              pkgs.pkg-config
              pkgs.which
              pkgs.coreutils
              pkgs.clang-tools
            ] ++ lib.optionals pkgs.stdenv.isDarwin [
              pkgs.darwin.cctools
            ] ++ lib.optionals pkgs.stdenv.isLinux [
              pkgs.gdb
              pkgs.valgrind
            ];

            buildInputs = [
              pkgs.boost
              pkgs.gsl
              pkgs.cairo
              pkgs.pango
              pkgs.librsvg
              pkgs.openssl
              pkgs.readline
              pkgs.ncurses
              pkgs.libclipboard
              python
              pkgs.glib
              pkgs.zlib
            ] ++ lib.optionals pkgs.stdenv.isLinux [
              pkgs.xorg.libxcb
              pkgs.xorg.libX11
            ] ++ lib.optionals pkgs.stdenv.isDarwin [
              pkgs.pixman
              pkgs.libffi
              pkgs.libiconv
            ];

            shellHook = ''
              echo "Minsky development shell"
              echo "  Build pyminsky:  make -j$NIX_BUILD_CORES FPIC=1 GCC=1 NOWERROR=1 OBS=1 pyminsky.so"
              echo "  Test import:     python3 -c 'import pyminsky'"
              echo ""
              echo "Note: Run 'git submodule update --init --recursive' if submodules are empty."

              if [ ! -f ecolab/include/Makefile.config ]; then
                mkdir -p ecolab/include
                cat > ecolab/include/Makefile.config <<'EOFCONFIG'
              GNUSL=1
              CAIRO=1
              PANGO=1
              READLINE=1
              ZLIB=1
              EOFCONFIG
                sed -i 's/^[[:space:]]*//' ecolab/include/Makefile.config
                echo "Created ecolab/include/Makefile.config"
              fi
            '';
          };
        }
      );

      # ==================================================================
      # Checks -- verify pyminsky can be imported
      # ==================================================================
      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          python = pkgs.python3;
        in
        {
          pyminsky-import = pkgs.runCommand "pyminsky-import-test" {
            nativeBuildInputs = [ python ];
            PYTHONPATH = "${self.packages.${system}.pyminsky}/lib/${python.libPrefix}/site-packages";
          } ''
            python3 -c "import pyminsky; print('pyminsky imported successfully')"
            touch $out
          '';
        }
      );
    };
}
