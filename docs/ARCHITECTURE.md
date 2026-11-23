# Architecture

```
trainer_journey/
  manifest.json
  main.lua      reads the save, builds the model, registers the panels with Trainer Desk
  journey.lua   the journey as data: story, post-game, items, obstacles, Pokédex rewards
  panel.lua     draws the two panels and handles clicks
  i18n.lua      language and fonts (the same file as in the other Trainer mods)
  lang/         texts: en (reference), es, pt, ja
  fonts/        Noto Sans JP subset for Japanese
```

## The data

`journey.lua` returns five lists. Each entry has an `id` (its texts are `STEPS`, `ITEMS`, `BLOCKS` or `DEX` entries in `lang/*.lua`) and conditions:

| Condition | True when |
| --- | --- |
| `flag "NAME"` | the event flag is set (names from the game's flag table) |
| `item(id)` | the key item is in the bag |
| `badges(n)` | at least n badges |
| `caught(n)` | at least n kinds caught in the Kanto Pokédex |
| `any{...}`, `all{...}` | combinations |

- `done`: the entry is finished.
- `open`: it can be done now. Story entries without `open` are open when they are the first unfinished one.
- `optional`: not counted in the progress and never the "next step".
- Items with `hm`, `badge` and `move` also report field use and whether the party knows the move.
- Obstacles name an HM (`hm`) or a key item (`key`) from the items list, or a number of `badges`.

## Deciding the next step

`chain()` walks the story in order: done entries are done, the first unfinished required entry is the current one, optional entries are open or later, everything else is later. The post-game list goes through the same function, gated by `FLAG_SYS_GAME_CLEAR`. The next step is the story's current entry, or the post-game's once the story is done.

## Reading the save

`reader()` collects, once per model:

- flags through `src.core.game3.scripting.flags` (`Flags.active(session).IDS` names to ids, `Flags.getFlag` on the store from `scripting.space`);
- bag counts through `src.core.game3.bag`;
- kinds caught through `src.core.game3.dex` (`countCaught(dex, "kanto")`);
- the party's move ids from `session.party`;
- the game family through `src.core.game3.profile` (Ruby/Sapphire/Emerald are not guided).

The model is rebuilt at most twice a second. With spoilers hidden, rows whose status is "later" are marked `masked` and the panel draws them as one summary row.

## Panels

`main.lua` registers `trainer_journey.next` (side right) and `trainer_journey.journey` (side bottom) with Trainer Desk's dock API (`mod.find("trainer_desk").exports.dock`, API 1) on `core.update`, again when the language changes, and takes them away when the dock is turned off or the player quits to the launcher. Both are responsive: they are laid out on a fixed sheet (480x432 and 480x240) and stretched to the room the dock gives them.

The spoiler choice is kept in the mod cache under `spoilers` ("1" or "0").
