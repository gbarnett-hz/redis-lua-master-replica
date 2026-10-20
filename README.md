# redis-lua

See what a Redis replica actually receives when the master runs a Lua `EVAL`.

## Run

Requires `redis-server`, `redis-cli` and `python3` on `PATH`.

```sh
./run.sh
```

`run.sh` starts a master on port 7000 and a replica on port 7001 in a temp dir, sends one `EVAL` with reads and writes, then prints:

1. **Raw RESP replication stream.** `stream.py` poses as a second replica (`PSYNC ? -1`), discards the RDB snapshot, and dumps the bytes that follow.
2. **Replica `MONITOR` output.** The commands the real replica executed.

Both servers are shut down and the temp dir is deleted on exit. To try your own script, edit the Lua in `run.sh`.

## What you'll see

```
*1\r\n$5\r\nMULTI\r\n
*2\r\n$6\r\nSELECT\r\n$1\r\n0\r\n
*3\r\n$3\r\nSET\r\n$7\r\ncounter\r\n$2\r\n15\r\n
*2\r\n$4\r\nINCR\r\n$4\r\nhits\r\n
*3\r\n$5\r\nLPUSH\r\n$3\r\nlog\r\n$12\r\nt=1792492328\r\n
*3\r\n$9\r\nPEXPIREAT\r\n$3\r\nlog\r\n$13\r\n1792492388269\r\n
*1\r\n$4\r\nEXEC\r\n
```

- **The script is never sent.** Only its writes are replicated, wrapped in `MULTI`/`EXEC`.
- **Reads are dropped.** `GET`, `MGET` and `TIME` don't appear.
- **Values arrive already computed.** The replica gets `SET counter 15`, not the arithmetic, and the `TIME` result is a plain string.
- **Relative TTLs become absolute.** `EXPIRE 60` is rewritten to `PEXPIREAT <ms>`, so the key expires at the same moment on both servers.

## Notes

- The master runs with `repl-diskless-sync-delay 0`. With the default 5 s delay, `stream.py` gets no snapshot in time and prints nothing.
- If the stream stays open longer than about 10 s you'll also see `PING` and `REPLCONF GETACK` keepalives.
