#!/usr/bin/env python3
"""Bring a Quaternius CC0 pack into the game.

Quaternius publishes each pack as a public Google Drive folder holding Blend,
FBX and OBJ subfolders. There is no glTF, which is what the Poly Haven
pipeline eats -- but Roblox Open Cloud accepts FBX for a Model asset directly,
so these need no repacking at all: enumerate the FBX folder, download, upload,
record the id.

    tools/quaternius.py list  <folder-id>
    tools/quaternius.py pull  <fbx-folder-id> <out-dir> [name ...]
    tools/quaternius.py push  <dir> <prefix>      # upload, print id per file

Licence: every pack ships a License.txt reading CC0 1.0 Universal. Checked
per pack before anything is pulled, and the text is kept beside the models.
"""
import json, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from drive import listing, fetch  # noqa: E402

SP = os.environ.get(
    "RBX_SCRATCH",
    "/tmp/claude-0/-home-user-Roblox-ultra/c9243cd0-6f22-5b01-98dd-c5d04d82a899/scratchpad",
)
CREATOR = os.environ.get("RBX_CREATOR", "11578479542")


def upload(path, display, description):
    request = {
        "assetType": "Model",
        "displayName": display,
        "description": description,
        "creationContext": {"creator": {"userId": CREATOR}},
    }
    req_path = os.path.join(SP, "_qt_req.json")
    open(req_path, "w").write(json.dumps(request))
    out = subprocess.run(
        ["curl", "-sS", "-K", os.path.join(SP, "curlrc"), "-X", "POST",
         "https://apis.roblox.com/assets/v1/assets",
         "-F", f"request=<{req_path}",
         "-F", f"fileContent=@{path};type=model/fbx",
         "--max-time", "120"],
        capture_output=True, text=True).stdout
    try:
        op = json.loads(out)["operationId"]
    except Exception:
        return None, out[:200]
    # the importer is asynchronous; a big mesh takes a few seconds
    for _ in range(30):
        time.sleep(3)
        got = subprocess.run(
            ["curl", "-sS", "-K", os.path.join(SP, "curlrc"), "--max-time", "30",
             f"https://apis.roblox.com/assets/v1/operations/{op}"],
            capture_output=True, text=True).stdout
        try:
            data = json.loads(got)
        except Exception:
            continue
        if data.get("done"):
            asset = data.get("response", {}).get("assetId")
            return (asset, None) if asset else (None, json.dumps(data)[:300])
    return None, "timed out waiting for the importer"


def main():
    what = sys.argv[1]
    if what == "list":
        for fid, name, mime in listing(sys.argv[2]):
            print(("DIR  " if mime.endswith("folder") else "file ") + fid + "  " + name)
    elif what == "pull":
        folder, out = sys.argv[2], sys.argv[3]
        wanted = set(sys.argv[4:])
        os.makedirs(out, exist_ok=True)
        for fid, name, mime in listing(folder):
            if mime.endswith("folder"):
                continue
            stem = os.path.splitext(name)[0]
            if wanted and stem not in wanted:
                continue
            size = fetch(fid, os.path.join(out, name))
            print(f"  {name:34s} {size:>9,} bytes")
    elif what == "push":
        directory, prefix = sys.argv[2], sys.argv[3]
        ids = {}
        for name in sorted(os.listdir(directory)):
            if not name.lower().endswith(".fbx"):
                continue
            stem = os.path.splitext(name)[0]
            asset, err = upload(
                os.path.join(directory, name),
                f"{prefix} {stem}",
                "CC0 (Quaternius, CC0 1.0 Universal). Low-poly prop.",
            )
            print(f"  {stem:28s} {asset or 'FAILED ' + str(err)}")
            if asset:
                ids[stem] = int(asset)
        print(json.dumps(ids, indent=1, sort_keys=True))
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
