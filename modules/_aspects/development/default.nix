# Composite development aspect including all development sub-aspects
{ dl, den, ... }:
{
  dl.development = {
    includes = [
      dl.dev-tools
      dl.dev-ai
      dl.dev-containers
      dl.dev-rust
      dl.dev-kubernetes
      dl.dev-java
    ];
  };
}
