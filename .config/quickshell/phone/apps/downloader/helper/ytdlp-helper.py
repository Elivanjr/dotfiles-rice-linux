#!/usr/bin/env python3
"""Auxiliar do app Baixar do celular (yt-dlp).

Uso (o celular chama assim; no terminal também funciona):

    ytdlp-helper.py info URL
    ytdlp-helper.py baixar URL --formato ID [--tem-audio] [--audio] [--pasta DIR]
    ytdlp-helper.py interativo            (o fluxo original, com input())

Saída para o celular: uma mensagem por linha, sempre com prefixo.

    INFO {json}                       resultado de `info`
    PROGRESS pct bytes/s eta etapa total
    STATUS texto                      ex.: juntando vídeo e áudio
    DONE /caminho/do/arquivo
    ERROR mensagem                    a última linha antes de sair com código != 0
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time

try:
    import yt_dlp
except ImportError:
    print("ERROR yt-dlp não está instalado para o python3 (no CachyOS: sudo pacman -S yt-dlp)", flush=True)
    sys.exit(2)

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def emite(prefixo: str, dado=None):
    if dado is None:
        print(prefixo, flush=True)
    else:
        print(f"{prefixo} {dado}", flush=True)


def limpaErro(msg: str) -> str:
    """Tira cores ANSI e o 'ERROR:' do yt-dlp; deixa uma linha só."""
    msg = re.sub(r"\x1b\[[0-9;]*m", "", str(msg))
    msg = re.sub(r"^\s*ERROR:\s*", "", msg.strip())
    msg = " ".join(msg.split())
    return msg[:300] or "Erro desconhecido."


def humano(n) -> str:
    if not n:
        return ""
    n = float(n)
    for unidade in ("B", "KB", "MB", "GB"):
        if n < 1024 or unidade == "GB":
            return f"{n:.0f} {unidade}" if unidade in ("B", "KB") else f"{n:.1f} {unidade}"
        n /= 1024
    return ""


class Logger:
    """Mantém o yt-dlp longe do stdout (que é o nosso protocolo)."""

    def debug(self, msg):
        pass

    def info(self, msg):
        pass

    def warning(self, msg):
        print(f"[aviso] {msg}", file=sys.stderr, flush=True)

    def error(self, msg):
        print(f"[erro] {msg}", file=sys.stderr, flush=True)


def pegaInfoVideo(url: str) -> dict:
    ydl_options = {
        "skip_download": True,
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,       # link com &list=... baixa só o vídeo
        "logger": Logger(),
    }

    with yt_dlp.YoutubeDL(ydl_options) as ydl:
        info = ydl.extract_info(url, download=False)

    if info is None:
        raise yt_dlp.utils.DownloadError("Não consegui obter informações desse link.")

    # link que é só playlist: sem formats no topo
    if info.get("_type") == "playlist" or "formats" not in info:
        raise yt_dlp.utils.DownloadError("Esse link é de uma playlist. Use o link de um vídeo.")

    return info


def temAudio(formato: dict) -> bool:
    return formato.get("acodec") not in (None, "none")


def tamanhoDe(formato: dict):
    return formato.get("filesize") or formato.get("filesize_approx")


def listaFormatos(info: dict) -> list:
    """Um formato de vídeo por resolução (o de maior taxa de bits)."""
    melhores = {}

    for formato in info.get("formats") or []:
        if formato.get("vcodec") in (None, "none"):
            continue

        altura = formato.get("height")

        if not altura:
            continue

        fps = formato.get("fps") or 30
        chave = (altura, fps > 35)       # 1080p e 1080p60 aparecem separados
        peso = formato.get("tbr") or 0
        atual = melhores.get(chave)

        if atual is None or peso > (atual.get("tbr") or 0):
            melhores[chave] = formato

    # tamanho do melhor áudio, para estimar o total (vídeo + áudio)
    tam_audio = 0

    for formato in info.get("formats") or []:
        if formato.get("vcodec") in (None, "none") and temAudio(formato):
            tam_audio = max(tam_audio, tamanhoDe(formato) or 0)

    lista = []

    for (altura, fps_alto), formato in sorted(melhores.items(), reverse=True):
        fps = int(formato.get("fps") or 30)
        nome = f"{altura}p" + (str(fps) if fps_alto else "")
        tem = temAudio(formato)
        tam = tamanhoDe(formato)
        total = (tam + (0 if tem else tam_audio)) if tam else None
        partes = [nome, formato.get("ext") or "?"]

        if total:
            partes.append("~" + humano(total))

        lista.append({
            "id": str(formato["format_id"]),
            "rotulo": " · ".join(partes),
            "temAudio": tem,
        })

    # sem altura nos metadados (link direto de arquivo, por exemplo): deixa o yt-dlp escolher
    if not lista:
        lista.append({"id": "best", "rotulo": "Melhor qualidade disponível", "temAudio": True})

    lista.append({"id": "audio", "rotulo": "Só áudio · mp3", "temAudio": True})

    return lista


def mostraFormatos(formatos: list):
    for formato in formatos:
        print(formato["id"], formato["rotulo"])


def pastaPadrao(so_audio: bool) -> str:
    chave = "MUSIC" if so_audio else "VIDEOS"
    pasta = ""

    try:
        pasta = subprocess.run(
            ["xdg-user-dir", chave], capture_output=True, text=True, timeout=3
        ).stdout.strip()
    except Exception:
        pass

    if not pasta or pasta == os.path.expanduser("~"):
        pasta = os.path.join(os.path.expanduser("~"), "Music" if so_audio else "Videos")

    return pasta


def baixaVideo(url: str, formato: str, pasta: str, tem_audio: bool = False, so_audio: bool = False) -> str:
    precisa_ffmpeg = so_audio or not tem_audio

    if precisa_ffmpeg and not shutil.which("ffmpeg"):
        raise yt_dlp.utils.DownloadError(
            "ffmpeg não encontrado (precisa dele para juntar vídeo e áudio ou converter para mp3)."
        )

    os.makedirs(pasta, exist_ok=True)

    total_etapas = 1 if (so_audio or tem_audio) else 2
    estado = {"etapa": 1, "ultimo": 0.0}

    def progresso(d):
        if d["status"] == "downloading":
            agora = time.monotonic()
            total = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
            baixado = d.get("downloaded_bytes") or 0

            # no máximo ~2 atualizações por segundo, mas nunca pula o fim da etapa
            if agora - estado["ultimo"] < 0.4 and not (total and baixado >= total):
                return

            estado["ultimo"] = agora
            pct = (baixado / total * 100) if total else 0
            emite(
                "PROGRESS",
                f"{pct:.1f} {int(d.get('speed') or 0)} {int(d.get('eta') or -1)} "
                f"{min(estado['etapa'], total_etapas)} {total_etapas}",
            )
        elif d["status"] == "finished":
            estado["etapa"] += 1

    def posprocesso(d):
        if d["status"] == "started":
            nome = d.get("postprocessor", "")
            if nome == "Merger":
                emite("STATUS", "Juntando vídeo e áudio…")
            elif nome == "ExtractAudio":
                emite("STATUS", "Convertendo para mp3…")
            else:
                emite("STATUS", "Finalizando…")

    saida = os.path.join(pasta, "%(title).120B [%(id)s].%(ext)s")

    ydl_options = {
        "outtmpl": saida,
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "noprogress": True,
        "logger": Logger(),
        "progress_hooks": [progresso],
        "postprocessor_hooks": [posprocesso],
    }

    if so_audio:
        ydl_options["format"] = "bestaudio/best"
        ydl_options["postprocessors"] = [
            {"key": "FFmpegExtractAudio", "preferredcodec": "mp3", "preferredquality": "0"}
        ]
    elif tem_audio:
        ydl_options["format"] = formato                       # já vem com áudio
    else:
        ydl_options["format"] = f"{formato}+bestaudio/{formato}"

    with yt_dlp.YoutubeDL(ydl_options) as ydl:
        info = ydl.extract_info(url, download=True)

    baixados = (info or {}).get("requested_downloads") or []

    if baixados and baixados[0].get("filepath"):
        return baixados[0]["filepath"]

    return ydl.prepare_filename(info)


def duracaoTexto(segundos):
    if not segundos:
        return ""

    s = int(segundos)
    h, resto = divmod(s, 3600)
    m, s = divmod(resto, 60)

    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def cmdInfo(url: str) -> int:
    info = pegaInfoVideo(url)
    emite("INFO", json.dumps({
        "titulo": info.get("title") or "(sem título)",
        "canal": info.get("uploader") or info.get("channel") or "",
        "duracao": duracaoTexto(info.get("duration")),
        "aoVivo": bool(info.get("is_live")),
        "formatos": listaFormatos(info),
    }, ensure_ascii=False))
    return 0


def cmdBaixar(args) -> int:
    so_audio = args.audio
    pasta = args.pasta or pastaPadrao(so_audio)
    caminho = baixaVideo(args.url, args.formato or "", pasta, args.tem_audio, so_audio)
    emite("DONE", caminho)
    return 0


def cmdInterativo() -> int:
    url = input("URL: ")
    info = pegaInfoVideo(url)
    print(f"Título: {info.get('title')}")
    print(f"Duração: {duracaoTexto(info.get('duration')) or 'desconhecida'}")
    print(f"Canal: {info.get('uploader') or 'desconhecido'}")
    formatos = listaFormatos(info)
    mostraFormatos(formatos)
    escolha = input("Digite o id do formato: ").strip()
    alvo = next((f for f in formatos if f["id"] == escolha), None)

    if alvo is None:
        print("Formato inválido.")
        return 1

    so_audio = escolha == "audio"
    caminho = baixaVideo(url, escolha, pastaPadrao(so_audio), alvo["temAudio"], so_audio)
    print(f"Salvo em: {caminho}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Auxiliar do app Baixar (yt-dlp)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_info = sub.add_parser("info")
    p_info.add_argument("url")

    p_bx = sub.add_parser("baixar")
    p_bx.add_argument("url")
    p_bx.add_argument("--formato", default="")
    p_bx.add_argument("--tem-audio", action="store_true")
    p_bx.add_argument("--audio", action="store_true")
    p_bx.add_argument("--pasta", default="")

    sub.add_parser("interativo")

    args = ap.parse_args()

    # links começando com "-" virariam opção do yt-dlp
    if getattr(args, "url", "").startswith("-"):
        emite("ERROR", "Link inválido.")
        return 2

    try:
        if args.cmd == "info":
            return cmdInfo(args.url)

        if args.cmd == "baixar":
            return cmdBaixar(args)

        return cmdInterativo()
    except yt_dlp.utils.DownloadError as e:
        emite("ERROR", limpaErro(e))
        return 1
    except KeyboardInterrupt:
        emite("ERROR", "Cancelado.")
        return 130
    except Exception as e:  # noqa: BLE001 — qualquer falha vira uma linha para o celular
        emite("ERROR", limpaErro(f"{type(e).__name__}: {e}"))
        return 1


if __name__ == "__main__":
    sys.exit(main())
