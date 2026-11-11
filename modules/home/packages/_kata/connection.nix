{
  stateDirectory,
  listenAddress,
  port,
}:
let
  address = if listenAddress == "::1" then "[::1]" else listenAddress;
  endpoint = "${address}:${toString port}";
in
{
  inherit endpoint;
  environment = {
    KATA_HOME = stateDirectory;
    KATA_DSN = "${stateDirectory}/kata.db";
    KATA_DB = "${stateDirectory}/kata.db";
    KATA_SERVER = "http://${endpoint}";
    KATA_AUTH_TOKEN_FILE = "${stateDirectory}/auth-token";
    # Inline credentials take precedence upstream; use only the selected file.
    KATA_AUTH_TOKEN = "";
  };
}
