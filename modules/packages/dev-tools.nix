# Core development tools — from nix-upstream/modules/development/default.nix
# Language-specific tools are in separate modules: ai.nix, containers.nix, java.nix, rust.nix
{ lib, ... }:
{
  flake.modules.home.dev-tools =
    { pkgs, ... }:
    {
      home.packages = with pkgs;
        [
          # build tooling
          cmake
          just

          # dotnet
          dotnet-sdk

          # golang
          delve
          gdlv
          go
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

          # python
          uv
        ]
        # FIXME: this is pulling in a broken version of bazel
        ++ lib.optionals pkgs.stdenv.isLinux [
          protoc-gen-js
        ];
    };
}
