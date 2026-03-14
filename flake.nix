{
  description = "Merlin to OpenAI API proxy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachSystem [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ] (
      system: let
        pkgs = import nixpkgs {inherit system;};
        lib = pkgs.lib;
        pythonPackages = pkgs.python312Packages;

        merlinai-proxy = pythonPackages.buildPythonApplication rec {
          pname = "merlinai-proxy";
          version = "0.1.0";
          src = self;

          pyproject = false;
          dontBuild = true;

          propagatedBuildInputs = with pythonPackages; [
            curl-cffi
            fastapi
            h2
            httpx
            loguru
            pydantic
            python-dotenv
            uvicorn
          ];

          installPhase = ''
            runHook preInstall

            sitePackages="$out/${pythonPackages.python.sitePackages}"

            mkdir -p "$sitePackages" "$out/bin"
            cp -r merlin_proxy "$sitePackages/"

            install -Dm644 README.md "$out/share/doc/${pname}/README.md"
            install -Dm644 pyproject.toml "$out/share/${pname}/pyproject.toml"

            cat > "$out/bin/${pname}" <<'EOF'
#!${pythonPackages.python.interpreter}
from merlin_proxy import app
import uvicorn

uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
            chmod +x "$out/bin/${pname}"

            runHook postInstall
          '';

          pythonImportsCheck = ["merlin_proxy"];

          makeWrapperArgs = [
            "--set"
            "PYTHONDONTWRITEBYTECODE"
            "1"
            "--set"
            "PYTHONUNBUFFERED"
            "1"
          ];

          meta = with lib; {
            description = "OpenAI-compatible proxy for Merlin AI";
            homepage = "https://github.com/bigtongue5566/merlinai-proxy";
            mainProgram = pname;
            platforms = platforms.unix;
          };
        };

        merlinai-proxy-image = pkgs.dockerTools.buildLayeredImage {
          name = merlinai-proxy.pname;
          tag = "${merlinai-proxy.version}-${lib.substring 0 12 (builtins.hashString "sha256" merlinai-proxy.drvPath)}";
          contents = [merlinai-proxy];
          extraCommands = ''
            find . -type d -name __pycache__ -prune -exec rm -rf {} +
            rm -rf ./nix/store/*-python3-*/lib/python3.12/idlelib
            rm -rf ./nix/store/*-python3-*/lib/python3.12/test
            rm -rf ./nix/store/*-python3-*/lib/python3.12/tkinter
            rm -rf ./nix/store/*-python3-*/lib/python3.12/turtledemo
            rm -rf ./nix/store/*-python3-*/lib/python3.12/ensurepip
            rm -rf ./nix/store/*-python3-*/lib/python3.12/venv
            rm -rf ./nix/store/*-python3-*/lib/python3.12/pydoc_data
            rm -rf ./nix/store/*-python3-*/lib/python3.12/config-*
            rm -rf ./nix/store/*-python3-*/include
            rm -f ./nix/store/*-python3-*/bin/idle ./nix/store/*-python3-*/bin/idle3
            rm -f ./nix/store/*-python3-*/bin/pydoc ./nix/store/*-python3-*/bin/pydoc3
          '';
          config = {
            Cmd = ["${merlinai-proxy}/bin/${merlinai-proxy.pname}"];
            Env = [
              "HOME=/tmp"
              "PYTHONDONTWRITEBYTECODE=1"
              "PYTHONUNBUFFERED=1"
            ];
            User = "10001:10001";
            WorkingDir = "/tmp";
            ExposedPorts = {"8000/tcp" = {};};
            Labels = {
              "org.opencontainers.image.source" = "https://github.com/bigtongue5566/merlinai-proxy";
            };
          };
        };
      in {
        packages =
          {
            inherit merlinai-proxy;
            default = merlinai-proxy;
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            inherit merlinai-proxy-image;
          };

        apps.default = flake-utils.lib.mkApp {
          drv = merlinai-proxy;
        };
      }
    );
}
