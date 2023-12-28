#!/usr/bin/env bash

read_env_vars() {
  if [[ -n "$PLUGIN_CONFIG" ]]; then
    config="$PLUGIN_CONFIG"
  else
    echo "ERROR: 'settings.config' cannot be empty." >&2
    exit 1
  fi
}

read_env_vars
