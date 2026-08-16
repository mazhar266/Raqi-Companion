"""Check that a font can actually draw every character the app renders.

Quranic text uses marks — U+06E1 for sukun, the open tanwin forms, the waqf
signs — that most otherwise-fine Arabic fonts lack. A font missing them looks
correct on a headline and drops or tofus tens of thousands of marks across the
Quran, which is not something you notice by glancing at one screen.

Run over a directory of fonts:

    python3 tool/check_font_coverage.py "quran fonts"

Run with no argument to check what is currently bundled, and to refresh
tool/font_coverage.json, which test/fonts_test.dart asserts against:

    python3 tool/check_font_coverage.py

Parses the cmap directly rather than depending on fonttools, which is not
installable on this machine.
"""
import glob
import json
import os
import struct
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLED = os.path.join(ROOT, 'assets/fonts')
REPORT = os.path.join(ROOT, 'tool/font_coverage.json')


# --- what the app renders ---------------------------------------------------

def required_codepoints():
    """Every codepoint appearing in Arabic the app can display."""
    cps = set()

    def scan(text):
        cps.update(ord(c) for c in text)

    with open(os.path.join(ROOT, 'assets/data/ruqyah.json'), encoding='utf-8') as f:
        for category in json.load(f)['categories']:
            for item in category['items']:
                scan(item['arabic'])

    quran = os.path.join(ROOT, 'sources/quran-json-arabic/dist/chapters/en/*.json')
    for path in glob.glob(quran):
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        # chapters/en also holds an index.json, which is a list.
        if not isinstance(data, dict):
            continue
        for verse in data.get('verses', []):
            scan(verse['text'])

    hisnul = os.path.join(ROOT, 'sources/Hisn-Muslim-Json/husn_en.json')
    if os.path.exists(hisnul):
        # This one carries a UTF-8 BOM; utf-8-sig reads it either way.
        with open(hisnul, encoding='utf-8-sig') as f:
            _walk_strings(json.load(f), scan)

    hadith = os.path.join(
        ROOT, 'sources/hadith-json/db/by_chapter/the_9_books/*/*.json')
    for path in glob.glob(hadith):
        with open(path, encoding='utf-8-sig') as f:
            _walk_strings(json.load(f), scan)

    # Only the Arabic script itself. Latin letters and Western punctuation do
    # appear inside some hadith records, but they fall back to the UI font and
    # are not this font's responsibility.
    return {c for c in cps if _is_arabic(c)}


def _is_arabic(cp):
    return (
        0x0600 <= cp <= 0x06FF or  # Arabic
        0x0750 <= cp <= 0x077F or  # Arabic Supplement
        0x08A0 <= cp <= 0x08FF or  # Arabic Extended-A
        0xFB50 <= cp <= 0xFDFF or  # Presentation Forms-A (incl. the ayah brackets)
        0xFE70 <= cp <= 0xFEFF     # Presentation Forms-B
    )


def _walk_strings(node, visit):
    if isinstance(node, dict):
        for value in node.values():
            _walk_strings(value, visit)
    elif isinstance(node, list):
        for value in node:
            _walk_strings(value, visit)
    elif isinstance(node, str):
        if any('؀' <= ch <= 'ۿ' for ch in node):
            visit(node)


# --- minimal TrueType cmap reader -------------------------------------------

def font_codepoints(path):
    """The set of codepoints a font has a glyph for."""
    with open(path, 'rb') as f:
        data = f.read()

    tag, num_tables = struct.unpack('>IH', data[:6])
    if tag == 0x74746366:  # 'ttcf' — font collection, read its first font
        offset = struct.unpack('>I', data[12:16])[0]
        num_tables = struct.unpack('>H', data[offset + 4:offset + 6])[0]
        directory = offset + 12
    else:
        directory = 12

    cmap_offset = None
    for i in range(num_tables):
        entry = directory + i * 16
        name, _, off, _ = struct.unpack('>4sIII', data[entry:entry + 16])
        if name == b'cmap':
            cmap_offset = off
            break
    if cmap_offset is None:
        raise ValueError(f'{path}: no cmap table')

    count = struct.unpack('>H', data[cmap_offset + 2:cmap_offset + 4])[0]
    subtables = []
    for i in range(count):
        rec = cmap_offset + 4 + i * 8
        platform, encoding, off = struct.unpack('>HHI', data[rec:rec + 8])
        subtables.append((platform, encoding, cmap_offset + off))

    # Prefer a full-Unicode subtable, then BMP, then anything Unicode.
    def rank(sub):
        platform, encoding, _ = sub
        if (platform, encoding) in ((3, 10), (0, 4), (0, 6)):
            return 0
        if (platform, encoding) in ((3, 1), (0, 3)):
            return 1
        if platform == 0:
            return 2
        return 3

    covered = set()
    for platform, encoding, off in sorted(subtables, key=rank):
        fmt = struct.unpack('>H', data[off:off + 2])[0]
        if fmt == 4:
            covered = _format4(data, off)
        elif fmt == 12:
            covered = _format12(data, off)
        else:
            continue
        if covered:
            break
    if not covered:
        raise ValueError(f'{path}: no readable Unicode cmap subtable')
    return covered


def _format4(data, off):
    seg_x2 = struct.unpack('>H', data[off + 6:off + 8])[0]
    segs = seg_x2 // 2
    ends = struct.unpack(f'>{segs}H', data[off + 14:off + 14 + seg_x2])
    starts_at = off + 14 + seg_x2 + 2
    starts = struct.unpack(f'>{segs}H', data[starts_at:starts_at + seg_x2])
    deltas_at = starts_at + seg_x2
    deltas = struct.unpack(f'>{segs}h', data[deltas_at:deltas_at + seg_x2])
    ranges_at = deltas_at + seg_x2
    ranges = struct.unpack(f'>{segs}H', data[ranges_at:ranges_at + seg_x2])

    covered = set()
    for i in range(segs):
        if starts[i] > ends[i] or starts[i] == 0xFFFF:
            continue
        for cp in range(starts[i], ends[i] + 1):
            if ranges[i] == 0:
                glyph = (cp + deltas[i]) & 0xFFFF
            else:
                idx = ranges_at + i * 2 + ranges[i] + (cp - starts[i]) * 2
                if idx + 2 > len(data):
                    continue
                glyph = struct.unpack('>H', data[idx:idx + 2])[0]
                if glyph:
                    glyph = (glyph + deltas[i]) & 0xFFFF
            if glyph:
                covered.add(cp)
    return covered


def _format12(data, off):
    n = struct.unpack('>I', data[off + 12:off + 16])[0]
    covered = set()
    for i in range(n):
        rec = off + 16 + i * 12
        start, end, glyph = struct.unpack('>III', data[rec:rec + 12])
        if glyph:
            covered.update(range(start, end + 1))
    return covered


def name(cp):
    return unicodedata.name(chr(cp), f'U+{cp:04X}')


# --- report -----------------------------------------------------------------

def main():
    directory = sys.argv[1] if len(sys.argv) > 1 else BUNDLED
    required = required_codepoints()
    print(f'App renders {len(required)} distinct non-ASCII codepoints\n')

    paths = sorted(
        glob.glob(os.path.join(directory, '*.ttf')) +
        glob.glob(os.path.join(directory, '*.otf')))
    if not paths:
        raise SystemExit(f'no fonts found in {directory}')

    report = {}
    worst = 0
    for path in paths:
        base = os.path.basename(path)
        try:
            covered = font_codepoints(path)
        except Exception as exc:  # noqa: BLE001 — report, do not crash the run
            print(f'{base:44s} UNREADABLE: {exc}')
            report[base] = {'error': str(exc)}
            worst = max(worst, 1)
            continue

        missing = sorted(required - covered)
        report[base] = {
            'glyphs': len(covered),
            'missing': [f'U+{c:04X}' for c in missing],
        }
        worst = max(worst, len(missing))
        status = 'OK' if not missing else f'MISSING {len(missing)}'
        print(f'{base:44s} {len(covered):6d} glyphs   {status}')
        for cp in missing[:12]:
            print(f'{"":46s}  U+{cp:04X}  {name(cp)}')
        if len(missing) > 12:
            print(f'{"":46s}  … and {len(missing) - 12} more')

    if directory == BUNDLED:
        with open(REPORT, 'w', encoding='utf-8') as f:
            json.dump({'required': len(required), 'fonts': report}, f, indent=2)
            f.write('\n')
        print(f'\nwrote {os.path.relpath(REPORT, ROOT)}')

    return 1 if worst else 0


if __name__ == '__main__':
    raise SystemExit(main())
