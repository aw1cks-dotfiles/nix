# Core development tools — from nix-upstream/modules/development/default.nix
# Language-specific tools are in separate modules: ai.nix, containers.nix, java.nix, rust.nix
{ lib, ... }:
{
  flake.modules.home.dev-tools =
    { config, pkgs, ... }:
    {
      home.packages =
        with pkgs;
        [
          # build tooling
          cmake
          just

          # dotnet
          dotnet-sdk

          # golang
          delve
          gdlv
          gore

          # js
          bun
          nodejs_22
          typescript
          yarn-berry

          # protobuf — needed for various codegen
          protobuf
          protoc-gen-go
          protoc-gen-go-grpc
          protoc-gen-prost
          protoc-gen-prost-crate
          protoc-gen-prost-serde
          protoc-gen-rust
          protoc-gen-rust-grpc
          protoc-gen-tonic
        ]
        # FIXME: this is pulling in a broken version of bazel on macOS
        ++ lib.optionals pkgs.stdenv.isLinux [
          protoc-gen-js
        ];

      programs = {
        go = {
          enable = true;
          env = {
            GOPATH = [ "${config.xdg.dataHome}/go" ];
          };
        };
        # rizin.enable = true;
        uv = {
          enable = true;
          settings = {
            native-tls = true;
          };
        };
      };
    };
}
