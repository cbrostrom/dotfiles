# shellcheck shell=bash
# Load host-local Paseo daemon credentials for unattended install / fleet-update.
# Copy sources/paseo/fleet-env.example to ~/.paseo/fleet-env (chmod 600).

PASEO_FLEET_ENV="${PASEO_HOME:-$HOME/.paseo}/fleet-env"
if [[ -f "$PASEO_FLEET_ENV" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$PASEO_FLEET_ENV"
    set +a
fi
