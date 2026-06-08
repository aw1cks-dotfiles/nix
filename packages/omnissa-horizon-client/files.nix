# Omnissa Horizon Client 2603 file derivation.
#
# Use the multi-arch tarball (same one nixpkgs 26.05's
# omnissa-horizon-client downloads) rather than the .x64-only variant.
# The .x64.tar.gz drops several pieces of the upstream payload that the
# client genuinely needs at runtime:
#
#   - 2603-matched libcrtbora.so / libomnissabase.so / librtavCliLib.so /
#     libudpProxyLib.so and the *mm C++ bindings (atkmm, cairomm, gdkmm,
#     giomm, glibmm, gtkmm, pangomm, sigc). The .x64 layout omits these
#     entirely and previously had to be backfilled from a 2512 tarball,
#     which produced an ABI mismatch with 2603's libclientSdkCPrimitive.so
#     (the latter NEEDs libcrtbora and libomnissabase). That mismatch is
#     the suspected cause of the legacy client's SIGSEGV in
#     CdkBasicHttp_SendRequestEx and the Next client's hang during the
#     P/Invoke into the same SDK at connect time.
#
#   - PCoIP libraries (libpcoip_client.so, libmmfw.a) plus the pcoip/
#     vchan_plugins/ directory required for the actual VDI session
#     protocol once the broker connection is established.
#
# `dontStrip` is critical: `strip -S` corrupts the bundled PE/CLI .NET
# assemblies in lib/omnissa/horizon/bin/horizon-client-next-bundle/, which
# makes CoreCLR fail to load System.Private.CoreLib.dll with
# COR_E_BADIMAGEFORMAT (0x8007000B) when the Next client starts.
{
  stdenv,
  fetchurl,
  opensc,
}:
let
  sysArch =
    if stdenv.hostPlatform.system == "x86_64-linux" then
      "x64"
    else
      throw "Unsupported system: ${stdenv.hostPlatform.system}";
in
stdenv.mkDerivation {
  pname = "omnissa-horizon-files";
  version = "2603";

  dontStrip = true;

  src = fetchurl {
    url = "https://download3.omnissa.com/software/CART27FQ1_LIN_2603_TARBALL/Omnissa-Horizon-Client-Linux-2603-8.18.0-24120621798.tar.gz";
    hash = "sha256:acd30479cec91ee693bbd685880fa3834f3678f8dd336511bb9d732f134f71d7";
  };

  installPhase = ''
    runHook preInstall

    mkdir ext
    find ${sysArch} -type f -print0 | xargs -0n1 tar -Cext --strip-components=1 -xf

    chmod -R u+w ext/usr/lib
    mv ext/usr $out
    cp -r ext/${sysArch}/include $out/
    cp -r ext/${sysArch}/lib $out/

    # Horizon ships its own libstdc++ and chains to it via
    # $libpath/gcc when the host stdc++ is too old. The FHS env always
    # provides a newer libstdc++ via gcc.cc.lib, so the bundled one is
    # at best redundant and at worst tripping the upstream
    # is_glibcxx_compatible probe into the wrong code path.
    rm -f "$out/lib/omnissa/gcc/libstdc++.so.6"

    # NOTE: do NOT remove the bundled libcrypto.so.3 / libssl.so.3 from
    # $out/lib/omnissa/. Initially this looked like the right cleanup
    # (mirrors the libstdc++ removal above, and would let opensc's
    # libopenscpkcs11.so resolve OPENSSL_3.4.0 symbols against the FHS
    # env's openssl). In practice removing it makes libclientSdkCPrimitive.so
    # segfault on the first TLS HTTPS call to the broker
    # (CdkSetLocaleTask), almost certainly because the binary was built
    # against the bundled OpenSSL ABI. Keep the bundle's libcrypto/libssl
    # and tolerate the opensc startup load error until smartcard becomes
    # something we actually need.

    # Smartcard authentication during initial broker connection.
    mkdir -p "$out/lib/omnissa/horizon/pkcs11"
    ln -s ${opensc}/lib/pkcs11/opensc-pkcs11.so \
      "$out/lib/omnissa/horizon/pkcs11/libopenscpkcs11.so"

    runHook postInstall
  '';
}
