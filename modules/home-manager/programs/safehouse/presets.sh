# Included by the shared safe wrapper. Local presets extend --enable while
# built-in feature names are passed through to Safehouse.
# Usage: safe --enable=aws aws ...
#        codex --safehouse --enable=aws --
safehouse_args=()
safehouse_aws_enabled=0
safehouse_uses_full_env=0
safehouse_command_started=0

safehouse_expand_features() {
  local feature
  local -a features=()
  IFS=, read -r -a features <<< "$1"

  for feature in "${features[@]}"; do
    feature="${feature#"${feature%%[![:space:]]*}"}"
    feature="${feature%"${feature##*[![:space:]]}"}"
    case "${feature,,}" in
      aws)
        safehouse_aws_enabled=1
        ;;
      *)
        safehouse_args+=("--enable=$feature")
        ;;
    esac
  done
}

while [ "$#" -gt 0 ]; do
  # Safehouse consumes runtime environment flags even after a command starts,
  # unless an explicit -- ended option parsing before the command.
  case "$1" in
    --env)
      safehouse_uses_full_env=1
      safehouse_args+=("$1")
      shift
      continue
      ;;
    --env-pass)
      [ "$#" -ge 2 ] || break
      safehouse_args+=("$1" "$2")
      shift 2
      continue
      ;;
  esac

  if [ "$safehouse_command_started" = 1 ]; then
    safehouse_args+=("$1")
    shift
    continue
  fi

  case "$1" in
    --enable)
      # Leave missing-value errors to Safehouse.
      [ "$#" -ge 2 ] || break
      safehouse_expand_features "$2"
      shift 2
      ;;
    --enable=*)
      safehouse_expand_features "${1#*=}"
      shift
      ;;
    --add-dirs-ro|--add-dirs|--workdir|--append-profile|--output)
      [ "$#" -ge 2 ] || break
      safehouse_args+=("$1" "$2")
      shift 2
      ;;
    --)
      break
      ;;
    -*)
      safehouse_args+=("$1")
      shift
      ;;
    *)
      safehouse_command_started=1
      safehouse_args+=("$1")
      shift
      ;;
  esac
done

if [ "$safehouse_aws_enabled" = 1 ] && [ "$safehouse_uses_full_env" != 1 ]; then
  # --env already inherits these variables and conflicts with --env-pass.
  safehouse_args+=("--env-pass=AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY,AWS_SESSION_TOKEN,AWS_REGION,AWS_DEFAULT_REGION")
fi
