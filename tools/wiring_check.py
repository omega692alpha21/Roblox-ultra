#!/usr/bin/env python3
"""Find remotes and signals that are only half-connected.

A remote nobody listens to, or a signal nobody fires, is a feature that looks
finished in the source and does nothing in the game. Neither the type checker
nor the map tools can see it: both halves compile, they just never meet.

    python3 tools/wiring_check.py

Exit code is 1 if anything is orphaned.
"""
import os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")
SERVER = "ServerScriptService"
CLIENT = ("StarterPlayer", "StarterGui")


def files():
    for base, _, names in os.walk(ROOT):
        for name in names:
            if name.endswith(".luau"):
                path = os.path.join(base, name)
                rel = os.path.relpath(path, ROOT)
                yield rel, open(path).read()


def side(rel):
    top = rel.split(os.sep)[0]
    if top == SERVER:
        return "server"
    if top in CLIENT:
        return "client"
    return "shared"


def main():
    remotes_src = open(os.path.join(ROOT, "ReplicatedStorage", "Remotes.luau")).read()
    # the declared inventory: the EVENTS / FUNCTIONS name lists
    declared_events = set(re.findall(r'^\t"([A-Za-z0-9_]+)",', remotes_src, re.M))
    declared_funcs = set(re.findall(r'^\t\t"([A-Za-z0-9_]+)",', remotes_src, re.M))

    # how each name is used, per side
    fires = {}   # name -> set of sides that send
    listens = {} # name -> set of sides that receive
    signals_fired, signals_heard = {}, {}

    for rel, src in files():
        if rel.endswith(os.path.join("ReplicatedStorage", "Remotes.luau")):
            continue
        where = side(rel)
        for name in re.findall(r'Get(?:Function)?\("([A-Za-z0-9_]+)"\)\s*[:.]?\s*Fire[A-Za-z]*', src):
            fires.setdefault(name, set()).add((where, rel))
        for name in re.findall(r'Get(?:Function)?\("([A-Za-z0-9_]+)"\)\s*[:.]?\s*(?:On[A-Za-z]*Event:Connect|OnServerInvoke|OnClientInvoke|InvokeServer)', src):
            listens.setdefault(name, set()).add((where, rel))
        # the diagnostics reporter deliberately walks the Remotes folder by
        # hand -- the Remotes module is one of the things it exists to catch
        # failing -- so a bare FindFirstChild + FireServer counts as a send
        for name in re.findall(r'FindFirstChild\("([A-Za-z0-9_]+)"\)', src):
            if ":FireServer" in src or ":InvokeServer" in src:
                fires.setdefault(name, set()).add((where, rel))
        # a client calling InvokeServer is the sender, not the listener
        for name in re.findall(r'GetFunction\("([A-Za-z0-9_]+)"\)\s*:InvokeServer', src):
            fires.setdefault(name, set()).add((where, rel))
            listens.get(name, set()).discard((where, rel))

        for name in re.findall(r'Signals\.([A-Za-z0-9_]+):Fire', src):
            signals_fired.setdefault(name, set()).add(rel)
        for name in re.findall(r'Signals\.([A-Za-z0-9_]+):Connect', src):
            signals_heard.setdefault(name, set()).add(rel)

    bad = []
    for name in sorted(declared_events | declared_funcs):
        senders = {w for w, _ in fires.get(name, set())}
        receivers = {w for w, _ in listens.get(name, set())}
        if not senders and not receivers:
            bad.append(f"remote {name}: declared and never used at all")
        elif not senders:
            bad.append(f"remote {name}: listened for ({'/'.join(sorted(receivers))}) but nothing ever fires it")
        elif not receivers:
            bad.append(f"remote {name}: fired from {'/'.join(sorted(senders))} but nothing listens")

    declared_signals = set(re.findall(r'^\t([A-Za-z0-9_]+) = ', open(
        os.path.join(ROOT, "ServerScriptService", "Signals.luau")).read(), re.M))
    for name in sorted(declared_signals):
        if name not in signals_fired and name not in signals_heard:
            bad.append(f"signal {name}: declared and never used at all")
        elif name not in signals_fired:
            bad.append(f"signal {name}: connected in {', '.join(sorted(signals_heard[name]))} but never fired")
        elif name not in signals_heard:
            bad.append(f"signal {name}: fired in {', '.join(sorted(signals_fired[name]))} but nobody listens")

    for line in bad:
        print("  " + line)
    print(f"{len(declared_events | declared_funcs)} remotes, {len(declared_signals)} signals — "
          + (f"{len(bad)} orphaned" if bad else "everything is wired at both ends"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
