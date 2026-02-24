{
  description = "Legacy exploit devshell (Python2 default + Python3 + PyLorcon2 + Crypto + full tooling)";

  inputs = {
    # nixpkgs-legacy.url = "github:NixOS/nixpkgs/nixos-21.05"; #  is:
    nixpkgs-legacy.url = "github:NixOS/nixpkgs/fefb0df7d2ab2e1cabde7312238026dcdc972441";
  };

  outputs = { self, nixpkgs-legacy }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs-legacy {
        inherit system;

        config.allowInsecurePredicate = p:
          let
            lib = (import nixpkgs-legacy { inherit system; }).lib;
            n = lib.getName p;
          in builtins.elem n [
            "python-2.7.18.7"
            "python2.7"
            "python2.7-pip"
            "python3.6"
          ];
      };

      py2 = pkgs.python27;
      py2Pkgs = pkgs.python27Packages;

      py3 = pkgs.python36;
      py3Pkgs = pkgs.python36Packages;

      lorconSrc = pkgs.fetchFromGitHub {
        owner = "kismetwireless";
        repo = "lorcon";
        # git ls-remote https://github.com/kismetwireless/lorcon master
        rev = "4a81d6aaa2c6ac7253ecd182ffe97c6c89411196";
        sha256 = "sha256-pFhO1BBvHOwH1X6WdcBBaAvQEtIw9OSNvYMKS2SEhzE=";
      };

      lorcon = pkgs.stdenv.mkDerivation {
        pname = "lorcon2";
        version = "git";
        src = lorconSrc;

        nativeBuildInputs = [
          pkgs.autoconf
          pkgs.automake
          pkgs.libtool
          pkgs.pkg-config
        ];

        buildInputs = [
          pkgs.libpcap
          pkgs.libnl
        ];

        preConfigure = ''
          autoreconf -fi
        '';

        configureFlags = [ "--disable-manpages" ];

        installFlags = [ "-i" ];
      };

      pylorcon2 = py3Pkgs.buildPythonPackage {
        pname = "PyLorcon2";
        version = "git";

        src = lorconSrc;
        sourceRoot = "source/pylorcon2";

        buildInputs = [
          lorcon
          pkgs.libpcap
          pkgs.libnl
        ];

        preBuild = ''
          export CFLAGS="-I${lorcon}/include"
          export LDFLAGS="-L${lorcon}/lib"
        '';

        doCheck = false;
      };

    in {
      devShells.${system}.default = pkgs.mkShell {

        packages = [

          # Python2 primary
          py2
          py2Pkgs.pip
          py2Pkgs.setuptools
          py2Pkgs.wheel
          py2Pkgs.requests
          py2Pkgs.pycrypto
          py2Pkgs.pycryptodome

          # Python3 secondary
          py3
          py3Pkgs.requests
          py3Pkgs.pycryptodome

          # lorcon stack
          lorcon
          pylorcon2

          # toolchain
          pkgs.gcc
          pkgs.gnumake
          pkgs.pkg-config
          pkgs.binutils
          pkgs.openssl
          pkgs.zlib

          # debugging
          pkgs.gdb
          pkgs.strace
          pkgs.ltrace
          pkgs.file

          # man
          pkgs.man-db
          pkgs.groff
          pkgs.man-pages
          pkgs.man-pages-posix
        ];

        shellHook = ''
          unset MANPATH
          export VENDOR_DIR="$PWD/vendor"
          mkdir -p "$VENDOR_DIR"

          export PIP_TARGET="$VENDOR_DIR"
          export PYTHONPATH="$VENDOR_DIR:$PYTHONPATH"

          export PATH="${py2}/bin:${py2Pkgs.pip}/bin:$PATH"
          alias python=python2
          alias pip=pip2

          echo ""
          echo "[legacy exploit shell ready]"
          echo "python  -> $(python --version 2>&1)"
          echo "python3 -> $(python3 --version 2>&1)"
          echo ""
        '';
      };
    };
}
