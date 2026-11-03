"""Inspect an unencrypted Godot 4.7 PCK, using the engine's v4 directory layout.
Source: https://github.com/godotengine/godot/blob/4.7-stable/core/io/file_access_pack.cpp
"""
import hashlib,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'builds/windows/CloseTheGap.pck'
entries=[]
with p.open('rb') as f:
    magic,version,major,minor,patch,flags=struct.unpack('<6I',f.read(24))
    assert magic==0x43504447 and version==4 and not flags&1
    base,directory=struct.unpack('<2Q',f.read(16));f.seek(directory)
    count=struct.unpack('<I',f.read(4))[0]
    for i in range(count):
        length=struct.unpack('<I',f.read(4))[0]
        path=f.read(length).rstrip(b'\0').decode()
        offset,size=struct.unpack('<2Q',f.read(16));md5=f.read(16).hex();file_flags=struct.unpack('<I',f.read(4))[0]
        entries.append(dict(path=path,offset=base+offset,size=size,md5=md5,flags=file_flags))
    forbidden=[e['path'] for e in entries if e['path'].startswith(('res://tests/','res://tools/','res://artifacts/')) or 'test_demo_pack' in e['path']]
    assert not forbidden,forbidden
    for e in entries:
        assert e['flags']==0
        f.seek(e['offset']);data=f.read(e['size']);assert len(data)==e['size'] and hashlib.md5(data).hexdigest()==e['md5'],e['path']
        if e['path'].startswith('res://replays/'):
            assert data==(ROOT/e['path'][6:]).read_bytes(),e['path']
report=dict(format=version,engine=[major,minor,patch],files=count,all_entry_hashes_valid=True,development_files=forbidden,entries=entries)
(ROOT/'artifacts/demo/pack-contents.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='entries'}))
