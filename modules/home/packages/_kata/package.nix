{ pkgs }:
(pkgs.buildGoModule.override { go = pkgs.go_1_27; }) {
  pname = "kata";
  version = "0.23.0";
  # The dedicated release archive includes production web assets and vendor/;
  # the Git tag archive contains only a development web stub.
  src = pkgs.fetchzip {
    url = "https://github.com/kenn-io/kata/releases/download/v0.23.0/kata_0.23.0_source.tar.gz";
    hash = "sha256-mQRKbx/V1QiPr4/SnPZOngaiXWAEp6KtDidD++OdnJw=";
  };
  patches = [ ./browser-auth.patch ];
  vendorHash = null;
  subPackages = [ "cmd/kata" ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
    "-X go.kenn.io/kata/internal/version.Version=v0.23.0"
    "-X go.kenn.io/kata/internal/version.Commit=dab18320428ce1fbf7b2e619aa6e6707520b4913"
    "-X go.kenn.io/kata/internal/version.BuildDate=2026-11-09T11:49:11Z"
    "-X go.kenn.io/kata/internal/version.Distribution=nixpkgs"
    "-X go.kenn.io/kit/telemetry/posthog.distribution=nixpkgs"
    # Public upstream ingestion key, shared by release/package-manager builds.
    "-X go.kenn.io/kit/telemetry/posthog.projectKey=phc_AzHd9YvuHR7M5poKzC6eW654d3SgKyBdoQPuwkWhimUf"
  ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    go test -mod=vendor ./internal/daemon -run '^TestWebEndpointAllowsLocalSessionForDirectLoopback$' -count=1
    runHook postCheck
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/kata" --version
    "$out/bin/kata" _web-assets-check
    runHook postInstallCheck
  '';
  meta = {
    description = "Local-first issue tracker with a CLI, daemon and web UI";
    homepage = "https://github.com/kenn-io/kata";
    license = pkgs.lib.licenses.mit;
    mainProgram = "kata";
    platforms = pkgs.lib.platforms.unix;
  };
}
