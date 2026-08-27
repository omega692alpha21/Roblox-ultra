# DETENTION (live) · club prototypes (parked)

> The school where lunch money runs everything.

**DETENTION is the live game again** (universe `10762834508`, place
`81310619434390`, restored at build 55): the steal-and-defend school RPG —
recruit students in the Main Hallway, steal from unlocked homerooms, punch
thieves, farm aura, graduate, survive curfew. Source under `src/`, built by
the root `default.project.json`.

The club-era prototypes (MILLIONS CLUB / CULT / ROBES) live under `club/`,
parked but complete; their game passes are off sale. Their store-page pass
ids and the asset registry are recorded in `club/src/ReplicatedStorage/ClubConfig.luau`.

---

## Previous README (club era) below

# CULT

> Find us. Solve it. Enter. Rise.

A social mystery MMO on Roblox. There is a house at the end of a dark path with
no sign on it and a door that does not open. Nothing in the game tells you what
it is or how to get in — the way in is written across the grounds in four
places, and the code is rolled fresh on every server, so the *method* can spread
and the answer never can.

Solve it and you are an INITIATE. After that, the only thing that matters is
**REP**, and REP buys rank, and rank opens doors that lower ranks can see but
cannot pass. A player who spends nothing can become one of the most respected
people in the game. Nothing that matters is for sale.

Live: universe `10762834508`, place `81310619434390`.

## The loop

DISCOVER → SOLVE → ENTER → EARN REP → UNLOCK → DISCOVER DEEPER → RISE

| Rank | REP | What opens |
|---|---|---|
| INITIATE | 0 | The entrance hall and the Grand Hall |
| MEMBER | 100 | Convocations, the directory, the board |
| INSIDER | 300 | The private corridor |
| OPERATOR | 750 | The undercroft |
| ARCHITECT | 1,500 | The rooftop — and tools to author puzzles |
| INNER CIRCLE | 3,000 | The unmarked door |

REP comes from initiation, hidden sigils, attending Convocations, completing
missions, and guiding someone else through their initiation. The first hundred
people to solve their way in, ever, become **THE FOUNDING HUNDRED** — an atomic
`UpdateAsync` roster that closes for good at 100.

## Project layout

```
club/default.project.json          Rojo tree (the live game builds from here)
club/src/ReplicatedStorage/        ClubConfig (ranks, REP values, asset ids), remotes
club/src/ServerScriptService/      ClubMap, Initiation, Rep, Gates, Convocation,
                                   Missions, Membership, Profiles, Robes, bootstrap
club/src/StarterPlayer/            Keypad, rank chip, initiation cinematic, the board
```

Everything is generated from code — the estate, the hall, the robes. Custom
textures and meshes are authored in Python, uploaded through the Open Cloud
Assets API, and loaded at runtime (`InsertService` + node-name recolor, because
Roblox's GLB import drops glTF material colors).

## Robes

Every character is stripped and dressed server-side in a hooded black shroud:
no face, no skin, no name above the head. The only thing that distinguishes
anyone is the trim color, and the trim is rank.

## Monetization

**PATRON** (pass `1962348330`, 499 R$) is gold thread on a robe and a mark on
the plaque by the fire. It grants no rank, no door, and no REP, by design.

## Build & publish

```
rojo build club/default.project.json -o CULT.rbxl
```

Publishing goes through the Open Cloud place-versions API, followed by
`restartServers` so live servers pick up the version immediately.

---

*A previous game in this repo (DETENTION / Lunch Money Legends, under `src/`) is
retired and no longer published; the source is kept for parts salvage only.*
