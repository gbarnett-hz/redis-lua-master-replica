#!/usr/bin/env bash
# Master on 7000, replica on 7001. Sends an EVAL to the master, then shows:
#   1. replication stream the master ships to replicas (redis-cli --replica)
#   2. what the real replica executes (MONITOR on the replica)
set -euo pipefail
cd "$(dirname "$0")"
M=7000 R=7001
D=$(mktemp -d)
trap 'rc=$?; set +e; redis-cli -p $M shutdown nosave 2>/dev/null; redis-cli -p $R shutdown nosave 2>/dev/null; kill $(jobs -p) 2>/dev/null; rm -rf "$D"; exit $rc' EXIT

redis-server --port $M --dir "$D" --save '' --appendonly no --daemonize yes --logfile "$D/m.log" --repl-diskless-sync-delay 0
redis-server --port $R --dir "$D" --save '' --appendonly no --daemonize yes --logfile "$D/r.log" --replicaof 127.0.0.1 $M
until [ "$(redis-cli -p $R info replication | tr -d '\r' | grep master_link_status)" = "master_link_status:up" ]; do sleep 0.1; done

redis-cli -p $M set counter 10 >/dev/null   # seed data before observers attach

redis-cli -p $M --replica 2>/dev/null > "$D/stream.txt" &
redis-cli -p $R monitor > "$D/monitor.txt" &
sleep 0.5

echo "== EVAL on master"
redis-cli -p $M eval '
  local c = tonumber(redis.call("GET", KEYS[1]))      -- read
  redis.call("SET", KEYS[1], c + tonumber(ARGV[1]))   -- write
  redis.call("INCR", KEYS[2])                         -- write
  redis.call("LPUSH", KEYS[3], "t=" .. redis.call("TIME")[1]) -- non-deterministic write
  redis.call("EXPIRE", KEYS[3], 60)                   -- relative TTL
  return redis.call("MGET", KEYS[1], KEYS[2])         -- read
' 3 counter hits log 5

sleep 1
echo; echo "== replication stream master -> replica"; cat "$D/stream.txt"
echo; echo "== replica MONITOR";                 cat "$D/monitor.txt"
