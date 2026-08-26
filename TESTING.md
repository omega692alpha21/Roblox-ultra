# Release checklist — nothing goes public until every box is ticked

## Automated (runs on every push via GitHub Actions, or `tests/run.sh` locally)
- [x] `rojo build` — the whole tree assembles into a valid place
- [x] `luau-lsp analyze` — zero type/lint errors across all 40+ modules
- [x] 519 unit tests — economy math, roster integrity, rarity/mutation odds,
      grade cost curve, aura ranks, reward tables, quiz answer keys, product configs

## Phase 1 — solo playtest (published PRIVATE, owner only)
- [ ] Join: spawn at bus stop, map fully generates, no errors in console
- [ ] Tutorial card appears and dismisses
- [ ] Recruit a student from the hallway; it walks nowhere but appears at your desk
- [ ] Income ticks; pile grows; collect pad banks it (particles + sound)
- [ ] Buy several; fuse 3 duplicates in the Crew panel → Star student
- [ ] Lock switch arms the gate; timer shows in HUD; cooldown enforced
- [ ] Class bell fires; quiz answers pay out; wrong answers lose 1 aura
- [ ] School day cycles in HUD (Free Period → Class → Lunch Rush 1.5x)
- [ ] Talk to all 3 mission characters; complete one mission each
- [ ] Rewards panel: claim a playtime chest; spin the wheel; streak shows
- [ ] Join a clique at the courtyard; perk applies (Jocks = faster)
- [ ] Graduate (grade 1): crew resets, multiplier rises, badge updates
- [ ] **Rejoin**: cash/crew/grade/aura/streak all persisted (DataStores)

## Phase 2 — 2-player test (invite ONE friend, still private)
- [ ] Second player gets their own homeroom
- [ ] Steal flow: grab from unlocked base → carry (slow, marked) → deposit
- [ ] Owner alarm fires; punch recovers the student; thief loses 5 aura
- [ ] Lock blocks the thief; gate bounces them
- [ ] Bounty crown appears on the richer player; robbing them pays bonus aura
- [ ] Thief leaves mid-carry → student returns; no duplication either side
- [ ] Both rejoin: no data loss, no duplicated students

## Phase 3 — monetization test (products created, still private)
- [ ] Every pass buyable with test purchase; effect applies immediately
- [ ] Cash pack grants scale with grade multiplier
- [ ] Legendary Crate grants (or refunds when crew full)
- [ ] Kill the client mid-purchase → rejoin → purchase honored exactly once

## Phase 4 — go public
- [ ] Icon + thumbnails uploaded
- [ ] Age questionnaire done
- [ ] Group created + GroupId in Products.luau
- [ ] Flip to Public. Watch the first 50 sessions like a hawk.

Rule: any failed box = fix first. No exceptions.
