{
  description = "Legacy exploit devshell (Python2 + PyLorcon2 pinned to 2013)";

  inputs = {
    nixpkgs-legacy.url =
      "github:NixOS/nixpkgs/fefb0df7d2ab2e1cabde7312238026dcdc972441";
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
          ];
      };

      py2 = pkgs.python27;
      py2Pkgs = pkgs.python27Packages;

      # ✅ Python2-era lorcon
      lorconSrc = pkgs.fetchFromGitHub {
        owner = "kismetwireless";
        repo = "lorcon";
        rev = "efd4f3550832e6bff20613d6634b08b8d92eedfc";
        sha256 = "sha256-MF5LUuot9p7Hh27XsZvSaEkOCPwUJEyNrndjNw+vzIk="; #pkgs.lib.fakeSha256;
      };

      lorcon = pkgs.stdenv.mkDerivation {
        pname = "lorcon2";
        version = "git-2013";
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

      # ✅ Build PyLorcon2 for Python2
      pylorcon2 = py2Pkgs.buildPythonPackage {
        pname = "PyLorcon2";
        version = "git-2013";

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

          # Python2 runtime
          py2
          py2Pkgs.pip
          py2Pkgs.setuptools
          py2Pkgs.wheel
          py2Pkgs.requests
          py2Pkgs.pycrypto
          py2Pkgs.pycryptodome

          # Lorcon stack
          lorcon
          pylorcon2

          # Toolchain
          pkgs.gcc
          pkgs.gnumake
          pkgs.pkg-config
          pkgs.binutils
          pkgs.openssl
          pkgs.zlib

          # Debugging
          pkgs.gdb
          pkgs.strace
          pkgs.ltrace
          pkgs.file
          pkgs.iw
          pkgs.iproute2
          pkgs.ethtool
        ];

shellHook = ''
  unset MANPATH

  export PATH="${py2}/bin:${py2Pkgs.pip}/bin:$PATH"
  export LD_LIBRARY_PATH="${lorcon}/lib:$LD_LIBRARY_PATH"

  alias python=python2
  alias pip=pip2

  echo ""
  echo "[legacy python2 wireless shell ready]"
  echo "python -> $(python --version 2>&1)"
  echo ""
'';
      };
    };
}
