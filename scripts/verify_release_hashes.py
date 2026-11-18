"""Verify the frozen repository file manifest. No optimization or data changes."""
import argparse,csv,hashlib,json
from pathlib import Path

def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(2**20),b''):h.update(block)
 return h.hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',default='.');p.add_argument('--assets');a=p.parse_args()
 root=Path(a.root).resolve();errors=[];checked=0
 rows=list(csv.DictReader((root/'MANIFEST.csv').open(encoding='utf-8-sig',newline='')))
 for r in rows:
  path=(root/r['Path']).resolve()
  if not path.is_relative_to(root):errors.append('Unsafe manifest path: '+r['Path']);continue
  if not path.is_file():errors.append('Missing: '+r['Path']);continue
  if path.stat().st_size!=int(r['Bytes']) or digest(path)!=r['SHA256']:errors.append('Mismatch: '+r['Path'])
  checked+=1
 assets=0
 if a.assets:
  assetroot=Path(a.assets).resolve()
  for r in csv.DictReader((assetroot/'RELEASE_ASSETS_SHA256.csv').open(encoding='utf-8-sig',newline='')):
   path=(assetroot/r['File']).resolve()
   if not path.is_relative_to(assetroot) or not path.is_file() or digest(path)!=r['SHA256']:errors.append('Asset mismatch: '+r['File'])
   assets+=1
 print(json.dumps({'status':'pass' if not errors else 'fail','repository_files_checked':checked,'release_assets_checked':assets,'errors':errors},indent=2))
 return bool(errors)
if __name__=='__main__':raise SystemExit(main())
