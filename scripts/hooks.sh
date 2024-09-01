#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables
# Provides default implementation of user hooks

bootable::user::config_load::post() { true; }
bootable::user::sysprep::pre() { true; }
bootable::user::sysprep::post() { true; }
