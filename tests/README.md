# Tests

`tests/main.lua` is a LÖVE program with a stand-in save (flags, bag, Pokédex, party) and a stand-in Trainer Desk. It walks a game from the first step to the post-game, checks the model and the panels' clicks, and saves screenshots.

```
cd tests
JOURNEY_MOD=../trainer_journey FLAGS_TABLE=<path to flags_table.lua> TEST_LANG=en \
  xvfb-run -a -s "-screen 0 1280x800x24" love .
```

`FLAGS_TABLE`, `WARPS_TABLE` and `CONNECTIONS_TABLE` are the game's generated flag table (`flags_table.lua`, `warps.lua`, `connections.lua` in `%APPDATA%\pokemon-love2d\firered\data\generated\gba\`), and `ENGINE_SRC` the game folder (for `src/core/game3/connections.lua`). Screenshots go to `TEST_OUT` (default `/tmp/journey_out`). The run ends with `ALL JOURNEY CHECKS PASSED`.
