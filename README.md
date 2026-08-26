# Lunch Money Legends

> Build your crew. Steal theirs. Rule the school.

A Roblox steal-and-defend collection game wrapped in a school-life RPG, set at
**Crumbworth High**. Students walk the main hallway — recruit them into your
homeroom crew, and every crew member prints **lunch money** per second. Steal
students from unlocked enemy homerooms, lock your own base, farm **Aura**
(status), pass pop quizzes, join a clique, and graduate (rebirth) for permanent
multipliers.

Everything — the map, the student NPCs, the UI — is generated from code in this
repo. No Studio assets required.

## Project layout

```
default.project.json      Rojo tree
src/ReplicatedStorage/    Config (all balance + product IDs), shared utils, remotes
src/ServerScriptService/  Server bootstrap + all game services
src/StarterPlayer/        Client bootstrap + UI controllers
```

Key config files (tune the game without touching logic):

| File | What's in it |
|---|---|
| `Config/GameConfig.luau` | every knob: spawn rates, lock timing, offline caps, event flags |
| `Config/Students.luau` | the 36-student roster: rarities, odds, costs, income |
| `Config/Products.luau` | **game pass / dev product IDs — paste yours here** |
| `Config/Rebirths.luau` | grade costs, multipliers, aura rank ladder |
| `Config/Rewards.luau` | playtime chests, streaks, wheel, quests |
| `Config/Cliques.luau` | the four cliques and their perks |
| `Config/Quizzes.luau` | pop-quiz question pool |

## Getting it into Roblox Studio

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in the repo root:
   ```
   rokit install
   rojo serve
   ```
2. In Roblox Studio, install the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/),
   open a new Baseplate place (delete the baseplate), and click **Connect** in the plugin.
   - Or build a place file directly: `rojo build default.project.json -o LunchMoneyLegends.rbxl` and open it.
3. Press Play. The whole school generates at runtime; you should spawn at the bus stop.

Multiplayer stealing/locking is best tested via **Test → Clients and Servers → 2 players** in Studio.

## Launch checklist (things only you can do)

1. **Publish**: File → Publish to Roblox.
2. **Enable DataStores in Studio testing**: Game Settings → Security →
   *Enable Studio Access to API Services* (saves + leaderboards won't work in Studio without it).
3. **Create monetization on the Creator Dashboard** (your experience → Monetization):
   - Game passes: `2x Lunch Money` (R$199), `Auto-Collect` (R$149), `+2 Crew Slots` (R$249),
     `Extended Lock` (R$179), `Speed Sneakers` (R$99)
   - Developer products: `Small Stack` (R$49), `Backpack of Cash` (R$149), `Locker of Cash`
     (R$399), `Vault of Cash` (R$999), `5 Wheel Spins` (R$75), `Legendary Crate` (R$299)
   - Paste every numeric ID into `src/ReplicatedStorage/Config/Products.luau`
     (anything left at `0` shows as "SOON" in-game and is safely disabled).
4. **Create a Roblox group**, set its ID in `Products.luau` (`GroupId`) so the
   join-group reward works — and so revenue can pay out to the group.
5. **Art**: game icon + 3 thumbnails (suggested hooks: "STEAL FROM YOUR FRIENDS",
   the rarity wall, the clique lineup).
6. **Age guidelines questionnaire**: the game has mild cartoon violence (knockback
   punches, no damage) and social stealing — answer accordingly.
7. Set the experience to **Public**. For events, flip `EventLuckMultiplier` /
   `EventCashMultiplier` in `GameConfig.luau` and publish an update.

## Design notes

- **Server-authoritative**: clients only send intent (prompts, button presses).
  Prices, odds, income, steal transitions, and quiz answers all live server-side.
- **Data safety**: session-locked DataStore saves with retries; purchases are
  idempotent and force-saved before being acknowledged; a failed load disables
  play instead of risking a wipe.
- **Students are real avatars**: R15 rigs generated via `HumanoidDescription`
  with deterministic per-character looks and part-built props — swap in Creator
  Store meshes later if you want fancier characters.
