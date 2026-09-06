#!/usr/bin/env python3
"""Export the explainer pages in docs/ as PDFs and PNG diagrams for Claude Design.

Usage: python3 scripts/export-docs.py [page ...] [--out DIR]

Default pages: learning-path, then every page linked from its reading-order table.
Default output: work/docs-export (work/ is ignored by version control). Pipeline per page:
mermaid-cli renders each ```mermaid fence to diagrams/<page>-<n>.png and rewrites the
Markdown, marked turns the Markdown into HTML, and headless Chrome prints the PDF.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
COMBINED = 'catch-five-explainer'
PROMPT = ('These PDFs are the engineering explainer pages for Catch 5, a SwiftUI iOS card game: '
          'a dependency-free Swift package rules engine, an MVVM view model, and a SwiftUI table. '
          'Turn each page into a visual explainer. Keep the section order and every type, function '
          'and test name exactly as written. Redraw each diagram natively; the PNGs show the exact '
          'nodes, labels and arrows to keep. Use a calm card-table palette (ivory, felt green, gold '
          'accents). Do not add behaviour that is not in the pages.')
CSS = """
@page { size: letter; margin: 0.6in; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
       font-size: 11pt; line-height: 1.45; color: #1f2328; max-width: 100%; }
h1, h2, h3, h4 { break-after: avoid; line-height: 1.25; }
h1 { font-size: 1.8em; border-bottom: 1px solid #d0d7de; padding-bottom: 0.2em; }
h2 { font-size: 1.4em; margin-top: 1.4em; }
img { max-width: 100%; max-height: 9.5in; width: auto; height: auto; object-fit: contain;
      break-inside: avoid; display: block; margin: 0.8em auto; }
pre, code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; }
pre { white-space: pre-wrap; overflow-wrap: anywhere; font-size: 0.85em; background: #f6f8fa;
      padding: 0.6em 0.8em; border-radius: 4px; break-inside: avoid; }
code { font-size: 0.9em; }
table { font-size: 0.85em; border-collapse: collapse; width: 100%; margin: 0.8em 0; }
th, td { border: 1px solid #d0d7de; padding: 0.3em 0.5em; vertical-align: top; text-align: left; }
th { background: #f6f8fa; }
tr { break-inside: avoid; }
blockquote { border-left: 3px solid #d0d7de; margin: 0.8em 0; padding: 0 0.8em; color: #57606a; }
section { break-before: page; }
"""
# Mirrors mermaid-cli's own Markdown fence regex so the self-check counts what mmdc renders.
FENCE = re.compile(r'^[^\S\n]*[`:]{3}(?:mermaid)([^\S\n]*\r?\n([\s\S]*?))[`:]{3}[^\S\n]*$', re.M)
TABLE_LINK = re.compile(r'\[[^\]]*\]\(([\w-]+)\.md\)')
PAGE_LINK = re.compile(r'\]\(([\w-]+)\.md(?:#[^)]*)?\)')
H1 = re.compile(r'^#\s+(.+?)\s*$', re.M)


def table_links(text):
    """Return page names linked as [x.md](x.md) from pipe-table rows, in order, deduped.

    >>> table_links('| Step | Page |\\n|---|---|\\n| 1 | [a.md](a.md) |\\n| 2 | [b.md](b.md) |')
    ['a', 'b']
    >>> table_links('Prose [c.md](c.md)\\n| 1 | [a.md](a.md) |\\n| 2 | [a.md](a.md) again |')
    ['a']
    >>> table_links('nothing here')
    []
    """
    pages = []
    for line in text.splitlines():
        if line.lstrip().startswith('|'):
            for name in TABLE_LINK.findall(line):
                if name not in pages:
                    pages.append(name)
    return pages


def rewrite_links(md, mode):
    """Rewrite (name.md) links to (name.pdf) for mode 'pdf' or (#name) for mode 'anchor'.

    >>> rewrite_links('see [architecture.md](architecture.md) and ![d](./../diagrams/a-1.png)', 'pdf')
    'see [architecture.md](architecture.pdf) and ![d](./../diagrams/a-1.png)'
    >>> rewrite_links('see [flow](game-flow.md#auction) and [x](game-flow.md)', 'anchor')
    'see [flow](#game-flow) and [x](#game-flow)'
    >>> rewrite_links('`CLAUDE.md` is not a link', 'pdf')
    '`CLAUDE.md` is not a link'
    """
    if mode == 'pdf':
        return PAGE_LINK.sub(r'](\1.pdf)', md)
    if mode == 'anchor':
        return PAGE_LINK.sub(r'](#\1)', md)
    raise ValueError(f'unknown link mode {mode!r}')


def count_fences(md):
    """Count ```mermaid fences the way mermaid-cli's Markdown mode finds them.

    >>> count_fences('a\\n```mermaid\\nflowchart LR\\n  A --> B\\n```\\nb\\n```swift\\nlet x = 1\\n```\\n')
    1
    >>> count_fences('  ```mermaid\\nA\\n  ```\\n\\n```mermaid\\nB\\n```\\n')
    2
    >>> count_fences('no diagrams')
    0
    """
    return len(FENCE.findall(md))


def page_title(md, fallback):
    """Return the first H1 text of a Markdown page, or the fallback.

    >>> page_title('# Learning Path: Reading Catch 5\\n\\ntext', 'learning-path')
    'Learning Path: Reading Catch 5'
    >>> page_title('no heading', 'learning-path')
    'learning-path'
    """
    match = H1.search(md)
    return match.group(1) if match else fallback


def plural(count, noun):
    """Count a noun for the README.

    >>> plural(1, 'diagram'), plural(3, 'page'), plural(0, 'diagram')
    ('1 diagram', '3 pages', '0 diagrams')
    """
    return f'{count} {noun}{"" if count == 1 else "s"}'


def default_pages(docs):
    """learning-path first, then the pages its reading-order table links, in table order."""
    index = (docs / 'learning-path.md').read_text()
    return ['learning-path'] + [p for p in table_links(index) if p != 'learning-path']


def find_chrome():
    """$CHROME, then puppeteer's cached chrome-headless-shell, then the Google Chrome app."""
    candidates = [os.environ.get('CHROME')]
    candidates += sorted(str(p) for p in Path.home().glob(
        '.cache/puppeteer/chrome-headless-shell/*/chrome-headless-shell-mac-arm64/chrome-headless-shell'))
    candidates.append('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    return None


def run(args):
    """Run a tool quietly; on failure show its stderr and stop."""
    try:
        subprocess.run(args, cwd=root, check=True, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE, text=True)
    except subprocess.CalledProcessError as error:
        sys.exit(f'{args[0]} failed ({error.returncode}): {" ".join(map(str, args))}\n{error.stderr}')


def render_page(page, docs, build, diagrams):
    """Render the page's Mermaid fences to PNGs; return the rewritten Markdown and the PNG paths."""
    source = docs / f'{page}.md'
    rewritten = build / f'{page}.md'
    run(['npx', '--yes', '-p', '@mermaid-js/mermaid-cli', 'mmdc', '-q',
         '-i', str(source), '-o', str(rewritten), '-a', str(diagrams),
         '-e', 'png', '-s', '2', '-w', '1200', '-b', 'white', '-t', 'neutral'])
    pngs = [diagrams / f'{page}-{n}.png' for n in range(1, count_fences(source.read_text()) + 1)]
    missing = [p.name for p in pngs if not p.is_file()]
    if missing:
        sys.exit(f'{page}: mermaid-cli did not produce {", ".join(missing)}')
    return rewritten.read_text(), pngs


def markdown_to_html(md_path, html_path):
    """Convert one Markdown file to an HTML fragment with marked (GFM for pipe tables)."""
    run(['npx', '--yes', '-p', 'marked', 'marked', '--gfm', '-i', str(md_path), '-o', str(html_path)])
    return html_path.read_text()


def wrap_html(title, bodies):
    """Wrap one or many (id, html) bodies in the print template; each body is its own section."""
    sections = ''.join(f'<section id="{id_}" style="break-before: page">\n{html}\n</section>\n'
                       for id_, html in bodies)
    return (f'<!DOCTYPE html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            f'<title>{title}</title>\n<style>{CSS}</style>\n</head>\n<body>\n{sections}</body>\n</html>\n')


def print_pdf(chrome, html_path, pdf_path):
    """Print an HTML file to PDF with headless Chrome; fail if the PDF is missing or tiny."""
    pdf_path.unlink(missing_ok=True)
    run([chrome, '--headless', '--disable-gpu', '--no-pdf-header-footer',
         '--run-all-compositor-stages-before-draw', '--virtual-time-budget=5000',
         f'--print-to-pdf={pdf_path}', f'file://{html_path}'])
    if not pdf_path.is_file() or pdf_path.stat().st_size < 1024:
        sys.exit(f'Chrome did not produce a usable PDF at {pdf_path}')


def write_readme(out, pages, diagrams):
    """Describe the export folder and give the paste-ready Claude Design prompt."""
    lines = ['# Catch 5 explainer export', '',
             f'Made on {time.strftime("%Y-%m-%d")} by `python3 scripts/export-docs.py` from `docs/*.md`: '
             'mermaid-cli renders the diagrams, marked converts Markdown to HTML, headless Chrome prints the PDFs.',
             '', '## Contents', '',
             f'- `{COMBINED}.pdf`: {plural(len(pages), "page")} in reading order, one document']
    for page in pages:
        lines.append(f'- `{page}.pdf`: one page ({plural(len(diagrams[page]), "diagram")})')
    total = sum(len(v) for v in diagrams.values())
    lines += [f'- `diagrams/<page>-<n>.png`: {total} PNGs, one per Mermaid diagram, 2x scale, white background',
              '- `_build/`: intermediates (rewritten Markdown and HTML); safe to ignore', '',
              '## Prompt for Claude Design', '',
              'Upload the PDFs and the `diagrams` folder, then paste:', '', f'> {PROMPT}', '']
    (out / 'README.md').write_text('\n'.join(lines))


def export_app(docs, pages):
    """Fill App/Explainer with the bundle the in-app reader uses: docs/<page>.md (verbatim) and
    diagrams/<page>-<n>.png, one per Mermaid fence. Anything else in the folder is removed."""
    explainer = root / 'App' / 'Explainer'
    for stale in explainer.glob('*.dc.html'):
        stale.unlink()
    app_docs, app_diagrams = explainer / 'docs', explainer / 'diagrams'
    for folder in (app_docs, app_diagrams):
        shutil.rmtree(folder, ignore_errors=True)
        folder.mkdir(parents=True)
    build = root / 'work' / 'docs-export' / 'app-build'
    shutil.rmtree(build, ignore_errors=True)
    build.mkdir(parents=True)
    total = 0
    for page in pages:
        source = docs / f'{page}.md'
        (app_docs / f'{page}.md').write_text(source.read_text())
        if count_fences(source.read_text()):
            _, pngs = render_page(page, docs, build, build)
            for png in pngs:
                shutil.copy(png, app_diagrams / png.name)
            total += len(pngs)
    print(f'App/Explainer: {plural(len(pages), "chapter")}, {plural(total, "diagram")}')


def main():
    started = time.monotonic()
    docs = root / 'docs'
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('pages', nargs='*', help='page names under docs/ (default: the learning-path order)')
    parser.add_argument('--out', type=Path, default=root / 'work' / 'docs-export', help='output folder')
    parser.add_argument('--app', action='store_true', help='fill App/Explainer for the in-app reader instead of exporting PDFs')
    args = parser.parse_args()
    docs = root / 'docs'
    if args.app:
        export_app(docs, default_pages(docs))
        return
    pages = [re.sub(r'\.md$', '', Path(p).name) for p in args.pages] or default_pages(docs)

    if shutil.which('npx') is None:
        sys.exit('npx not found: install Node 20 (mermaid-cli and marked run through npx)')
    chrome = find_chrome()
    if chrome is None:
        sys.exit('Chrome not found: set CHROME=/path/to/chrome, or install Google Chrome, '
                 'or run mmdc once so puppeteer caches chrome-headless-shell')
    for page in pages:
        if not (docs / f'{page}.md').is_file():
            sys.exit(f'no such page: {docs / (page + ".md")}')

    out = args.out.resolve()
    build, diagrams_dir = out / '_build', out / 'diagrams'
    for folder in (build, diagrams_dir):
        shutil.rmtree(folder, ignore_errors=True)
        folder.mkdir(parents=True)

    diagrams, sections = {}, []
    for page in pages:
        md, diagrams[page] = render_page(page, docs, build, diagrams_dir)
        title = page_title(md, page)
        page_md = build / f'{page}.page.md'
        page_md.write_text(rewrite_links(md, 'pdf'))
        body = markdown_to_html(page_md, build / f'{page}.page.html')
        html_path = build / f'{page}.html'
        html_path.write_text(wrap_html(title, [(page, body)]))
        print_pdf(chrome, html_path, out / f'{page}.pdf')
        section_md = build / f'{page}.section.md'
        section_md.write_text(rewrite_links(md, 'anchor'))
        sections.append((page, markdown_to_html(section_md, build / f'{page}.section.html')))
        print(f'{page}: {len(diagrams[page])} diagrams, {page}.pdf')

    combined_html = build / f'{COMBINED}.html'
    combined_html.write_text(wrap_html('Catch 5 explainer', sections))
    print_pdf(chrome, combined_html, out / f'{COMBINED}.pdf')
    write_readme(out, pages, diagrams)

    expected = sum(count_fences((docs / f'{page}.md').read_text()) for page in pages)
    produced = sorted(diagrams_dir.glob('*.png'))
    pdfs = [out / f'{page}.pdf' for page in pages] + [out / f'{COMBINED}.pdf']
    bad = [p.name for p in pdfs if not p.is_file() or p.stat().st_size < 1024]
    print(f'\n{"page":<24}{"diagrams":>10}{"pdf":>10}')
    for page in pages:
        print(f'{page:<24}{len(diagrams[page]):>10}{(out / f"{page}.pdf").stat().st_size // 1024:>8} KB')
    print(f'{COMBINED:<24}{len(produced):>10}{(out / f"{COMBINED}.pdf").stat().st_size // 1024:>8} KB')
    print(f'\n{len(produced)} PNGs, {len(pdfs)} PDFs, {time.monotonic() - started:.1f}s -> {out}')
    if len(produced) != expected:
        sys.exit(f'self-check failed: expected {expected} PNGs from mermaid fences, found {len(produced)}')
    if bad:
        sys.exit(f'self-check failed: missing or tiny PDFs: {", ".join(bad)}')


if __name__ == '__main__':
    main()
