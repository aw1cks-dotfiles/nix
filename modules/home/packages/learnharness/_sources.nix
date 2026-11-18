let
  version = "0.6.1";
  releases = "https://github.com/amosblomqvist/learnharness/releases";
  download = "${releases}/download/v${version}/LearnHarness-${version}";
in
{
  inherit version;
  changelog = "${releases}/tag/v${version}";
  artifacts = {
    aarch64-darwin = {
      url = "${download}-arm64.dmg";
      hash = "sha256-vyJTYa907nv2JCOKEjr9aObP1vc2Tjwj880rh5+l9SQ=";
    };
    x86_64-linux = {
      url = "${download}-x86_64.AppImage";
      hash = "sha256-uKAz63QhZ3iT2W5JiLMBU/3+T8bw3EVveUcWG7oEG5g=";
    };
  };
}
