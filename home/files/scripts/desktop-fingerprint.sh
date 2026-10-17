# Run in a terminal from Setup > Fingerprint, or call desktop-fingerprint.
export LC_ALL=C
fingerprint_user=$(id -un)

finish() {
  result=$?
  if (( result != 0 )); then
    printf '\nFingerprint operation failed. Check the message above and try again.\n' >&2
  fi
  if [[ -t 0 ]]; then
    read -r -p $'\nPress Enter to close… ' || true
  fi
  exit "$result"
}
trap finish EXIT

case "${1:-setup}" in
  setup)
    printf 'Enroll a fingerprint. Follow the prompts to select a finger and scan it.\n\n'
    fprintd-enroll "$fingerprint_user"
    printf '\nFollow the verification prompt and scan the requested finger.\n\n'
    fprintd-verify "$fingerprint_user"
    printf '\nFingerprint verified. Use it to unlock the screen, run sudo, and approve administrator prompts.\n'
    ;;
  verify)
    fprintd-verify "$fingerprint_user"
    ;;
  list)
    fprintd-list "$fingerprint_user"
    ;;
  *)
    printf 'Usage: desktop-fingerprint [setup|verify|list]\n' >&2
    exit 2
    ;;
esac
