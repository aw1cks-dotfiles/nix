{ pkgs }:
pkgs.writeShellApplication {
  name = "paseo-with-password";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.openssl
  ];
  text = ''
    if (( $# < 2 )); then
      echo "Usage: paseo-with-password PASSWORD_FILE COMMAND [ARG...]" >&2
      exit 1
    fi
    password_file=$1
    shift
    umask 077

    if [[ ! -e "$password_file" && ! -L "$password_file" ]]; then
      mkdir -p -- "$(dirname -- "$password_file")"
      temporary=$(mktemp "$password_file.XXXXXX")
      trap 'rm -f -- "$temporary"' EXIT
      openssl rand -hex 32 > "$temporary"
      # Publish the complete secret atomically without replacing a concurrent one.
      if ! ln -T -- "$temporary" "$password_file" 2>/dev/null; then
        [[ -e "$password_file" || -L "$password_file" ]] || exit 1
      fi
      rm -f -- "$temporary"
      trap - EXIT
    fi

    if [[ ! -f "$password_file" || -L "$password_file" || ! -O "$password_file" ]]; then
      echo "Paseo password must be a private, user-owned regular file: $password_file" >&2
      exit 1
    fi
    mode=$(stat -c %a -- "$password_file")
    if (( (8#$mode & 077) != 0 )); then
      echo "Paseo password must be a private, user-owned regular file: $password_file" >&2
      exit 1
    fi
    PASEO_PASSWORD=$(< "$password_file")
    if [[ "$PASEO_PASSWORD" != *[![:space:]]* || "$PASEO_PASSWORD" == *$'\n'* || "$PASEO_PASSWORD" == *$'\r'* ]]; then
      echo "Paseo password must contain one nonempty line: $password_file" >&2
      exit 1
    fi
    # Read data, not shell code; never put the secret in an argument or the store.
    export PASEO_PASSWORD
    exec "$@"
  '';
}
