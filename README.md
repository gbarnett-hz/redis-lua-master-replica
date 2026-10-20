# redis-lua

See what a Redis replica actually receives when the master runs a Lua `EVAL`.

## Run

Requires `redis-server` and `redis-cli` on `PATH`.

```sh
./run.sh
```

`run.sh` starts a master on port 7000 and a replica on port 7001 in a temp dir, sends one `EVAL` with reads and writes, then prints:

1. **Replication stream.** `redis-cli --replica` poses as a second replica, discards the RDB snapshot, and prints each command that follows.
2. **Replica `MONITOR` output.** The commands the real replica executed.

Both servers are shut down and the temp dir is deleted on exit. To try your own script, edit the Lua in `run.sh`.

## What you'll see

```
"SELECT","0"
"SET","counter","15"
"INCR","hits"
"LPUSH","log","t=1792492328"
"PEXPIREAT","log","1792492388269"
"EXEC"
```

- **The script is never sent.** Only its writes are replicated, wrapped in `MULTI`/`EXEC`.
- **Reads are dropped.** `GET`, `MGET` and `TIME` don't appear.
- **Values arrive already computed.** The replica gets `SET counter 15`, not the arithmetic, and the `TIME` result is a plain string.
- **Relative TTLs become absolute.** `EXPIRE 60` is rewritten to `PEXPIREAT <ms>`, so the key expires at the same moment on both servers.

## Notes

- The master runs with `repl-diskless-sync-delay 0`. With the default 5 s delay, `redis-cli --replica` gets no snapshot in time and prints nothing.
- `redis-cli --replica` swallows the first command after the sync, so its output is missing the opening `MULTI`. The replica `MONITOR` output shows it.
- If the stream stays open longer than about 10 s you'll also see `PING` and `REPLCONF GETACK` keepalives.
