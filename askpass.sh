#!/bin/sh
# git credential prompt: answer with GIT_TOKEN so private https repos clone without the token in any URL or config.
case "$1" in
  Username*) echo "x-access-token" ;;
  *) echo "${GIT_TOKEN:-}" ;;
esac
