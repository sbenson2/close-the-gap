"""Verify the MP4's actual sample count and constant timing without ffprobe."""
import json
import pathlib
import struct
import sys


def atoms(stream, begin, end):
    offset = begin
    while offset + 8 <= end:
        stream.seek(offset)
        size, kind = struct.unpack('>I4s', stream.read(8))
        header = 8
        if size == 1:
            size = struct.unpack('>Q', stream.read(8))[0]
            header = 16
        elif size == 0:
            size = end - offset
        if size < header or offset + size > end:
            raise ValueError(f'Invalid {kind!r} atom at {offset}')
        yield kind, offset + header, offset + size
        offset += size


def child(stream, parent, kind):
    return next((start, end) for name, start, end in atoms(stream, *parent) if name == kind)


def payload(stream, span):
    stream.seek(span[0])
    return stream.read(span[1] - span[0])


def inspect(path):
    result = {'file': str(path), 'bytes': path.stat().st_size, 'tracks': []}
    with path.open('rb') as stream:
        moov = child(stream, (0, path.stat().st_size), b'moov')
        for kind, start, end in atoms(stream, *moov):
            if kind != b'trak':
                continue
            track = (start, end)
            mdia = child(stream, track, b'mdia')
            handler = payload(stream, child(stream, mdia, b'hdlr'))[8:12].decode('ascii')
            mdhd = payload(stream, child(stream, mdia, b'mdhd'))
            if mdhd[0] == 1:
                scale = struct.unpack_from('>I', mdhd, 20)[0]
                duration = struct.unpack_from('>Q', mdhd, 24)[0]
            else:
                scale, duration = struct.unpack_from('>II', mdhd, 12)
            stbl = child(stream, child(stream, mdia, b'minf'), b'stbl')
            stsz = payload(stream, child(stream, stbl, b'stsz'))
            count = struct.unpack_from('>I', stsz, 8)[0]
            stts = payload(stream, child(stream, stbl, b'stts'))
            entries = struct.unpack_from('>I', stts, 4)[0]
            timing = [struct.unpack_from('>II', stts, 8 + index * 8) for index in range(entries)]
            assert sum(item[0] for item in timing) == count
            data = {'kind': handler, 'samples': count, 'seconds': duration / scale, 'timescale': scale}
            if handler == 'vide':
                tkhd = payload(stream, child(stream, track, b'tkhd'))
                width, height = struct.unpack_from('>II', tkhd, len(tkhd) - 8)
                data.update(width=width >> 16, height=height >> 16,
                            timing_runs=timing, constant_fps=scale / timing[0][1] if len(timing) == 1 else None)
            result['tracks'].append(data)
    return result


if __name__ == '__main__':
    report = inspect(pathlib.Path(sys.argv[1]))
    expected_seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 600
    video = next(track for track in report['tracks'] if track['kind'] == 'vide')
    assert video['samples'] == round(expected_seconds * 60), report
    assert video['constant_fps'] == 60, report
    assert video['seconds'] == expected_seconds, report
    assert (video['width'], video['height']) == (1920, 1080), report
    assert any(track['kind'] == 'soun' for track in report['tracks']), report
    print(json.dumps(report, indent=2))
