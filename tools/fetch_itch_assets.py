"""Fetch public zero-price itch.io assets; never submits a payment or account data."""
import argparse
import hashlib
import html
import http.cookiejar
import json
import pathlib
import re
import urllib.parse
import urllib.request
import urllib.error

ROOT = pathlib.Path(__file__).resolve().parents[1]
CACHE = pathlib.Path.home() / '.cache/close-the-gap-assets'
PACKS = {
    'nature': ('https://quaternius.itch.io/stylized-nature-megakit', r'\[Standard\]'),
    'character': ('https://theunseenvulga.itch.io/3d-charater-riggeddiesel', r'Diesel\.glb'),
    'weapons': ('https://3dmodelscc0.itch.io/free-cc0-guns-explosives-pack', r'Guns.*\.rar'),
    'knife': ('https://skywolfgamestudios.itch.io/cc0tree', r'Combat Knife'),
    'birds': ('https://heyheythere.itch.io/psx-animals-free', r'\.zip'),
    'animations': ('https://quaternius.itch.io/universal-animation-library', r'\[Standard\]'),
    'nature_props': ('https://quaternius.itch.io/150-lowpoly-nature-models', r'\.zip'),
    'industrial': ('https://godgoldfear.itch.io/psx-industrial-environment-asset-pack', r'\.glb$'),
    'industrial_textures': ('https://godgoldfear.itch.io/psx-industrial-environment-asset-pack', r'\.zip'),
    'containers': ('https://loafbrr.itch.io/shipping-crates', r'Godot4\.zip'),
}


def fetch(name, download):
    base, wanted = PACKS[name]
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

    def request(url, data=None, referer=None):
        headers = {'User-Agent': 'CloseTheGapAssetImport/1.0'}
        if referer:
            headers.update(Referer=referer, **{'X-Requested-With': 'XMLHttpRequest'})
        encoded = urllib.parse.urlencode(data).encode() if data is not None else None
        return opener.open(urllib.request.Request(url, data=encoded, headers=headers), timeout=40)

    try:
        with request(base + '/purchase') as response:
            page = response.read().decode()
        token = re.search(r'<meta name="csrf_token" value="([^"]+)"', page).group(1)
        with request(base + '/download_url', {'csrf_token': token}, base + '/purchase') as response:
            ticket = json.load(response)
        with request(ticket['url']) as response:
            referer = response.url
            page = response.read().decode()
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        # Permanently free pages can expose their public uploads directly.
        with request(base) as response:
            referer = response.url
            page = response.read().decode()
    token = re.search(r'<meta name="csrf_token" value="([^"]+)"', page).group(1)
    files = []
    for part in re.split(r'<div class="upload">', page)[1:]:
        identifier = re.search(r'data-upload_id="(\d+)"', part)
        title = re.search(r'<strong[^>]*class="name"[^>]*>(.*?)</strong>', part)
        if identifier and title:
            files.append({'id': identifier.group(1), 'name': html.unescape(title.group(1))})
    print(json.dumps({'pack': name, 'files': files}), flush=True)
    if not download:
        return
    selected = [item for item in files if re.search(wanted, item['name'], re.I)]
    if len(selected) != 1:
        raise ValueError(f'Expected one free upload for {name}, found {len(selected)}')
    chosen = selected[0]
    CACHE.mkdir(parents=True, exist_ok=True)
    destination = CACHE / (name + '-' + pathlib.Path(chosen['name']).name)
    if not destination.exists():
        with request(base + '/file/' + chosen['id'], {'csrf_token': token}, referer) as response:
            location = json.load(response)['url']
        partial = destination.with_suffix(destination.suffix + '.part')
        with request(location) as source, partial.open('wb') as output:
            total = 0
            while block := source.read(1024 * 1024):
                total += len(block)
                if total > 1024 * 1024 * 1024:
                    raise ValueError('Asset upload exceeds the 1 GiB limit')
                output.write(block)
        partial.replace(destination)
    with destination.open('rb') as source:
        checksum = hashlib.file_digest(source, 'sha256').hexdigest()
    report = {'pack': name, 'page': base, 'upload_id': chosen['id'], 'upload_name': chosen['name'],
              'file': str(destination), 'bytes': destination.stat().st_size, 'sha256': checksum}
    (ROOT / 'artifacts/asset-research' / (name + '-download.json')).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('pack', choices=PACKS)
    parser.add_argument('--download', action='store_true')
    options = parser.parse_args()
    fetch(options.pack, options.download)
