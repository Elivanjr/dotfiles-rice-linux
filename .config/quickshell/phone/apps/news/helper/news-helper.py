#!/usr/bin/env python3
"""Coletor RSS para o Quickshell Phone.

Comandos:
  news-helper.py init [--recriar]
  news-helper.py fetch [--max-age 900] [--force]

Saída de fetch (uma linha):
  NEWS {"itens": [...], "erros": [...], "geradoEm": 0, "doCache": false}
ou
  ERROR mensagem
"""

from __future__ import annotations

import argparse
import email.utils
import html
import json
import re
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

APP_DIR = Path.home() / ".config" / "quickshell-phone"
FEEDS_FILE = APP_DIR / "news-feeds.json"
CACHE_FILE = APP_DIR / "news-cache.json"
CACHE_VERSAO = 2
USER_AGENT = "QuickshellPhone-NewsReader/1.0 (+RSS reader)"
MAX_FEED_BYTES = 4 * 1024 * 1024

TOPICOS = ["tecnologia", "jogos", "animes", "politica", "linux"]

# Palavras que tiram a notícia da lista (comparação sem acento e sem maiúscula).
# Edite a lista "excluir" em news-feeds.json para mudar.
EXCLUIR_PADRAO = [
    "bbb", "big brother", "fofoca", "famoso", "famosa", "famosos",
    "celebridade", "celebridades", "novela", "novelas", "reality",
    "divas", "diva", "namoro", "namora", "casamento", "cantor",
    "cantora", "atriz", "atores", "ator", "musica", "musical",
    "album", "gshow", "pop & arte",
]

DEFAULT_FEEDS = {
    "topicos": TOPICOS,
    "excluir": EXCLUIR_PADRAO,
    "feeds": [
        {"fonte": "Tecnoblog", "topico": "tecnologia", "url": "https://tecnoblog.net/feed/"},
        {"fonte": "Phoronix", "topico": "tecnologia", "url": "https://www.phoronix.com/rss.php"},
        {"fonte": "It's FOSS", "topico": "tecnologia", "url": "https://itsfoss.com/feed/"},
        {"fonte": "G1 Tecnologia", "topico": "tecnologia", "url": "http://pox.globo.com/rss/g1/tecnologia/"},
        {"fonte": "Tecnoblog Jogos", "topico": "jogos", "url": "https://tecnoblog.net/tema/jogos/feed"},
        {"fonte": "Viva o Linux", "topico": "linux", "url": "https://www.vivaolinux.com.br/index.rdf"},
        {"fonte": "VOL Fórum", "topico": "linux", "url": "https://www.vivaolinux.com.br/forum.rdf"},
        {"fonte": "Linux Journal", "topico": "linux", "url": "https://www.linuxjournal.com/node/feed"},
        {"fonte": "LXer", "topico": "linux", "url": "https://lxer.com/module/newswire/headlines.rss"},
        {"fonte": "Anime News Network", "topico": "animes", "url": "https://www.animenewsnetwork.com/all/rss.xml"},
        {"fonte": "G1 Política", "topico": "politica", "url": "https://g1.globo.com/rss/g1/politica/"},
        {"fonte": "Agência Brasil", "topico": "politica", "url": "https://agenciabrasil.ebc.com.br/rss/geral/feed.xml"},
        {"fonte": "BBC Brasil", "topico": "politica", "url": "https://feeds.bbci.co.uk/portuguese/brasil/rss.xml"},
        {"fonte": "BBC Mundo", "topico": "politica", "url": "https://feeds.bbci.co.uk/portuguese/internacional/rss.xml"},
    ],
}


def clean_html(value: str | None) -> str:
    """Remove tags e normaliza entidades/espaços de um resumo RSS."""
    if not value:
        return ""
    value = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", value)
    value = re.sub(r"(?s)<[^>]+>", " ", value)
    value = html.unescape(value)
    return re.sub(r"\s+", " ", value).strip()


def local_name(tag: str) -> str:
    """'{http://...}title' -> 'title'. Assim RSS 1.0 (RDF), RSS 2.0 e Atom funcionam."""
    return tag.rsplit("}", 1)[-1]


def child_text(element: ET.Element, names: tuple[str, ...]) -> str:
    # respeita a ordem de preferência de 'names'
    for name in names:
        wanted = local_name(name)
        for child in element:
            if local_name(child.tag) == wanted and child.text and child.text.strip():
                return child.text.strip()
    return ""


def parse_date(value: str) -> int:
    if not value:
        return 0
    try:
        parsed = email.utils.parsedate_to_datetime(value)
        return int(parsed.timestamp())
    except (TypeError, ValueError, OverflowError):
        pass

    # Alguns feeds usam datas ISO 8601.
    try:
        from datetime import datetime

        normalized = value.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized)
        return int(parsed.timestamp())
    except (TypeError, ValueError, OverflowError):
        return 0


def load_feeds() -> list[dict[str, str]]:
    if not FEEDS_FILE.exists():
        raise FileNotFoundError(
            f"Arquivo de feeds não encontrado: {FEEDS_FILE}. Rode 'init'."
        )

    with FEEDS_FILE.open("r", encoding="utf-8") as file:
        data = json.load(file)

    feeds = data.get("feeds", []) if isinstance(data, dict) else data
    if not isinstance(feeds, list):
        raise ValueError("O campo 'feeds' precisa ser uma lista.")

    valid = []
    for feed in feeds:
        if not isinstance(feed, dict):
            continue
        source = str(feed.get("fonte", "Feed")).strip()
        topic = str(feed.get("topico", "")).strip().lower()
        if not topic:
            # formato antigo (grupo brasil/mundo): cai em Política
            topic = "politica"
        url = str(feed.get("url", "")).strip()
        if topic not in TOPICOS:
            continue
        if not url.startswith(("http://", "https://")):
            continue
        valid.append({"fonte": source or "Feed", "topico": topic, "url": url})
    return valid


def load_excluded() -> list[str]:
    try:
        with FEEDS_FILE.open("r", encoding="utf-8") as file:
            data = json.load(file)
        words = data.get("excluir") if isinstance(data, dict) else None
    except (OSError, json.JSONDecodeError):
        words = None
    if not isinstance(words, list):
        words = EXCLUIR_PADRAO
    return [str(w) for w in words if str(w).strip()]


def fold(text: str) -> str:
    """Minúsculas e sem acento, para comparar palavras."""
    import unicodedata

    decomposed = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in decomposed if not unicodedata.combining(c))


def excluded_pattern(words: list[str]) -> re.Pattern[str] | None:
    parts = [re.escape(fold(w)) for w in words]
    if not parts:
        return None
    return re.compile(r"\b(?:" + "|".join(parts) + r")\b")


def fetch_url(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml, */*",
        },
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        content = response.read(MAX_FEED_BYTES + 1)
    if len(content) > MAX_FEED_BYTES:
        raise ValueError("Feed excede o limite de 4 MiB.")
    return content


def parse_feed(content: bytes, feed: dict[str, str]) -> list[dict[str, Any]]:
    root = ET.fromstring(content)
    # RSS 2.0 e RSS 1.0 (RDF) usam <item>; Atom usa <entry>
    entries = [el for el in root.iter() if local_name(el.tag) in ("item", "entry")]

    items = []
    for entry in entries:
        title = clean_html(
            child_text(entry, ("title", "{http://www.w3.org/2005/Atom}title"))
        )
        link = child_text(entry, ("link",))
        if not link:
            for child in entry:
                if local_name(child.tag) == "link" and child.attrib.get("href"):
                    link = child.attrib["href"]
                    break

        summary = child_text(
            entry,
            (
                "description",
                "summary",
                "encoded",
                "content",
            ),
        )
        summary = clean_html(summary)

        date_text = child_text(
            entry,
            (
                "pubDate",
                "published",
                "updated",
                "date",
            ),
        )

        if not title or not link or not link.startswith(("http://", "https://")):
            continue

        items.append(
            {
                "fonte": feed["fonte"],
                "topico": feed["topico"],
                "titulo": title,
                "resumo": summary,
                "link": link,
                "data": parse_date(date_text),
            }
        )
    return items


def read_cache() -> dict[str, Any] | None:
    try:
        with CACHE_FILE.open("r", encoding="utf-8") as file:
            data = json.load(file)
        if (
            isinstance(data, dict)
            and data.get("versao") == CACHE_VERSAO
            and isinstance(data.get("itens"), list)
        ):
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return None


def write_cache(data: dict[str, Any]) -> None:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    temporary = CACHE_FILE.with_suffix(".tmp")
    with temporary.open("w", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, separators=(",", ":"))
    temporary.replace(CACHE_FILE)


def command_init(recriar: bool) -> int:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    if FEEDS_FILE.exists():
        if not recriar:
            print(f"Arquivo já existe: {FEEDS_FILE} (use 'init --recriar' para trocar pelos tópicos)")
            return 0
        FEEDS_FILE.replace(FEEDS_FILE.with_suffix(".json.bak"))
    with FEEDS_FILE.open("w", encoding="utf-8") as file:
        json.dump(DEFAULT_FEEDS, file, ensure_ascii=False, indent=2)
        file.write("\n")
    print(f"Feeds criados em: {FEEDS_FILE}")
    return 0


def command_fetch(max_age: int, force: bool) -> int:
    now = int(time.time())
    cached = read_cache()

    if not force and cached:
        generated = int(cached.get("geradoEm", 0))
        if generated > 0 and now - generated < max_age:
            cached["doCache"] = True
            print(
                "NEWS " + json.dumps(cached, ensure_ascii=False, separators=(",", ":"))
            )
            return 0

    try:
        feeds = load_feeds()
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print("ERROR " + str(error))
        return 1

    all_items: list[dict[str, Any]] = []
    failures: list[dict[str, str]] = []

    for feed in feeds:
        try:
            parsed = parse_feed(fetch_url(feed["url"]), feed)
            all_items.extend(parsed)
            if not parsed:
                failures.append(
                    {"fonte": feed["fonte"], "erro": "nenhuma notícia válida"}
                )
        except (
            urllib.error.URLError,
            TimeoutError,
            OSError,
            ET.ParseError,
            ValueError,
        ) as error:
            failures.append({"fonte": feed["fonte"], "erro": str(error)[:180]})

    # Deduplica por URL, mantendo a primeira fonte que forneceu a notícia.
    unique: list[dict[str, Any]] = []
    seen: set[str] = set()
    for item in all_items:
        link = item["link"]
        if link in seen:
            continue
        seen.add(link)
        unique.append(item)

    pattern = excluded_pattern(load_excluded())
    if pattern is not None:
        unique = [
            item
            for item in unique
            if not pattern.search(fold(item["titulo"] + " " + item["resumo"]))
        ]

    unique.sort(key=lambda item: item.get("data", 0), reverse=True)

    if not unique and cached and cached.get("itens"):
        # Mantém o último conteúdo utilizável quando todos os feeds falham.
        cached["doCache"] = True
        cached["aviso"] = "Falha ao atualizar; exibindo o último cache disponível."
        cached["erros"] = failures
        print("NEWS " + json.dumps(cached, ensure_ascii=False, separators=(",", ":")))
        return 0

    result = {
        "versao": CACHE_VERSAO,
        "itens": unique,
        "erros": failures,
        "geradoEm": now,
        "doCache": False,
        "aviso": "" if unique else "Nenhum feed retornou notícias.",
    }

    try:
        write_cache(result)
    except OSError as error:
        result["aviso"] = f"Não foi possível salvar o cache: {error}"

    if not unique and not failures:
        print("ERROR Nenhuma notícia encontrada nos feeds configurados.")
        return 1

    print("NEWS " + json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


def command_search(termo: str) -> int:
    """Busca na web (Google News RSS) quando o cache não tem o termo."""
    from urllib.parse import quote

    termo = " ".join(termo.split())
    if not termo:
        print("ERROR Digite um termo para buscar.")
        return 1

    url = (
        "https://news.google.com/rss/search?q=" + quote(termo)
        + "&hl=pt-BR&gl=BR&ceid=BR:pt-419"
    )
    feed = {"fonte": "Busca na web", "topico": "busca", "url": url}

    try:
        itens = parse_feed(fetch_url(url), feed)
    except (
        urllib.error.URLError,
        TimeoutError,
        OSError,
        ET.ParseError,
        ValueError,
    ) as error:
        print("ERROR Busca na web falhou: " + str(error)[:160])
        return 1

    pattern = excluded_pattern(load_excluded())
    if pattern is not None:
        itens = [
            item
            for item in itens
            if not pattern.search(fold(item["titulo"] + " " + item["resumo"]))
        ]

    if not itens:
        print("ERROR Nenhuma notícia na web para esse termo.")
        return 1

    resultado = {
        "versao": CACHE_VERSAO,
        "itens": itens,
        "erros": [],
        "geradoEm": int(time.time()),
        "doCache": False,
        "aviso": "",
    }
    print("NEWS " + json.dumps(resultado, ensure_ascii=False, separators=(",", ":")))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Coletor RSS do Quickshell Phone")
    subparsers = parser.add_subparsers(dest="command", required=True)
    init_parser = subparsers.add_parser("init", help="cria news-feeds.json com feeds padrão")
    init_parser.add_argument("--recriar", action="store_true", help="troca o arquivo pelos tópicos padrão (guarda .bak)")

    fetch_parser = subparsers.add_parser("fetch", help="baixa e retorna notícias RSS")
    fetch_parser.add_argument("--max-age", type=int, default=900)
    fetch_parser.add_argument("--force", action="store_true")

    search_parser = subparsers.add_parser("search", help="busca termo na web (Google News)")
    search_parser.add_argument("--termo", required=True)

    args = parser.parse_args()
    if args.command == "init":
        return command_init(args.recriar)
    if args.command == "search":
        return command_search(args.termo)
    return command_fetch(max(0, args.max_age), args.force)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("ERROR Operação cancelada.")
        sys.exit(130)
