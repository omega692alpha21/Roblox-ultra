#!/usr/bin/env python3
"""Copy pure game modules into tests/_build with Roblox datatypes injected."""
import os, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
BUILD = ROOT / "tests" / "_build"
BUILD.mkdir(exist_ok=True)
MODULES = {
    "GameConfig": "src/ReplicatedStorage/Config/GameConfig.luau",
    "Students": "src/ReplicatedStorage/Config/Students.luau",
    "Cliques": "src/ReplicatedStorage/Config/Cliques.luau",
    "Rebirths": "src/ReplicatedStorage/Config/Rebirths.luau",
    "Rewards": "src/ReplicatedStorage/Config/Rewards.luau",
    "Quizzes": "src/ReplicatedStorage/Config/Quizzes.luau",
    "Products": "src/ReplicatedStorage/Config/Products.luau",
    "Sounds": "src/ReplicatedStorage/Config/Sounds.luau",
    "NumberFormat": "src/ReplicatedStorage/Shared/NumberFormat.luau",
    "Palette": "src/ReplicatedStorage/Shared/Palette.luau",
}
HEADER = ('--!nocheck\n'
          'local __dt = require("./_datatypes")\n'
          'local Color3, Random = __dt.Color3, __dt.Random\n')
for name, rel in MODULES.items():
    src = (ROOT / rel).read_text()
    (BUILD / (name + ".luau")).write_text(HEADER + src)
# datatypes must sit next to the built modules for relative require
(BUILD / "_datatypes.luau").write_text((ROOT / "tests" / "_datatypes.luau").read_text())
print(f"built {len(MODULES)} modules into tests/_build")
