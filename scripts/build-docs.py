#!/usr/bin/env python3
"""Build a self-contained documentation site from the repository's Markdown."""
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from html.parser import HTMLParser
from urllib.parse import urlsplit, urlunsplit

import markdown

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'temp' / 'site'
BASE_URL = 'https://ahrik.github.io/tashair/'
REPOSITORY = 'https://github.com/ahrik/tashair'
SOURCE_REF = os.environ.get('TASHAIR_SOURCE_REF')
if not SOURCE_REF:
    try:
        SOURCE_REF = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        SOURCE_REF = 'main'
PAGES = [
    ('web/index.md', 'index.html', 'Начало'),
    ('docs/INSTALLATION.md', 'installation.html', 'Установка'),
    ('docs/USER_GUIDE.md', 'guide.html', 'Руководство'),
    ('docs/WIDGETS.md', 'widgets.html', 'Виджеты macOS'),
    ('docs/ALERTS.md', 'alerts.html', 'Уведомления'),
    ('docs/DATA_SOURCES.md', 'sources.html', 'Источники и методика'),
    ('docs/PRIVACY.md', 'privacy.html', 'Конфиденциальность'),
    ('CONTRIBUTING.md', 'contributing.html', 'Разработчикам'),
    ('CHANGELOG.md', 'changelog.html', 'История версий'),
    ('LICENSE', 'license.html', 'Лицензия MIT'),
    ('README.md', 'readme.html', 'О проекте'),
    ('THIRD_PARTY_NOTICES.md', 'notices.html', 'Благодарности'),
    ('docs/PUBLISHING.md', 'publishing.html', 'Публикация'),
]
DESTINATIONS = {(ROOT / source).resolve(): filename for source, filename, _ in PAGES}


def rewrite_links(content, source):
    def replace(match):
        attribute, quote, target = match.groups()
        parts = urlsplit(html.unescape(target))
        if parts.scheme or parts.netloc or not parts.path or parts.path.startswith('/'):
            return match.group(0)
        path = (source.parent / parts.path).resolve()
        if path in DESTINATIONS:
            target = urlunsplit(('', '', DESTINATIONS[path], parts.query, parts.fragment))
        elif path.is_relative_to(ROOT / 'docs' / 'images') and path.is_file():
            target = urlunsplit(('', '', 'assets/images/' + path.relative_to(ROOT / 'docs' / 'images').as_posix(), parts.query, parts.fragment))
        elif path.is_relative_to(ROOT / 'web' / 'assets') and path.is_file():
            target = urlunsplit(('', '', 'assets/' + path.relative_to(ROOT / 'web' / 'assets').as_posix(), parts.query, parts.fragment))
        elif path.is_relative_to(ROOT) and path.exists() and not path.is_relative_to(ROOT / 'web'):
            target = f'{REPOSITORY}/blob/{SOURCE_REF}/{path.relative_to(ROOT).as_posix()}'
        else:
            return match.group(0)
        return f'{attribute}={quote}{html.escape(target, quote=True)}{quote}'
    return re.sub(r'(href|src)=(\x22|\x27)(.*?)\2', replace, content)


class Text(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []

    def handle_data(self, data):
        self.parts.append(data)


def navigation(current):
    def link(page):
        _, filename, label = page
        selected = ' aria-current="page"' if filename == current else ''
        return f'<a href="{filename}"{selected}>{label}</a>'
    return ''.join(link(page) for page in PAGES[:10]) + '<details><summary>О проекте подробнее</summary>' + ''.join(link(page) for page in PAGES[10:]) + '</details>'


def pagination(current):
    position = next(i for i, page in enumerate(PAGES) if page[1] == current)
    links = []
    for offset, label in [(-1, 'Предыдущая страница'), (1, 'Следующая страница')]:
        target = position + offset
        if 0 <= target < len(PAGES):
            _, filename, title = PAGES[target]
            links.append(f'<a href="{filename}"><small>{label}</small>{html.escape(title)}</a>')
    return '<nav class="book-pagination" aria-label="Страницы книги">' + ''.join(links) + '</nav>'


if OUTPUT.exists():
    shutil.rmtree(OUTPUT)
OUTPUT.mkdir(parents=True)
shutil.copytree(ROOT / 'web' / 'assets', OUTPUT / 'assets')
shutil.copytree(ROOT / 'docs' / 'images', OUTPUT / 'assets' / 'images')
index = []
for source_name, filename, title in PAGES:
    source = ROOT / source_name
    text = source.read_text()
    if source_name == 'LICENSE':
        text = '# Лицензия MIT\n\n```text\n' + text + '\n```\n'
    converter = markdown.Markdown(extensions=['extra', 'toc', 'sane_lists'], extension_configs={'toc': {'toc_depth': '2-3'}})
    content = rewrite_links(converter.convert(text), source)
    plain = Text(); plain.feed(content)
    index.append({'title': title, 'url': filename, 'text': ' '.join(' '.join(plain.parts).split())})
    page = f'''<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} — TashAir</title>
<meta name="description" content="Воздух, погода, УФ и космическая погода Ташкента в строке меню macOS. Установка и документация TashAir.">
<meta name="color-scheme" content="light"><link rel="canonical" href="{BASE_URL + filename}">
<link rel="icon" href="assets/logo.png" type="image/png"><link rel="stylesheet" href="assets/style.css">
<script src="assets/site.js" defer></script></head><body>
<a class="skip" href="#content">Перейти к содержимому</a>
<header class="topbar"><a class="brand" href="index.html"><img src="assets/logo.png" alt="" width="37" height="37">TashAir<span>Документация</span></a>
<nav class="toplinks" aria-label="Ссылки проекта"><a href="{REPOSITORY}">GitHub</a><a class="download" href="installation.html">Установить</a><button class="menu-button" type="button" aria-controls="sidebar" aria-expanded="false">Меню</button></nav></header>
<div class="layout"><aside class="sidebar" id="sidebar"><label class="search-label" for="search">Поиск по документации</label><input class="search" id="search" type="search" placeholder="Например, уведомления" autocomplete="off"><nav class="pages" aria-label="Разделы документации">{navigation(filename)}</nav><p class="sidebar-note">macOS 14 и новее<br>Интерфейс: русский и узбекский<br>Бесплатно, с открытым кодом</p></aside>
<main id="content"><div class="article"><section class="search-results" aria-label="Результаты поиска" aria-live="polite" hidden></section><article>{content}</article>
{pagination(filename)}<footer><span>TashAir распространяется под MIT.</span><a href="{REPOSITORY}/issues">Сообщить об ошибке</a></footer></div></main>
<aside class="toc" aria-label="Содержание страницы"><p>На этой странице</p>{converter.toc}</aside></div></body></html>'''
    (OUTPUT / filename).write_text(page)
(OUTPUT / 'search-index.json').write_text(json.dumps(index, ensure_ascii=False))
(OUTPUT / '.nojekyll').touch()
(OUTPUT / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + ''.join(f'<url><loc>{BASE_URL + filename}</loc></url>' for _, filename, _ in PAGES) + '</urlset>')
(OUTPUT / 'robots.txt').write_text(f'User-agent: *\nAllow: /\nSitemap: {BASE_URL}sitemap.xml\n')
(OUTPUT / '404.html').write_text(f'''<!doctype html><html lang="ru"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><base href="{BASE_URL}"><title>Страница не найдена — TashAir</title>
<link rel="stylesheet" href="assets/style.css"></head><body>
<header class="topbar"><a class="brand" href="index.html">TashAir<span>Документация</span></a></header>
<main class="article"><h1>Страница не найдена</h1><p>Адрес мог измениться. Начните с <a href="index.html">главной страницы</a> или откройте <a href="guide.html">руководство пользователя</a>.</p></main></body></html>''')
print(f'Built {len(PAGES)} documentation pages in {OUTPUT}')
