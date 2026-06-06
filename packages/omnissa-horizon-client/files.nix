# Omnissa Horizon Client 2603 file derivation.
# In 2603 the main tarball only contains the UI shell and next-bundle.
# PCoIP connection libraries (libcrtbora.so, libomnissabase.so, etc.) are
# not in the main tarball; we build a companion 2512 files derivation and
# symlink its native libs here, since the C ABI is stable across releases.
{
  stdenv,
  fetchurl,
  opensc,
  callPackage,
}:
let
  # Build the 2512 files derivation to get libcrtbora.so, libomnissabase.so
  # and the bundled omnissa C++ libs that 2603 no longer ships.
  files2512 = callPackage ./files-2512.nix { };
in
stdenv.mkDerivation {
  pname = "omnissa-horizon-files";
  version = "2603";

  # strip -S corrupts PE/CLI .NET assemblies in the next-bundle directory.
  dontStrip = true;

  src = fetchurl {
    url = "https://download3.omnissa.com/software/CART27FQ1_LIN_2603_TARBALL/Omnissa-Horizon-Client-2603-8.18.0-24120621798.x64.tar.gz";
    hash = "sha256-XY20WUNVrKhWa+ioLPvwLbhoxCfeJEfFT9J2scariXA=";
  };

  installPhase = ''
    runHook preInstall

    # unpackPhase sets cwd to the extracted dir; usr/ is directly here.
    cp -r usr "$out"
    chmod -R u+w "$out"

    # Transplant PCoIP/crtbora native libs from the 2512 build.
    # libclientSdkCPrimitive.so (2603) still depends on libcrtbora.so,
    # libomnissabase.so, and the omnissa C++ binding libs.
    mkdir -p "$out/lib/omnissa"
    for lib in \
      libcrtbora.so libomnissabase.so librtavCliLib.so libudpProxyLib.so \
      libatkmm-1.6.so.1 libcairomm-1.0.so.1 libgdkmm-3.0.so.1 \
      libgiomm-2.4.so.1 libglibmm-2.4.so.1 libgtkmm-3.0.so.1 \
      libpangomm-1.4.so.1 libsigc-2.0.so.0; do
      src="${files2512}/lib/omnissa/$lib"
      if [ -f "$src" ]; then
        cp "$src" "$out/lib/omnissa/$lib"
      fi
    done

    # Smart card support via opensc.
    mkdir -p "$out/lib/omnissa/horizon/pkcs11"
    ln -s ${opensc}/lib/pkcs11/opensc-pkcs11.so \
      "$out/lib/omnissa/horizon/pkcs11/libopenscpkcs11.so"

    runHook postInstall
  '';
}
