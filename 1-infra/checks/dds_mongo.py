#!/usr/bin/env python3
"""Verify DDS connectivity and authentication via pymongo."""
import os
import re
import struct
import sys
import socket
import threading

from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, OperationFailure

dds_host = os.environ.get('DDS_HOST', '')
dds_port = int(os.environ.get('DDS_PORT', '8635'))
dds_password = os.environ.get('DDS_PASSWORD', '')

if not dds_host or not dds_password:
    print("DDS_HOST or DDS_PASSWORD not set")
    sys.exit(1)

proxy_host = None
proxy_port = None
proxy_label = 'none (direct)'
for var in ('HTTPS_PROXY', 'https_proxy', 'ALL_PROXY', 'all_proxy'):
    m = re.match(r'socks5h?://([^:]+):(\d+)', os.environ.get(var, ''))
    if m:
        proxy_host = m.group(1)
        proxy_port = int(m.group(2))
        proxy_label = f"socks5://{proxy_host}:{proxy_port}"
        break

print(f"  proxy: {proxy_label}", flush=True)


def _socks5_connect(proxy_h, proxy_p, target_h, target_p):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((proxy_h, proxy_p))
    s.sendall(b'\x05\x01\x00')                         # greeting: no-auth
    if s.recv(2) != b'\x05\x00':
        raise ConnectionError("SOCKS5 auth negotiation failed")
    host_bytes = target_h.encode()
    s.sendall(
        struct.pack('!BBBB', 5, 1, 0, 3)               # VER CMD RSV ATYP=domain
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
        print(f"  tunnel error: {e}", flush=True)
        conn.close()
        return
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
    print(f"  tunnel: 127.0.0.1:{local_port} -> {proxy_label} -> {dds_host}:{dds_port}", flush=True)

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
    f"mongodb://rwuser:{dds_password}@{connect_host}:{connect_port}/admin"
    f"?authSource=admin&tls=true&tlsAllowInvalidCertificates=true&directConnection=true"
)
print(f"  uri: mongodb://rwuser:***@{connect_host}:{connect_port}/admin"
      f"?authSource=admin&tls=true&tlsAllowInvalidCertificates=true&directConnection=true", flush=True)

try:
    client = MongoClient(uri, serverSelectionTimeoutMS=10000)
    result = client.admin.command('ping')
    if result.get('ok') == 1.0:
        print("ping ok")
        sys.exit(0)
    print(f"unexpected ping result: {result}")
    sys.exit(1)
except (ConnectionFailure, OperationFailure) as e:
    msg = str(e)
    if 'timed out' in msg.lower() and proxy_host:
        msg += f' (hint: is the SOCKS tunnel active at {proxy_label}?)'
    print(msg)
    sys.exit(1)
