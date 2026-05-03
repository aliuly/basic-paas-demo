#!/usr/bin/env python3
"""
Verify DDS connectivity using the app user credentials.
Used by checks/mern-demo (check 8).

Required env vars:
  DDS_HOST, DDS_PORT, DDS_PASSWORD  — from mern-dds secret
  DDS_USER                          — app username (bezkoder)
  DDS_AUTH_DB                       — database to authenticate against
  HTTPS_PROXY (optional)            — socks5://host:port tunnel
"""
import os
import re
import struct
import sys
import socket
import threading

from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, OperationFailure

dds_host   = os.environ.get('DDS_HOST', '')
dds_port   = int(os.environ.get('DDS_PORT', '8635'))
dds_pass   = os.environ.get('DDS_PASSWORD', '')
dds_user   = os.environ.get('DDS_USER', '')
dds_authdb = os.environ.get('DDS_AUTH_DB', '')

for var, val in [('DDS_HOST', dds_host), ('DDS_PASSWORD', dds_pass),
                 ('DDS_USER', dds_user), ('DDS_AUTH_DB', dds_authdb)]:
    if not val:
        print(f"ERROR: {var} not set", file=sys.stderr)
        sys.exit(1)

proxy_host = proxy_port = None
for var in ('HTTPS_PROXY', 'https_proxy', 'ALL_PROXY', 'all_proxy'):
    m = re.match(r'socks5h?://([^:]+):(\d+)', os.environ.get(var, ''))
    if m:
        proxy_host, proxy_port = m.group(1), int(m.group(2))
        break


def _socks5_connect(proxy_h, proxy_p, target_h, target_p):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((proxy_h, proxy_p))
    s.sendall(b'\x05\x01\x00')
    if s.recv(2) != b'\x05\x00':
        raise ConnectionError("SOCKS5 auth negotiation failed")
    host_bytes = target_h.encode()
    s.sendall(
        struct.pack('!BBBB', 5, 1, 0, 3)
        + bytes([len(host_bytes)]) + host_bytes
        + struct.pack('!H', target_p)
    )
    resp = s.recv(256)
    if len(resp) < 2 or resp[1] != 0:
        code = resp[1] if len(resp) > 1 else '?'
        raise ConnectionError(f"SOCKS5 CONNECT refused (code {code})")
    return s


def _pipe(src, dst):
    try:
        while True:
            data = src.recv(4096)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for sock in (src, dst):
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass


def _handle(conn, proxy_h, proxy_p, target_h, target_p):
    try:
        remote = _socks5_connect(proxy_h, proxy_p, target_h, target_p)
    except Exception as e:
        conn.close()
        raise
    t = threading.Thread(target=_pipe, args=(remote, conn), daemon=True)
    t.start()
    _pipe(conn, remote)
    t.join()


if proxy_host:
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(('127.0.0.1', 0))
    listener.listen(5)
    local_port = listener.getsockname()[1]

    def _accept_loop():
        while True:
            try:
                conn, _ = listener.accept()
            except OSError:
                break
            threading.Thread(
                target=_handle,
                args=(conn, proxy_host, proxy_port, dds_host, dds_port),
                daemon=True,
            ).start()

    threading.Thread(target=_accept_loop, daemon=True).start()
    connect_host, connect_port = '127.0.0.1', local_port
else:
    connect_host, connect_port = dds_host, dds_port

uri = (
    f"mongodb://{dds_user}:{dds_pass}@{connect_host}:{connect_port}/{dds_authdb}"
    f"?authSource=admin&tls=true&tlsAllowInvalidCertificates=true&directConnection=true"
)

try:
    client = MongoClient(uri, serverSelectionTimeoutMS=10000)
    result = client[dds_authdb].command('ping')
    if result.get('ok') == 1.0:
        print("ping ok")
        sys.exit(0)
    print(f"unexpected ping result: {result}")
    sys.exit(1)
except (ConnectionFailure, OperationFailure) as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
