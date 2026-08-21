"""Re-fetch every Quranic ayah in ruqyah.json from the bundled Quran data.

The app originally shipped imlaei Arabic, which omits the Uthmani madd signs
and the open tanwin forms. This replaces the `arabic` of every Quranic item
with the Uthmani text from sources/quran, so the whole file is one
orthography and the tajweed parser and the Quranic fonts both see what they
expect.

Only `arabic` and `script` change. The hand-written `transliteration`,
`translation`, `note` and `repeat` are kept — orthography does not affect them.

Items that are not Quran (the masnun duas in Modules 8 and 9) have no
counterpart in the Quran data and are left exactly as they are.

Every replacement is verified: the existing text and the fetched text are
compared with diacritics stripped, and anything below the similarity floor is
reported and skipped rather than silently overwritten.

    python3 tool/resync_quran_text.py            # report only
    python3 tool/resync_quran_text.py --write    # apply
"""
import collections
import difflib
import glob
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'assets/data/ruqyah.json')
QURAN = os.path.join(ROOT, 'sources/quran/chapters/{}.json')

# Below this, the fetched ayah is probably not the one the item holds.
SIMILARITY_FLOOR = 0.70

# Items with no Quranic counterpart: duas from the sunnah, and the procedural
# steps that carry no Arabic at all.
NON_QURANIC = {
    'm8-tahlil', 'm8-earth-sky', 'm8-kalimat', 'm8-hasbiyallah',
    'm9-pain', 'm9-home-entry',
    'm9-sleep-wudu', 'm9-sleep-recite', 'm9-sleep-quls',
}

_chapters = {}


def chapter(surah):
    if surah not in _chapters:
        with io.open(QURAN.format(surah), encoding='utf-8') as f:
            _chapters[surah] = json.load(f)
    return _chapters[surah]


def arabic_num(n):
    return ''.join('٠١٢٣٤٥٦٧٨٩'[int(d)] for d in str(n))


def parse_reference(reference):
    """(surah, start, end) from a reference like `Al-A'raf 7:117-122`.

    A reference naming only a surah — `Surah Al-Ikhlas 112` — means all of it.
    """
    m = re.search(r'(\d+)\s*:\s*(\d+)\s*-\s*(\d+)', reference)
    if m:
        return int(m.group(1)), int(m.group(2)), int(m.group(3))
    m = re.search(r'(\d+)\s*:\s*(\d+)', reference)
    if m:
        return int(m.group(1)), int(m.group(2)), int(m.group(2))
    m = re.search(r'(\d+)\s*$', reference)
    if m:
        surah = int(m.group(1))
        return surah, 1, chapter(surah)['total_verses']
    return None


def fetch(surah, start, end):
    verses = [v for v in chapter(surah)['verses'] if start <= v['id'] <= end]
    if len(verses) != end - start + 1:
        raise SystemExit(f'{surah}:{start}-{end}: found {len(verses)}')
    if len(verses) == 1:
        return verses[0]['text']
    return ' '.join(f"{v['text']} ﴿{arabic_num(v['id'])}﴾" for v in verses)


# --- verification -----------------------------------------------------------

_MARKS = re.compile(
    '[ً-ٰٟۖ-ۭـ]')
_ALEF = re.compile('[آأإاٱ]')


def skeleton(text):
    """Consonant skeleton, for comparing two orthographies of one ayah.

    Imlaei and Uthmani disagree about more than diacritics — Uthmani writes a
    superscript alef where imlaei writes a full one — so alefs are dropped
    rather than normalised, and the comparison is a similarity ratio, not
    equality.
    """
    text = _MARKS.sub('', text)
    text = _ALEF.sub('', text)
    text = text.replace('ى', 'ي')
    for ch in '﴿﴾٠١٢٣٤٥٦٧٨٩ ':
        text = text.replace(ch, '')
    return text


def similarity(a, b):
    return difflib.SequenceMatcher(None, skeleton(a), skeleton(b)).ratio()


# --- run --------------------------------------------------------------------

def main():
    write = '--write' in sys.argv

    with io.open(DATA, encoding='utf-8') as f:
        data = json.load(f, object_pairs_hook=collections.OrderedDict)

    converted = replaced = skipped = 0
    suspicious = []

    for category in data['categories']:
        for item in category['items']:
            if item['id'] in NON_QURANIC or not item['arabic']:
                skipped += 1
                continue

            parsed = parse_reference(item['reference'])
            if parsed is None:
                suspicious.append((item['id'], item['reference'],
                                   'no surah:ayah in reference', 0.0))
                continue

            fetched = fetch(*parsed)
            ratio = similarity(item['arabic'], fetched)
            if ratio < SIMILARITY_FLOOR:
                suspicious.append(
                    (item['id'], item['reference'],
                     'text does not match the reference', ratio))
                continue

            already = item.get('script') == 'uthmani'
            if item['arabic'] != fetched:
                if already:
                    replaced += 1
                else:
                    converted += 1
                item['arabic'] = fetched
            item['script'] = 'uthmani'

    print(f'converted from imlaei : {converted}')
    print(f'already uthmani, text changed : {replaced}')
    print(f'left alone (not Quran, or no Arabic) : {skipped}')

    if suspicious:
        print('\nNOT REPLACED — needs a look:')
        for item_id, reference, why, ratio in suspicious:
            print(f'  {item_id:24s} {reference:34s} {why} ({ratio:.2f})')

    if not write:
        print('\n(report only — pass --write to apply)')
        return 1 if suspicious else 0

    with io.open(DATA, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'\nwrote {os.path.relpath(DATA, ROOT)}')
    return 1 if suspicious else 0


if __name__ == '__main__':
    raise SystemExit(main())
