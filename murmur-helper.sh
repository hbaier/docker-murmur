#!/bin/sh

set -e

command=$@

signal_handler() {
  kill -TERM $child
  wait $child

  exit 0
}

trap signal_handler SIGINT SIGTERM

$command &

child=$!
wait $child

exit 1
