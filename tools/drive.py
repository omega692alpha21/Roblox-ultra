#!/usr/bin/env python3
"""List and fetch files from a public Google Drive folder without an API key.

Quaternius publishes every pack as a shared Drive folder, so this is the only
way in. Folder pages embed their listing as an escaped JSON blob in
window['_DRIVE_ivd']; files come down from the usual uc?export=download path.
"""
import codecs, json, re, subprocess, sys, os

def listing(folder_id):
    html = subprocess.run(
        ["curl", "-sSL", "--max-time", "60",
         f"https://drive.google.com/drive/folders/{folder_id}"],
        capture_output=True, text=True).stdout
    m = re.search(r"window\['_DRIVE_ivd'\]\s*=\s*'(.*?)'\s*;", html, re.S)
    if not m:
        return []
    data = codecs.decode(m.group(1).replace("\\/", "/"), "unicode_escape")
    return [(e[0], e[2], e[3]) for e in json.loads(data)[0]]

def fetch(file_id, out):
    subprocess.run(
        ["curl", "-sSL", "--max-time", "180", "-o", out,
         f"https://drive.usercontent.google.com/download?id={file_id}&export=download&confirm=t"],
        check=True)
    return os.path.getsize(out)

if __name__ == "__main__":
    if sys.argv[1] == "ls":
        for fid, name, mime in listing(sys.argv[2]):
            kind = "DIR " if mime.endswith("folder") else "file"
            print(f"{kind} {fid}  {name}")
    else:
        print(fetch(sys.argv[2], sys.argv[3]), "bytes")
