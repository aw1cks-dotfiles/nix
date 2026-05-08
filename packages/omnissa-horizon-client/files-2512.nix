# Omnissa Horizon Client 2512 native library derivation.
# Used only as a source of PCoIP/crtbora/C++ binding libs for the 2603 package,
# since 2603 no longer bundles these in its main tarball.
{
  stdenv,
  fetchurl,
  opensc,
}:
let
  version = "2512";
  sysArch = "x64";
in
stdenv.mkDerivation {
  pname = "omnissa-horizon-files";
  inherit version;
  dontStrip = true;
  src = fetchurl {
    url = "https://download3.omnissa.com/software/CART26FQ4_LIN_2512_TARBALL/Omnissa-Horizon-Client-Linux-2512-8.17.0-20187591429.tar.gz";
    hash = "sha256-dYvP3W/tciqwazuVu4ib9gB98JUJykczd7sPCUih/Ew=";
  };
  installPhase = ''
    mkdir ext
    find ${sysArch} -type f -print0 | xargs -0n1 tar -Cext --strip-components=1 -xf

    chmod -R u+w ext/usr/lib
    mv ext/usr $out
    cp -r ext/${sysArch}/include $out/
    cp -r ext/${sysArch}/lib $out/

    # Remove the bundled libstdc++ to avoid conflicts; FHS env provides it.
    rm -f "$out/lib/omnissa/gcc/libstdc++.so.6"

    mkdir -p $out/lib/omnissa/horizon/pkcs11
    ln -s ${opensc}/lib/pkcs11/opensc-pkcs11.so \
      $out/lib/omnissa/horizon/pkcs11/libopenscpkcs11.so
  '';
}
