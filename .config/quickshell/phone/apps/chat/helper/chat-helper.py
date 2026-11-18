#!/usr/bin/env python3
# apps/chat/helper/chat-helper.py — ponte TCP do chat do celular (sem SSH)
#
# Uso:
#   chat-helper.py listen <porta>            espera o outro aparelho conectar
#   chat-helper.py connect <ip> <porta>      conecta no outro aparelho (uma tentativa)
#
# stdin  (vindo de ChatApp.qml): uma linha JSON por mensagem  {"m": "texto"}
# stdout (para ChatApp.qml):     uma linha JSON por evento
#                                     {"t": "status", "v": "..."}
#                                     {"t": "msg",    "v": "..."}   (recebida)
#                                     {"t": "erro",   "v": "..."}
# Na rede: uma linha JSON {"m": "texto"} por mensagem, nos dois sentidos.

import json
import socket
import sys
import threading

link_lock = threading.Lock()
link_conn = None


def emit(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def status(texto):
    emit({"t": "status", "v": texto})


def local_ip():
    # não envia pacote nenhum: só descobre qual IP da rede seria usado
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.255.255.255", 1))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except OSError:
        return "?"


def send_text(texto):
    global link_conn
    with link_lock:
        conn = link_conn
    if conn is None:
        emit({"t": "erro", "v": "sem conexão"})
        return
    try:
        conn.sendall((json.dumps({"m": texto}, ensure_ascii=False) + "\n").encode("utf-8"))
    except OSError:
        emit({"t": "erro", "v": "falha ao enviar"})


def serve_peer(conn, addr):
    global link_conn
    with link_lock:
        link_conn = conn
    status("conectado a %s:%d" % (addr[0], addr[1]))

    buf = b""
    try:
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                linha, buf = buf.split(b"\n", 1)
                if not linha.strip():
                    continue
                try:
                    texto = json.loads(linha.decode("utf-8"))["m"]
                except (ValueError, KeyError, TypeError):
                    continue
                emit({"t": "msg", "v": str(texto)})
    except OSError:
        pass
    finally:
        with link_lock:
            link_conn = None
        try:
            conn.close()
        except OSError:
            pass
    status("desconectado")


def run_listen(porta):
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", porta))
    srv.listen(1)
    while True:
        status("aguardando em %s:%d" % (local_ip(), porta))
        conn, addr = srv.accept()
        serve_peer(conn, addr)


def run_connect(host, porta):
    status("conectando em %s:%d" % (host, porta))
    try:
        conn = socket.create_connection((host, porta), timeout=8)
    except OSError as e:
        status("falhou: %s" % (e.strerror or e))
        return
    conn.settimeout(None)
    serve_peer(conn, (host, porta))


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2

    modo = sys.argv[1]
    if modo == "listen":
        porta = int(sys.argv[2])
        rede = threading.Thread(target=run_listen, args=(porta,), daemon=True)
    elif modo == "connect" and len(sys.argv) >= 4:
        rede = threading.Thread(target=run_connect, args=(sys.argv[2], int(sys.argv[3])), daemon=True)
    else:
        print(__doc__, file=sys.stderr)
        return 2

    rede.start()

    # stdin: cada linha é uma mensagem para o outro aparelho
    for linha in sys.stdin:
        try:
            texto = json.loads(linha)["m"]
        except (ValueError, KeyError, TypeError):
            continue
        send_text(str(texto))

    return 0


if __name__ == "__main__":
    sys.exit(main())
