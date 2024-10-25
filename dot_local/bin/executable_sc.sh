#!/bin/bash
# This script is used to perform a context switch, that means load a specific environment file instead of using a different user.
# Its main purpose is to load env vars, custom aliases, etc.

if [ -z "$1" ]; then
  echo "Usage: sc <context>"
  echo "Current valid contexts are: $(ls -1 ~/.private/.env.d/ | tr '\n' ' ')"
fi

env=~/.private/.env.d/$1

if [ -f "$env" ]; then
  echo Loading $env
  source $env
  export CONTEXT_ENV="$1"
fi
