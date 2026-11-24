"""Run the Open Agent Connector API on one dual-stack socket ([::]:PORT, IPv4 and IPv6).

uvicorn's own --host :: sets IPV6_V6ONLY, so IPv4 callers on Railway's private network
would be refused. Exits non-zero if the app fails to start, so Railway restarts it.
"""
import os
import socket
import sys

import uvicorn

port = int(os.environ.get("PORT", "8000"))
sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
sock.bind(("::", port))
sock.set_inheritable(True)

config = uvicorn.Config(
    "main:app",
    workers=1,
    server_header=False,
    proxy_headers=False,
    timeout_graceful_shutdown=5,
    log_level=os.environ.get("LOG_LEVEL", "info").lower(),
)
server = uvicorn.Server(config)
server.run(sockets=[sock])
if not server.started:
    sys.exit(3)
