#!/usr/bin/env python3
"""Coletor RSS para o Quickshell Phone.

Comandos:
  news-helper.py init
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
USER_AGENT = "QuickshellPhone-NewsReader/1.0 (+RSS reader)"
MAX_FEED_BYTES = 4 * 1024 * 1024

DEFAULT_FEEDS = {
    "feeds": [
        {"fonte": "G1", "grupo": "brasil", "url": "https://g1.globo.com/rss/g1/"},
        {
            "fonte": "Agência Brasil",
            "grupo": "brasil",
            "url": "https://agenciabrasil.ebc.com.br/rss/geral/feed.xml",
        },
        {
            "fonte": "BBC Brasil",
            "grupo": "brasil",
            "url": "https://feeds.bbci.co.uk/portuguese/brasil/rss.xml",
        },
        {
            "fonte": "BBC Mundo",
            "grupo": "mundo",
            "url": "https://feeds.bbci.co.uk/portuguese/internacional/rss.xml",
        },
        {"fonte": "DW", "grupo": "mundo", "url": "https://rss.dw.com/rdf/rss-pt-all"},
        {
            "fonte": "The Guardian",
            "grupo": "mundo",
            "url": "https://www.theguardian.com/world/rss",
        },
    ]
}


def clean_html(value: str | None) -> str:
    """Remove tags e normaliza entidades/espaços de um resumo RSS."""
    if not value:
        return ""
    value = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", value)
    value = re.sub(r"(?s)<[^>]+>", " ", value)
    value = html.unescape(value)
    return re.sub(r"\s+", " ", value).strip()


def child_text(element: ET.Element, names: tuple[str, ...]) -> str:
    for name in names:
        found = element.find(name)
        if found is not None and found.text:
            return found.text.strip()
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
        group = str(feed.get("grupo", "")).strip().lower()
        url = str(feed.get("url", "")).strip()
        if group not in ("brasil", "mundo"):
            continue
        if not url.startswith(("http://", "https://")):
            continue
        valid.append({"fonte": source or "Feed", "grupo": group, "url": url})
    return valid


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
    entries: list[ET.Element] = []

    # RSS 2.0
    entries.extend(root.findall(".//item"))
    # Atom
    entries.extend(root.findall(".//{http://www.w3.org/2005/Atom}entry"))

    items = []
    for entry in entries:
        title = clean_html(
            child_text(entry, ("title", "{http://www.w3.org/2005/Atom}title"))
        )
        link = child_text(entry, ("link",))
        if not link:
            atom_link = entry.find("{http://www.w3.org/2005/Atom}link")
            if atom_link is not None:
                link = atom_link.attrib.get("href", "")

        summary = child_text(
            entry,
            (
                "description",
                "summary",
                "content:encoded",
                "{http://www.w3.org/2005/Atom}summary",
                "{http://www.w3.org/2005/Atom}content",
            ),
        )
        summary = clean_html(summary)

        date_text = child_text(
            entry,
            (
                "pubDate",
                "published",
                "updated",
                "{http://www.w3.org/2005/Atom}published",
                "{http://www.w3.org/2005/Atom}updated",
            ),
        )

        if not title or not link or not link.startswith(("http://", "https://")):
            continue

        items.append(
            {
                "fonte": feed["fonte"],
                "grupo": feed["grupo"],
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
        if isinstance(data, dict) and isinstance(data.get("itens"), list):
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


def command_init() -> int:
    APP_DIR.mkdir(parents=True, exist_ok=True)
    if FEEDS_FILE.exists():
        print(f"Arquivo já existe: {FEEDS_FILE}")
        return 0
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

    unique.sort(key=lambda item: item.get("data", 0), reverse=True)

    if not unique and cached and cached.get("itens"):
        # Mantém o último conteúdo utilizável quando todos os feeds falham.
        cached["doCache"] = True
        cached["aviso"] = "Falha ao atualizar; exibindo o último cache disponível."
        cached["erros"] = failures
        print("NEWS " + json.dumps(cached, ensure_ascii=False, separators=(",", ":")))
        return 0

    result = {
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Coletor RSS do Quickshell Phone")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("init", help="cria news-feeds.json com feeds padrão")

    fetch_parser = subparsers.add_parser("fetch", help="baixa e retorna notícias RSS")
    fetch_parser.add_argument("--max-age", type=int, default=900)
    fetch_parser.add_argument("--force", action="store_true")

    args = parser.parse_args()
    if args.command == "init":
        return command_init()
    return command_fetch(max(0, args.max_age), args.force)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("ERROR Operação cancelada.")
        sys.exit(130)
