#!/bin/bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

C_OK=''
C_SKIP=''
C_FAIL=''
C_SECT=''
RESET=''
if [ -t 2 ]; then
  C_OK=$'\033[32m'
  C_SKIP=$'\033[33m'
  C_FAIL=$'\033[31m'
  C_SECT=$'\033[1;95m'
  RESET=$'\033[0m'
fi

VAGRANT_DIR="$HOME/shared/infra/vagrant"

usage() {
  cat <<'EOF'
vvm — Manage Vagrant environments

Usage:
  vvm [OPTIONS] <action> [env ...]

Options:
  -h            Show this help
  --dir <path>  Use <path> as the Vagrant folder (default ~/shared/infra/vagrant)
  --list        Print detected env names, one per line
  --preview <env>
                Print an env's info block (for fzf)
  --fzf         Open the environment picker instead

Actions:
  status        per-env state, one "env<TAB>state" per line
  up | halt | suspend | resume | reload | provision
  ssh           requires exactly one env
  validate      check the Vagrantfile (no VM touch)
  destroy       confirmed, then vagrant destroy -f
  rebuild       confirmed, then destroy -f + up
  snapshot      save <env> <name> | ls [env] | restore <env> <name> | delete <env> <name>

Examples:
  vvm                    # fzf picker (same as vvm --fzf)
  vvm status             # all detected envs
  vvm up zbxserver       # one env
  vvm --dir /mnt/vagrant status   # a different Vagrant folder
  vvm rebuild zbxserver  # destroy + up (asks)

Notes:
  Detects envs from the Vagrant folder (dirs with a Vagrantfile).
  no env given -> all detected; given names are validated (unknown => error,
  nothing runs). --list/--preview print data only to stdout; status chatter
  goes to stderr.
  Requires: Vagrant; fzf (for the picker).
  Exit codes: 0 = all ok, 1 = one or more envs failed, 2 = usage error.
EOF
  exit "${1:-0}"
}

die() {
  echo "vvm: $1" >&2
  exit "${2:-1}"
}

usage_error() {
  echo "vvm: $1 (see vvm -h)" >&2
  exit 2
}

detect_envs() {
  local d
  ENVS=()
  [[ -d "$VAGRANT_DIR" ]] || die "vagrant dir not found: $VAGRANT_DIR" 1
  for d in "$VAGRANT_DIR"/*/; do
    [[ -d "$d" ]] || continue
    [[ -f "$d/Vagrantfile" ]] || continue
    ENVS+=("$(basename "$d")")
  done
  ((${#ENVS[@]} > 0)) || die "no environments detected in $VAGRANT_DIR" 1
}

is_env() {
  local e
  for e in "${ENVS[@]}"; do
    [[ "$e" == "$1" ]] && return 0
  done
  return 1
}

resolve_targets() {
  local e
  TARGETS=()
  if (($# > 0)); then
    for e in "$@"; do
      if is_env "$e"; then
        TARGETS+=("$e")
      else
        echo "vvm: unknown env: $e (known: ${ENVS[*]})" >&2
        exit 2
      fi
    done
  else
    TARGETS=("${ENVS[@]}")
  fi
}

env_state() {
  local out
  out=$( (cd "$VAGRANT_DIR/$1" && vagrant status 2>/dev/null) |
        awk '$1 == "default" && /\([^)]*\)$/ { if ($2 == "not") print "not created"; else print $2 }' )
  echo "${out:-unknown}"
}

warn_confirm() {
  local env=$1 op=$2 ans
  [[ "$(env_state "$env")" == "not created" ]] && {
    echo "  ${C_SKIP}[skip]$RESET $env is not created - nothing to $op" >&2
    return 1
  }
  echo "vvm: $op is destructive - removes the '$env' machine" >&2
  read -r -p "  $op $env? [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || {
    echo "  aborted" >&2
    return 1
  }
}

run_env() {
  ( cd "$VAGRANT_DIR/$1" && vagrant "${@:2}" )
}

do_run() {
  local action=$1
  shift
  local i=0 e ok=0 fail=0 skip=0
  detect_envs
  resolve_targets "$@"

  for e in "${TARGETS[@]}"; do
    i=$((i + 1))
    if ((${#TARGETS[@]} > 1)); then
      echo "=== $e ($i/${#TARGETS[@]}) ===" >&2
    fi

    if [[ "$action" == "destroy" || "$action" == "rebuild" ]] && \
       ! warn_confirm "$e" "$action"; then
      skip=$((skip + 1))
      continue
    fi

    if [[ "$action" == "rebuild" ]]; then
      if run_env "$e" destroy -f && run_env "$e" up; then
        ok=$((ok + 1)); echo "  ${C_OK}[ok]$RESET $e rebuild" >&2
      else
        fail=$((fail + 1)); echo "  ${C_FAIL}[fail]$RESET $e rebuild" >&2
      fi
    elif run_env "$e" "$action"; then
      ok=$((ok + 1)); echo "  ${C_OK}[ok]$RESET $e $action" >&2
    else
      fail=$((fail + 1)); echo "  ${C_FAIL}[fail]$RESET $e $action" >&2
    fi
  done

  echo "vvm: done - ${C_OK}ok $ok$RESET, ${C_FAIL}fail $fail$RESET, ${C_SKIP}skipped $skip$RESET" >&2
  ((fail == 0))
}

cmd_status() {
  local e
  detect_envs
  resolve_targets "$@"
  for e in "${TARGETS[@]}"; do
    printf '%s\t%s\n' "$e" "$(env_state "$e")"
  done
}

cmd_list() {
  detect_envs
  printf '%s\n' "${ENVS[@]}"
}

cmd_preview() {
  local env=$1 vf host ip box provider cpus mem state
  detect_envs
  is_env "$env" || usage_error "unknown env: $env"
  vf="$VAGRANT_DIR/$env/Vagrantfile"
  host=$(    sed -n 's/.*config\.vm\.hostname *= *"\([^"]*\)".*/\1/p' "$vf" | head -1)
  ip=$(      sed -n 's/.*config\.vm\.network *"private_network".*ip: *"\([^"]*\)".*/\1/p' "$vf" | head -1)
  box=$(     sed -n 's/.*config\.vm\.box *= *"\([^"]*\)".*/\1/p' "$vf" | head -1)
  provider=$(sed -n 's/.*config\.vm\.provider *"\([^"]*\)".*/\1/p' "$vf" | head -1)
  cpus=$(    sed -n 's/.*vb\.cpus *= *\([0-9]*\).*/\1/p' "$vf" | head -1)
  mem=$(     sed -n 's/.*vb\.memory *= *\([0-9]*\).*/\1/p' "$vf" | head -1)
  state=$(   env_state "$env")
  printf '%-10s %s\n' "ENV"      "$env"
  printf '%-10s %s\n' "STATE"    "${state:-unknown}"
  printf '%-10s %s\n' "HOSTNAME" "${host:-unknown}"
  printf '%-10s %s\n' "IP"       "${ip:-unknown}"
  printf '%-10s %s\n' "BOX"      "${box:-unknown}"
  printf '%-10s %s\n' "PROVIDER" "${provider:-unknown}"
  printf '%-10s %s\n' "CPU"      "${cpus:-unknown}"
  printf '%-10s %s\n' "MEM"      "$([[ -n "${mem:-}" ]] && echo "${mem}MB" || echo unknown)"
}

cmd_ssh() {
  local e
  [[ $# -eq 1 ]] || usage_error "ssh requires exactly one env"
  e=$1
  detect_envs
  is_env "$e" || usage_error "unknown env: $e"
  run_env "$e" ssh
}

cmd_snapshot() {
  local verb=${1:-} env name
  detect_envs
  case "$verb" in
    save)
      [[ $# -eq 3 ]] || usage_error "snapshot save requires: <env> <name>"
      env=$2; name=$3
      is_env "$env" || usage_error "unknown env: $env"
      run_env "$env" snapshot save "$name" ;;
    ls)
      if [[ $# -eq 2 ]]; then
        env=$2
        is_env "$env" || usage_error "unknown env: $env"
        run_env "$env" snapshot list
      else
        local e
        for e in "${ENVS[@]}"; do
          echo "== $e ==" >&2
          run_env "$e" snapshot list
        done
      fi ;;
    restore)
      [[ $# -eq 3 ]] || usage_error "snapshot restore requires: <env> <name>"
      env=$2; name=$3
      is_env "$env" || usage_error "unknown env: $env"
      run_env "$env" snapshot restore "$name" ;;
    delete)
      [[ $# -eq 3 ]] || usage_error "snapshot delete requires: <env> <name>"
      env=$2; name=$3
      is_env "$env" || usage_error "unknown env: $env"
      read -r -p "  delete snapshot '$name' from $env? [y/N] " ans
      [[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "  aborted" >&2; return 0; }
      run_env "$env" snapshot delete "$name" ;;
    *)
      usage_error "snapshot: unknown verb '${verb:-}' (save|ls|restore|delete)" ;;
  esac
}

run_banner() {
  clear 2>/dev/null || true
  printf '%s\n' "${C_SECT}── $1 : $2 ──${RESET}" >&2
  printf '\n' >&2
}

fzf_pick() {
  local sel env verb snap
  clear 2>/dev/null || true
  mapfile -t sel < <(
    printf '%s\n' "${ENVS[@]}" |
    fzf --layout=reverse --prompt='v> ' --info=inline \
        --marker='┃' --pointer='▸' --color='marker:green,pointer:white' \
        --header='enter = pick env · esc = quit' \
        --preview-window='right:45%' \
        --preview="${SCRIPT_DIR}/vvm.sh --dir '$VAGRANT_DIR' --preview {}"
  )
  ((${#sel[@]})) || return 130
  read -r env _rest <<< "${sel[0]}"
  is_env "$env" || die "internal: picked unknown env '$env'" 1

  while true; do
    mapfile -t sel < <(
      printf '%s\n' \
        'status        per-env state' \
        'up            create + boot' \
        'halt          shutdown OS' \
        'suspend       freeze' \
        'resume        unfreeze' \
        'reload        reboot' \
        'provision     re-run provisioner' \
        'validate      check Vagrantfile' \
        'ssh           SSH in' \
        'destroy       delete VM (asks)' \
        'rebuild       destroy + up (asks)' \
        'snapshot      save | ls | restore | delete' |
      fzf --layout=reverse --prompt='v> ' --info=inline \
          --marker='┃' --pointer='▸' --color='marker:green,pointer:white' \
          --header="$env :: select action · esc = back" \
          --delimiter=' ' --with-nth=1
    )
    ((${#sel[@]})) || return 3
    read -r verb _rest <<< "${sel[0]}"

    if [[ "$verb" != "snapshot" ]]; then
      run_banner "$env" "$verb"
      if [[ "$verb" == "status" ]]; then
        cmd_status "$env"
      else
        do_run "$verb" "$env"
      fi
      return $?
    fi

    while true; do
      mapfile -t sel < <(
        printf '%s\n' 'save' 'ls' 'restore' 'delete' |
        fzf --layout=reverse --prompt='v> snapshot ' --info=inline \
            --marker='┃' --pointer='▸' --color='marker:green,pointer:white' \
            --header="$env :: select action · esc = back"
      )
      ((${#sel[@]})) || break
      read -r verb _rest <<< "${sel[0]}"
      case "$verb" in
        ls)
          run_banner "$env" "snapshot ls"
          cmd_snapshot ls "$env"
          return $? ;;
        save|restore|delete)
          read -r -p "  snapshot name: " snap
          [[ -n "$snap" ]] || { echo "vvm: no snapshot name" >&2; continue; }
          run_banner "$env" "snapshot $verb $snap"
          cmd_snapshot "$verb" "$env" "$snap"
          return $? ;;
      esac
    done
  done
}

picker() {
  command -v fzf >/dev/null 2>&1 || die "fzf is not installed (install.sh provides it)" 1
  detect_envs
  local st
  while true; do
    fzf_pick
    st=$?
    ((st == 130)) && return 130
    ((st == 3)) && continue
    printf '%s\n' '' "[enter] continue" >&2
    read -r _
  done
}

main() {
  local action args=()
  while (($# > 0)); do
    case "$1" in
      --dir) [[ $# -ge 2 && -n "$2" ]] || usage_error "--dir requires a path"
             VAGRANT_DIR="$2"; shift 2 ;;
      --dir=*) [[ -n "${1#*=}" ]] || usage_error "--dir requires a path"
                VAGRANT_DIR="${1#*=}"; shift ;;
      *) args+=("$1"); shift ;;
    esac
  done
  set -- "${args[@]}"

  action=${1:-}
  shift || true
  case "$action" in
    "" | --fzf)  picker ;;
    -h|--help)   usage 0 ;;
    --list)       cmd_list ;;
    --preview)    [[ $# -eq 1 ]] || usage_error "--preview requires one env"; cmd_preview "$1" ;;
    status)       cmd_status "$@" ;;
    up|halt|suspend|resume|reload|provision|validate|destroy|rebuild)
                  do_run "$action" "$@" ;;
    ssh)          cmd_ssh "$@" ;;
    snapshot)     cmd_snapshot "$@" ;;
    *)            usage_error "unknown action: '$action'" ;;
  esac
}

main "$@"