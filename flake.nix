{
  description = "Harmony programming language compiler and model checker";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          # Pin to a known-good Python for Harmony + ANTLR 4.9.3.
          python = pkgs.python311;
          pyPkgs = python.pkgs;

          harmonyVersion =
            if (self ? rev) && (self.rev != null) then
              "0.0.0+git.${builtins.substring 0 7 self.rev}"
            else if (self ? lastModifiedDate) then
              "0.0.0+${self.lastModifiedDate}"
            else
              "0.0.0";

          antlr4-python3-runtime = pyPkgs.buildPythonPackage rec {
            pname = "antlr4-python3-runtime";
            version = "4.9.3";
            src = pkgs.fetchPypi {
              inherit pname version;
              hash = "sha256-8iRGm0FoKUkCux76gKi/eFXyTJmu+Zy+/BvNPM53iBs=";
            };
            format = "setuptools";
            doCheck = false;
          };

          antlr-denter = pyPkgs.buildPythonPackage rec {
            pname = "antlr-denter";
            version = "1.3.1";
            # The sdist's setup.py expects a README.md outside the source root.
            # Use the wheel instead.
            src = pkgs.fetchurl {
              url = "https://files.pythonhosted.org/packages/0b/7d/90b9b27e51099deff45ae426157332c8d29448c62df0036efaa28ef3c27b/antlr_denter-1.3.1-py3-none-any.whl";
              hash = "sha256-FaMtw5Il3rW0B5aPyaN7eNYJbFuSGJH3tO31OG6Tjho=";
            };
            format = "wheel";
            propagatedBuildInputs = [ antlr4-python3-runtime ];
            doCheck = false;
          };

          automata-lib = pyPkgs.buildPythonPackage rec {
            pname = "automata-lib";
            version = "5.0.0";
            src = pkgs.fetchPypi {
              inherit pname version;
              hash = "sha256-YMUmtNrWes4rile5OlPTi2UEBQsAiEXKclRa/ZvnuQw=";
            };
            format = "setuptools";
            doCheck = false;
          };
        in
        rec {
          harmony = pyPkgs.buildPythonPackage {
            pname = "harmony";
            version = harmonyVersion;
            src = self;
            format = "setuptools";

            # setup.py reads harmony_model_checker/__init__.py for __version__.
            postPatch = ''
              cat > harmony_model_checker/__init__.py <<'EOF'
              __package__ = "harmony_model_checker"
              __version__ = "${harmonyVersion}"
              EOF
            '';

            nativeBuildInputs = [
              pyPkgs.setuptools
              pyPkgs.wheel
            ];

            propagatedBuildInputs = [
              pkgs.graphviz
              antlr-denter
              antlr4-python3-runtime
              automata-lib
              pyPkgs.pydot
              pyPkgs.requests
            ];

            doCheck = false;
            pythonImportsCheck = [
              "harmony_model_checker"
              "harmony_model_checker.charm"
            ];

            meta = with pkgs.lib; {
              description = "Harmony programming language compiler and model checker";
              homepage = "https://harmony.cs.cornell.edu";
              license = licenses.bsd3;
              mainProgram = "harmony";
            };
          };

          default = harmony;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/harmony";
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          python = pkgs.python311;
        in
        {
          default = pkgs.mkShell {
            packages = [
              (python.withPackages (ps: [
                ps.pydot
                ps.requests
              ]))
              pkgs.graphviz
              pkgs.stdenv.cc
            ];
          };
        }
      );
    };
}
