# Core development tools — from nix-upstream/modules/development/default.nix
# Language-specific tools are in separate modules: ai.nix, containers.nix, java.nix, rust.nix
{ inputs, lib, ... }:
{
  aw1cks.modules.home.dev-tools =
    { config, pkgs, ... }:
    let
      mmdr = import ./_mermaid.nix {
        inherit inputs lib;
      } pkgs;
    in
    {
      home.packages =
        with pkgs;
        [
          # build tooling
          cmake
          just
          mmdr

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
