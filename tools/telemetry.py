#!/usr/bin/env python3
"""Read what actually went wrong on the live servers.

The game writes failures it cannot otherwise report -- a map build that threw,
a client whose UI self-check found missing panels -- into a DataStore, because
that is the only channel out of a running Roblox server to someone with no
Studio access. This reads them back.

    tools/telemetry.py            # everything, newest first
    tools/telemetry.py 10         # the newest ten

Needs an API key with universe-datastores.objects:list and :read, and the same
curlrc the publish script uses.
"""
import json, os, subprocess, sys, urllib.parse

SP = os.environ.get(
    "RBX_SCRATCH",
    "/tmp/claude-0/-home-user-Roblox-ultra/c9243cd0-6f22-5b01-98dd-c5d04d82a899/scratchpad",
)
UNIVERSE = os.environ.get("RBX_UNIVERSE", "10762834508")
STORE = os.environ.get("RBX_STORE", "ClientDiagnostics")
BASE = f"https://apis.roblox.com/cloud/v2/universes/{UNIVERSE}/data-stores/{STORE}"


def api(url):
    out = subprocess.run(
        ["curl", "-sS", "-K", os.path.join(SP, "curlrc"), "--max-time", "45", url],
        capture_output=True, text=True).stdout
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return {"_raw": out[:400]}


def main():
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    ids, token = [], None
    while True:
        url = f"{BASE}/entries?maxPageSize=100"
        if token:
            url += "&pageToken=" + urllib.parse.quote(token)
        page = api(url)
        if "dataStoreEntries" not in page:
            print("could not list entries:", page)
            return 1
        ids += [e["id"].split("/", 1)[-1] for e in page["dataStoreEntries"]]
        token = page.get("nextPageToken")
        if not token:
            break

    rows = []
    for entry_id in ids:
        got = api(f"{BASE}/entries/{urllib.parse.quote(entry_id)}?scope=global")
        value = got.get("value", {})
        rows.append((value.get("time", 0), entry_id, value))
    rows.sort(reverse=True)
    if limit:
        rows = rows[:limit]

    if not rows:
        print("nothing reported — no map failures and no client UI failures")
        return 0
    for when, entry_id, value in rows:
        print(f"\n=== {entry_id}")
        if value.get("build"):
            print(f"    build {value['build']}")
        if value.get("name"):
            print(f"    {value['name']} ({value.get('userId')})")
        text = value.get("err") or "\n".join(value.get("failures", []))
        for line in str(text).splitlines():
            print("    " + line)
    print(f"\n{len(rows)} of {len(ids)} report(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
