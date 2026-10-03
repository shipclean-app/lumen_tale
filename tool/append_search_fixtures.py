import hashlib
import json
import os

BASE = 'test/fixtures/sources/royalroad'
MANIFEST = os.path.join(BASE, 'manifest.json')
UA = 'LumenTale/1.0.0 (personal reader)'

CAPTURE = [
    {
        'key': 'search-litrpg',
        'file': 'search/rr-search-litrpg.html',
        'url': '/fictions/search?title=litrpg',
        'kind': 'search',
        'expected': {'rows': 20, 'mustMatch': True},
        'notes': (
            '6-11. The POSITIVE half of a measured pair: a query that MUST match. '
            'Twenty rows, and every sampled title carries "LitRPG" — ADR-015 asks for '
            '"results a reader would call useful", so the TITLES are the verdict and a '
            'count of twenty is not. Captured with the honest UA, GET, no session.'
        ),
    },
    {
        'key': 'search-system-fantasy',
        'file': 'search/rr-search-system-fantasy.html',
        'url': '/fictions/search?title=system+fantasy',
        'kind': 'search',
        'expected': {'rows': 20, 'mustMatch': True},
        'notes': (
            '6-11. The second positive, deliberately a DIFFERENT shape of query '
            '("system fantasy", two words) so the verdict does not rest on one keyword '
            'the site happens to favour. Twenty rows; sampled titles carry "System '
            'Fantasy" and "Progression".'
        ),
    },
    {
        'key': 'search-no-match',
        'file': 'search/rr-search-zzzqqqxxnotanovelname.html',
        'url': '/fictions/search?title=zzzqqqxxnotanovelname',
        'kind': 'search',
        'expected': {'rows': 0, 'mustMatch': False, 'emptyMarker': True},
        'notes': (
            '6-11. THE CONTROL, and the half that makes the other half mean anything: '
            'without it, "20 rows for litrpg" and "the page always shows 20 rows" are '
            'the same observation. Zero rows, HTTP 200, the SAME page shell '
            '(97 498 bytes against 250 980), and the site own visible marker '
            '"No results matching these criteria were found" inside '
            'div.search-item.clearfix > h4.font-red-sunglo. Present once here, absent '
            'from BOTH 20-row pages — a marker that appears everywhere discriminates '
            'nothing. The verdict lives in search/verdict.json and is re-derived from '
            'these three pages by test/fixtures/royalroad_search_test.dart.'
        ),
    },
]


def sha256_of(path):
    with open(path, 'rb') as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def main():
    manifest = json.load(open(MANIFEST, encoding='utf-8'))

    existing = {entry['key'] for entry in manifest['entries']}
    by_key = {entry['key']: entry for entry in manifest['entries']}

    for capture in CAPTURE:
        path = os.path.join(BASE, capture['file'])
        if not os.path.exists(path):
            raise SystemExit('missing fixture: %s' % path)
        data = open(path, 'rb').read()

        entry = {
            'key': capture['key'],
            'file': capture['file'],
            'url': capture['url'],
            'httpStatus': 200,
            'contentType': 'text/html; charset=utf-8',
            'capturedAt': '2026-10-03T21:27:00Z',
            'bytes': len(data),
            'sha256': sha256_of(path),
            'kind': capture['kind'],
            'expected': capture['expected'],
            'notes': capture['notes'],
        }

        if capture['key'] in by_key:
            by_key[capture['key']].update(entry)
            print('updated %s' % capture['key'])
        else:
            manifest['entries'].append(entry)
            print('added %s' % capture['key'])

    # `notes` at the top level is where a reader looks first; say what the capture set
    # now covers and what the search verdict concluded, so the manifest alone is enough
    # to know the difference from the pre-6-11 state.
    manifest['notes'] = (
        manifest.get('notes', '')
        + ' '
        if manifest.get('notes')
        else ''
    ) + (
        '| 2026-10-03 `6-11`: three search pages added under `search/` — two queries '
        'that MUST match and one control that cannot — plus `search/verdict.json`. '
        'Royal Road `supportsSearch` is TRUE, measured from the titles rather than a '
        'status code, and its search side carries the site own empty marker '
        '"No results matching these criteria were found". The BROWSE side has no marker '
        'and stays `zeroIsBroken`; the two are different pages and one measurement must '
        'not become a policy on both. Novel Fire was NOT measurable on the same day '
        '(403 Cloudflare interstitial, honest UA), so its flag stays unmeasured rather '
        'than false.'
    )

    with open(MANIFEST, 'w', encoding='utf-8') as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write('\n')

    print('manifest entries: %d' % len(manifest['entries']))


if __name__ == '__main__':
    main()