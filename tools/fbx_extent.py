#!/usr/bin/env python3
"""Measure a binary FBX's bounding box, in its own units.

The Poly Haven props are glTF and get measured by reading the accessor min/max
out of the JSON. The Quaternius props are FBX -- Roblox's importer takes them
directly, so nothing ever repacked them and nothing ever measured them, which
left fifty props with no footprint at all. A prop with no footprint is a prop
no check can test.

Binary FBX is a tree of nodes, each: end offset, property count, property list
length, name length, name, then the properties. Vertex positions live in a
'Vertices' node as a 'd' (double array) property. That is all this needs.
"""
import struct, sys, zlib


def read_props(buf, off, count):
    out = []
    for _ in range(count):
        code = chr(buf[off]); off += 1
        if code in "CBYIL FD":
            size = {"C": 1, "B": 1, "Y": 2, "I": 4, "L": 8, "F": 4, "D": 8}.get(code)
            if size is None:
                continue
            out.append((code, buf[off:off + size])); off += size
        elif code in "fdlbic":
            length, encoding, comp_len = struct.unpack("<III", buf[off:off + 12]); off += 12
            raw = buf[off:off + comp_len]; off += comp_len
            if encoding == 1:
                raw = zlib.decompress(raw)
            out.append((code, (length, raw)))
        elif code in "SR":
            (length,) = struct.unpack("<I", buf[off:off + 4]); off += 4
            out.append((code, buf[off:off + length])); off += length
        else:
            raise ValueError("unknown FBX property code " + repr(code))
    return out, off


def walk(buf, off, end, version, found):
    while off < end:
        if version >= 7500:
            end_off, num_props, _plen = struct.unpack("<QQQ", buf[off:off + 24]); off += 24
            name_len = buf[off]; off += 1
        else:
            end_off, num_props, _plen = struct.unpack("<III", buf[off:off + 12]); off += 12
            name_len = buf[off]; off += 1
        if end_off == 0:
            return
        name = buf[off:off + name_len].decode("ascii", "replace"); off += name_len
        props, off = read_props(buf, off, num_props)
        if name == "Vertices":
            for code, value in props:
                if code == "d":
                    count, raw = value
                    found.append(struct.unpack("<%dd" % count, raw[: count * 8]))
        walk(buf, off, end_off, version, found)
        off = end_off


def extent(path):
    buf = open(path, "rb").read()
    if buf[:21] != b"Kaydara FBX Binary  \x00":
        raise ValueError("not a binary FBX: " + path)
    (version,) = struct.unpack("<I", buf[23:27])
    found = []
    walk(buf, 27, len(buf), version, found)
    lo = [1e30] * 3
    hi = [-1e30] * 3
    for verts in found:
        for i in range(0, len(verts) - 2, 3):
            for axis in range(3):
                v = verts[i + axis]
                lo[axis] = min(lo[axis], v)
                hi[axis] = max(hi[axis], v)
    if lo[0] > hi[0]:
        raise ValueError("no vertices in " + path)
    return lo, hi


if __name__ == "__main__":
    for path in sys.argv[1:]:
        lo, hi = extent(path)
        print(path.split("/")[-1], [round(hi[i] - lo[i], 3) for i in range(3)])
