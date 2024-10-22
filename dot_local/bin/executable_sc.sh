#!/bin/bash

env=~/.private/.env.d/$1

if [ -f "$env" ]; then
  echo Loading $env
  source $env
  export CONTEXT_ENV=$1
fi
