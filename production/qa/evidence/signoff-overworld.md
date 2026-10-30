# Overworld Visual Sign-off

Lead sign-off for Visual/Feel and UI evidence in the Overworld Exploration &
Encounters epic. Each entry names the retained evidence it covers. The
evidence is placeholder art (graybox sets, placeholder sprites and labels);
signing off says the shot proves the story's claim, not that the art is final.

## 2026-10-30 — signed off by the user (acting art director)

The user signed off all overworld visual evidence captured in the
2026-10-29/30 build run ("sign off everything").

| Story | Claim | Evidence |
|---|---|---|
| 076 (AC-30i) | From the pre-dungeon CampSpot's safe-zone edge, facing the Counter, the Permit Counter is on screen | `story-075-camps-checkpoints/02-dungeon-counter-and-boom-from-camp-edge.png` (retaken after the story 085 dungeon redesign) |
| 075 / 113 | The Town café camp prompt ("Rest here?", Yes focused); the boss chamber with the Supervisor | `story-075-camps-checkpoints/01-town-cafe-rest-prompt.png`, `03-boss-chamber-supervisor.png` |
| 007 | Followers snap into formation behind the leader | `story-007-follower-snap/01-trail-before-reset.png`, `02-snapped-after-teleport.png` |
| 091 | Ticket prompt at the Counter, "Take a number." bark, the "number called" line | `story-091-permit-counter/01-03` |
| 089 | The interim Camp mode card | `story-089-camp-retreat/01-camp-card.png` |
| 011-016 | Talk prompt over the NPC, Look prompt over the clue poster, the poster's line | `story-015-interact-prompt/01-03` |
| 085 | The dungeon hall wall with its near (watched) and far gaps | `story-085-pressure-floor/01-hall-wall-two-gaps.png` |

Known placeholder limits accepted with this sign-off: the near south walls
can hide the party (the GDD cut-away rule is unbuilt), and prompts, barks and
the camp card are interim labels until stories 015/108/130 and the Camp &
Party Management system replace them.

## Sign-off: story 087 patrol walk-ins (2026-10-30)

**Signed off by:** the user, acting as art director ("sign off 087"), 2026-10-30.

| Story | Claim | Evidence |
|---|---|---|
| 087 (AC-39 VF) | Every symbol's patrol is on screen, unoccluded, from every approach before the leader can be noticed: 46 approaches across the segment and dungeon, all 100% visible, none clipped | `story-087-patrol-visibility/report.md` and its 46 PNGs, captured at the 12 m camera (story 099) after the level-design pass (stories 086/119/103) |

Noted with this sign-off: the dungeon north-west Clerk sits near the top
edge of the frame on its 270° approach (`..._hall_north_west__s6.png`),
visible and accepted.

## Narrative sign-off (AC-51) 2026-10-30

**Reviewer:** narrative-director (autonomous run, user asleep). Each line is a
line-only item (GDD rule 18): it ticks (a), nothing from guardrail 6's
exclusion list, plus the lines-only composite read ("does this read as
occupied 1940s Paris, or as border control, with the faction swapped in?",
answer must be no). Also checked against narrative bible §4 (Bureaucratia),
§5 (battle cry stays with the squad), §8.3 (G-1..G-10) and §9 (short lines,
≤ 120 characters, localization-ready).

**Still owed for full AC-51:** the art-director co-signature on tick (a), and
transfer of these entries, with content hashes, into
`design/gdd/reviews/overworld-narrative-signoff.md` (the record rule 18 names).

| # | Story | Item (record) | Line (final) | (a) | Composite | Verdict |
|---|---|---|---|---|---|---|
| 1 | 055 | Stage 1 subtitle (`ostage_bureaucratia_stage1.tres`) | "Paperwork pending" | ✓ | ✓ | PASS |
| 2 | 055 | Stage 2 subtitle (`ostage_bureaucratia_stage2.tres`) | "Permits now mandatory" | ✓ | ✓ | PASS. Echoes the `permits_mandatory` decree |
| 3 | 055 | Stage 3 subtitle (`ostage_bureaucratia_stage3.tres`) | "Please take a number" | ✓ | ✓ | PASS. Queue numbers, never people; ties to the Counter's "Take a number." |
| 4 | 063 | Town liberation reaction, café owner, `ribs_squad` (`paris_town_placeholder.tscn`, `npc_cafe_owner_sweeping`) | "You liberated the street. Lovely. Who is liberating my broom?" | ✓ | ✓ | PASS. The tag is honest: it deflates the squad's grand "liberation" and leaves the owner with the cleanup. No crowd, no celebration (rule 17) |
| 5 | 063 | Segment liberation reaction, street sweeper, `ribs_squad` (`paris_segment_placeholder.tscn`, `npc_street_sweeper`) | "Twelve thousand posters, and you lot leave every one of them on my pavement." | ✓ | ✓ | PASS. The tag is honest: the squad is blamed for the mess |
| 6 | 068 | Boss post-battle line (`enc_paris_supervisor.tres`, `post_battle_line`) | "The Supervisor stamps his own resignation APPROVED, in triplicate. Nobody cheers. Somebody asks if the counter is open." | ✓ | ✓ | **REVISE** (done). Old line was 148 characters, over the 120 limit, and ended in a bare stage direction ("Walk home.") that reads as UI, not voice. Old: "The Supervisor signs his own resignation in triplicate and stamps it APPROVED. Nobody cheers. Somebody asks if the counter is still open. Walk home." → New: as shown (120 characters; keeps "resignation" for `walk_home_after_boss_victory_test.gd`). Works with either boss choice (§6.2) |
| 7 | 051 | Segment pocket gate (`cp_segment_pocket` failure line) | "The courtyard gate is chained. A tag reads: ARCHIVE. FILED UNDER NO." | ✓ | ✓ | PASS. "Filed under No" is a light pun; flagged for the localizer |
| 8 | 051 | Dungeon shortcut gate (`cp_dungeon_shortcut` failure line) | "Bolted. A note on the door: STAFF ONLY. STAFF ARE ON A BREAK." | ✓ | ✓ | PASS |
| 9 | 051 | Dungeon pocket gate (`cp_dungeon_pocket` failure line) | "Locked. The sign says: STAMPS. AUTHORISED HANDS ONLY." | ✓ | ✓ | PASS. Restricts stamps, not people |
| 10 | 051 | Stamp cupboard gag (`gag_stamp_cupboard`) | "You knock over a rack of rubber stamps. APPROVED, APPROVED, DENIED, APPROVED." | ✓ | ✓ | PASS. The squad looks clumsy (tick (d) material) |
| 11 | 051 | Archive courtyard gag (`gag_archive_courtyard`, `paris_segment_placeholder.tscn`) | "You tip over a filing cabinet. Forty kilos of permits to apply for permits slide out." | ✓ | ✓ | **REVISE** (done). "Forty years" contradicts canon: permits-for-permits is Bureaucratia's own decree, "in force since Tuesday", and reading it as Paris's own old paperwork would make the joke about being French (guardrail 3). Old: "...Forty years of permits to apply for permits slide out." → New: "...Forty kilos of permits to apply for permits slide out." The same string in `tools/maps/build_segment_pocket.gd` was synced so a rebuild keeps it |
| 12 | 051 | Rolled-poster tell text (`tell_west_poster`, `tell_first_room_poster`, `tell_hall_poster`) | "A rolled-up poster sticks out of the Clerk's in-tray." | ✓ | ✓ | PASS. In-tray styling matches the decree-poster brief |
| 13 | 051 | New clue stub, facet `clerks_wait` (`enc_paris_clerks_hall.tres`) | "Rumour: until the permit comes, Clerks hide behind their desks. Look weak, though, and they all go for you." | ✓ | ✓ | **REVISE** (done). Old text described only half the rule and got it wrong ("just shove. Plain attacks"); the built AI defends behind a weak jab and focuses the weakest squad member (`faction-rule-modifiers.md`), and the clue must let players predict that (tick (e)). Old: "Rumour: while they wait for their permit, Clerks just shove. Plain attacks, nothing special." → New: as shown. Tick (e), the playtest comprehension check, is still owed |

The recruit remarks (`remark_paris_archive_courtyard`,
`remark_paris_stamp_cupboard`) are IDs only until Squad Roster exists; they
are not signed off here.
