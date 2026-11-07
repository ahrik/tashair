#!/usr/bin/env python3
"""Check generated HTML links, fragments, images, book navigation and search data."""
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import unquote, urlsplit

root = Path(__file__).resolve().parent.parent / 'temp/site'

class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.ids = set()
        self.assets = []
        self.headings = 0
        self.navigation = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            assert attrs['id'] not in self.ids, f'Duplicate id: {attrs["id"]}'
            self.ids.add(attrs['id'])
        if tag == 'h1':
            self.headings += 1
        if tag == 'nav' and attrs.get('aria-label') == 'Страницы книги':
            self.navigation = True
        for name in ('href', 'src'):
            if name in attrs:
                self.links.append(attrs[name])
        if tag == 'img':
            assert 'alt' in attrs, 'Missing image alternative text'
            self.assets.append(attrs['src'])

pages = {}
for page in root.glob('*.html'):
    parser = Links()
    parser.feed(page.read_text())
    assert parser.headings == 1, f'Expected one h1: {page.name}'
    pages[page.resolve()] = parser
assert len(pages) == 14, f'Expected 13 book pages and 404, got {len(pages)}'
count = 0
for page, parser in pages.items():
    for link in parser.links:
        url = urlsplit(link)
        if url.scheme or url.netloc:
            continue
        target = (page.parent / unquote(url.path)).resolve() if url.path else page
        assert target.is_relative_to(root), f'Link outside site: {page.name}: {link}'
        assert target.is_file(), f'Missing target: {page.name}: {link}'
        if url.fragment and target in pages:
            assert unquote(url.fragment) in pages[target].ids, f'Missing fragment: {page.name}: {link}'
        count += 1
    if page.name != '404.html':
        assert parser.navigation, f'Missing book navigation: {page.name}'
        assert 'widgets.html' in parser.links and 'alerts.html' in parser.links
        assert 'search-index.json' not in parser.assets
search = json.loads((root / 'search-index.json').read_text())
assert len(search) == 13
assert len({item['url'] for item in search}) == 13
assert all((root / item['url']).resolve() in pages for item in search)
for word in ['уведомления', 'виджеты', 'подпись', 'модель', 'конфиденциальность']:
    assert any(word in item['text'].lower() for item in search), word
widgets = pages[(root / 'widgets.html').resolve()]
assert len([image for image in widgets.assets if image.startswith('assets/widgets/')]) == 3
for parser in pages.values():
    assert all(not image.startswith('https://github.com/') for image in parser.assets), 'Image points to GitHub HTML'
assert (root / '.nojekyll').is_file()
assert 'https://ahrik.github.io/tashair/' in (root / 'sitemap.xml').read_text()
assert not any(p.is_symlink() for p in root.rglob('*')), 'GitHub Pages archive cannot contain symlinks'
print(f'Checked 13 book pages + 404, {count} local links, fragments and assets, full-text index and book navigation.')
