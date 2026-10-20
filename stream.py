"""Pose as a replica, skip the RDB snapshot, print the raw RESP replication stream."""
import socket, sys

s = socket.create_connection(("127.0.0.1", int(sys.argv[1])))
f = s.makefile("rb")
s.sendall(b"PSYNC ? -1\r\n")           # no capa eof -> RDB arrives as $<len>\r\n<bytes>
while not (line := f.readline()).startswith(b"$"):
    pass                               # skip +FULLRESYNC and keepalive newlines
f.read(int(line[1:]))                  # discard RDB (no trailing CRLF)
while chunk := f.read1(4096):
    print(chunk.decode(errors="replace").replace("\r\n", "\\r\\n\n"), end="", flush=True)
