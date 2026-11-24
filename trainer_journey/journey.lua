-- journey.lua: the FireRed/LeafGreen journey as data.
--
-- Every entry has an id (its texts live in lang/<code>.lua under the same id)
-- and conditions written with the helpers below, checked against the save:
--   flag "NAME"     an event flag, by its name in the game's flag table
--   item(id)        a key item in the bag (FRLG item ids)
--   badges(n)       at least n badges
--   caught(n)       at least n kinds of Pokémon caught (Kanto Pokédex)
--   any{...}, all{...}
-- `go` (story and post-game) is where the on-screen arrow leads: a list of
-- { map, x, y, when }, the first whose `when` holds (or has none) wins; x/y
-- is the cell to point at once on that map (the person or the event).
-- `done` says the entry is finished. `open` says it can be done now (for the
-- spoiler filter and the "ready now" list); without it an entry is open once
-- the entries before it are done.
local function flag(name) return { flag = name } end
local function item(id) return { item = id } end
local function badges(n) return { badges = n } end
local function caught(n) return { caught = n } end
local function any(list) return { any = list } end
local function all(list) return { all = list } end

local ITEM = {
  HM07 = 345, OAKS_PARCEL = 349, POKE_FLUTE = 350, SECRET_KEY = 351, BIKE_VOUCHER = 352, GOLD_TEETH = 353,
  CARD_KEY = 355, LIFT_KEY = 356, SILPH_SCOPE = 359, BICYCLE = 360, TRI_PASS = 367, RAINBOW_PASS = 368, TEA = 369,
  RUBY = 373, SAPPHIRE = 374, SS_TICKET = 265,
}
local GAME_CLEAR = flag("FLAG_SYS_GAME_CLEAR")

local J = { ITEM = ITEM }

-- The main story, in the order it is usually played.
J.story = {
  { id = "starter", go = { { map = "FR_ROUTE_1" } }, done = flag("FLAG_SYS_POKEMON_GET") },
  { id = "parcel", go = { { map = "FR_OAKS_LAB", x = 6, y = 3, when = item(ITEM.OAKS_PARCEL) }, { map = "FR_VIRIDIAN_CITY_MART", x = 2, y = 3 } }, done = flag("FLAG_SYS_POKEDEX_GET") },
  { id = "brock", go = { { map = "FR_PEWTER_CITY_GYM", x = 6, y = 5 } }, done = flag("FLAG_BADGE01_GET") },
  { id = "cerulean", go = { { map = "FR_CERULEAN_CITY" } }, done = any({ flag("FLAG_WORLD_MAP_CERULEAN_CITY"), flag("FLAG_BADGE02_GET") }) },
  { id = "misty", go = { { map = "FR_CERULEAN_CITY_GYM", x = 8, y = 6 } }, done = flag("FLAG_BADGE02_GET") },
  { id = "bill", go = { { map = "FR_ROUTE_25_SEA_COTTAGE", x = 7, y = 5 } }, done = any({ flag("FLAG_GOT_SS_TICKET"), item(ITEM.SS_TICKET) }) },
  { id = "ssanne", go = { { map = "FR_SSANNE_CAPTAINS_OFFICE", x = 5, y = 4 } }, done = flag("FLAG_GOT_HM01") },
  { id = "surge", go = { { map = "FR_VERMILION_CITY_GYM", x = 5, y = 2 } }, done = flag("FLAG_BADGE03_GET") },
  { id = "lavender", go = { { map = "FR_LAVENDER_TOWN" } }, done = flag("FLAG_WORLD_MAP_LAVENDER_TOWN") },
  { id = "celadon", go = { { map = "FR_CELADON_CITY" } }, done = flag("FLAG_WORLD_MAP_CELADON_CITY") },
  { id = "erika", go = { { map = "FR_CELADON_CITY_GYM", x = 6, y = 4 } }, done = flag("FLAG_BADGE04_GET") },
  { id = "hideout", go = { { map = "FR_ROCKET_HIDEOUT_B4F", when = flag("FLAG_OPENED_ROCKET_HIDEOUT") }, { map = "FR_CELADON_CITY_GAME_CORNER", x = 11, y = 1 } }, done = any({ item(ITEM.SILPH_SCOPE), flag("FLAG_RESCUED_MR_FUJI") }) },
  { id = "tower", go = { { map = "FR_POKEMON_TOWER_7F", x = 11, y = 4 } }, done = flag("FLAG_RESCUED_MR_FUJI") },
  { id = "flute", go = { { map = "FR_LAVENDER_TOWN_VOLUNTEER_POKEMON_HOUSE", x = 3, y = 3 } }, done = flag("FLAG_GOT_POKE_FLUTE") },
  { id = "fuchsia", go = { { map = "FR_FUCHSIA_CITY" } }, done = flag("FLAG_WORLD_MAP_FUCHSIA_CITY") },
  { id = "koga", go = { { map = "FR_FUCHSIA_CITY_GYM", x = 7, y = 13 } }, done = flag("FLAG_BADGE05_GET") },
  { id = "surf", go = { { map = "FR_SAFARI_ZONE_SECRET_HOUSE", x = 6, y = 5 } }, done = flag("FLAG_GOT_HM03") },
  { id = "strength", go = { { map = "FR_FUCHSIA_CITY_WARDENS_HOUSE", x = 3, y = 5, when = item(ITEM.GOLD_TEETH) }, { map = "FR_SAFARI_ZONE_WEST" } }, done = flag("FLAG_GOT_HM04") },
  { id = "saffron", go = { { map = "FR_SAFFRON_CITY", when = flag("FLAG_GOT_TEA") }, { map = "FR_CELADON_CITY_CONDOMINIUMS_1F", x = 2, y = 9 } }, done = any({ flag("FLAG_WORLD_MAP_SAFFRON_CITY"), flag("FLAG_BADGE06_GET") }) },
  { id = "silph", go = { { map = "FR_SILPH_CO_11F", when = item(ITEM.CARD_KEY) }, { map = "FR_SILPH_CO_5F" } }, done = any({ flag("FLAG_HIDE_SAFFRON_ROCKETS"), flag("FLAG_BADGE06_GET") }) },
  { id = "sabrina", go = { { map = "FR_SAFFRON_CITY_GYM", x = 14, y = 11 } }, done = flag("FLAG_BADGE06_GET") },
  { id = "cinnabar", go = { { map = "FR_CINNABAR_ISLAND" } }, done = any({ flag("FLAG_WORLD_MAP_CINNABAR_ISLAND"), flag("FLAG_BADGE07_GET") }) },
  { id = "mansion", go = { { map = "FR_POKEMON_MANSION_B1F" } }, done = any({ item(ITEM.SECRET_KEY), flag("FLAG_BADGE07_GET") }) },
  { id = "blaine", go = { { map = "FR_CINNABAR_ISLAND_GYM", x = 5, y = 4 } }, done = flag("FLAG_BADGE07_GET") },
  { id = "sevii", go = { { map = "FR_CINNABAR_ISLAND_POKEMON_CENTER_1F", x = 11, y = 5 } }, optional = true, done = flag("FLAG_SEVII_DETOUR_FINISHED"), open = flag("FLAG_BADGE07_GET") },
  { id = "giovanni", go = { { map = "FR_VIRIDIAN_CITY_GYM", x = 2, y = 2 } }, done = flag("FLAG_BADGE08_GET") },
  { id = "league", go = { { map = "FR_INDIGO_PLATEAU_EXTERIOR" } }, done = any({ flag("FLAG_WORLD_MAP_INDIGO_PLATEAU_EXTERIOR"), GAME_CLEAR }) },
  { id = "elite", go = {
    { map = "FR_POKEMON_LEAGUE_CHAMPIONS_ROOM", x = 6, y = 8, when = flag("FLAG_DEFEATED_LANCE") },
    { map = "FR_POKEMON_LEAGUE_LANCES_ROOM", x = 6, y = 8, when = flag("FLAG_DEFEATED_AGATHA") },
    { map = "FR_POKEMON_LEAGUE_AGATHAS_ROOM", x = 6, y = 5, when = flag("FLAG_DEFEATED_BRUNO") },
    { map = "FR_POKEMON_LEAGUE_BRUNOS_ROOM", x = 6, y = 5, when = flag("FLAG_DEFEATED_LORELEI") },
    { map = "FR_POKEMON_LEAGUE_LORELEIS_ROOM", x = 6, y = 5 } }, done = GAME_CLEAR,
    parts = { "FLAG_DEFEATED_LORELEI", "FLAG_DEFEATED_BRUNO", "FLAG_DEFEATED_AGATHA", "FLAG_DEFEATED_LANCE" } },
}

-- After the Hall of Fame. The legendary birds can be met earlier; they are
-- listed here as optional.
J.post = {
  { id = "natdex", go = { { map = "FR_OAKS_LAB", x = 6, y = 3, when = caught(60) } }, done = flag("FLAG_SYS_NATIONAL_DEX"), open = GAME_CLEAR, need = 60 },
  { id = "ruby", go = { { map = "FR_MT_EMBER_RUBY_PATH_B5F", x = 7, y = 7 } }, done = any({ flag("FLAG_GOT_RUBY"), flag("FLAG_SYS_SEVII_MAP_4567") }) },
  { id = "rainbow", go = { { map = "SEVII_ONE_ISLAND_POKECENTER", x = 15, y = 6 } }, done = flag("FLAG_SYS_SEVII_MAP_4567") },
  { id = "sapphire", go = { { map = "FR_FIVE_ISLAND_ROCKET_WAREHOUSE", x = 27, y = 4, when = flag("FLAG_WORLD_MAP_SIX_ISLAND_DOTTED_HOLE_1F") }, { map = "FR_SIX_ISLAND_DOTTED_HOLE_SAPPHIRE_ROOM" } }, done = any({ flag("FLAG_RECOVERED_SAPPHIRE"), flag("FLAG_HIDE_CERULEAN_CAVE_GUARD") }) },
  { id = "network", go = { { map = "SEVII_ONE_ISLAND_POKECENTER", x = 15, y = 6 } }, done = flag("FLAG_HIDE_CERULEAN_CAVE_GUARD") },
  { id = "mewtwo", go = { { map = "FR_CERULEAN_CAVE_B1F", x = 7, y = 12 } }, done = flag("FLAG_FOUGHT_MEWTWO") },
  { id = "articuno", go = { { map = "FR_SEAFOAM_ISLANDS_B4F", x = 9, y = 2 } }, optional = true, done = flag("FLAG_FOUGHT_ARTICUNO"), open = all({ flag("FLAG_GOT_HM03"), flag("FLAG_GOT_HM04") }) },
  { id = "zapdos", go = { { map = "FR_POWER_PLANT", x = 5, y = 11 } }, optional = true, done = flag("FLAG_FOUGHT_ZAPDOS"), open = flag("FLAG_GOT_HM03") },
  { id = "moltres", go = { { map = "FR_MT_EMBER_SUMMIT", x = 9, y = 6 } }, optional = true, done = flag("FLAG_FOUGHT_MOLTRES"), open = flag("FLAG_GOT_HM06") },
}

-- HMs and key items: where they are and from when. `hm` is the HM number,
-- `badge` the badge that lets its move be used outside battle, `move` its move id.
J.items = {
  { id = "hm1", hm = 1, badge = 2, move = 15, done = flag("FLAG_GOT_HM01"), open = flag("FLAG_GOT_SS_TICKET") },
  { id = "hm5", hm = 5, badge = 1, move = 148, done = flag("FLAG_GOT_HM05"), open = all({ caught(10), flag("FLAG_SYS_POKEDEX_GET") }) },
  { id = "hm2", hm = 2, badge = 3, move = 19, done = flag("FLAG_GOT_HM02"), open = all({ flag("FLAG_GOT_HM01"), flag("FLAG_WORLD_MAP_CELADON_CITY") }) },
  { id = "hm3", hm = 3, badge = 5, move = 57, done = flag("FLAG_GOT_HM03"), open = flag("FLAG_WORLD_MAP_FUCHSIA_CITY") },
  { id = "hm4", hm = 4, badge = 4, move = 70, done = flag("FLAG_GOT_HM04"), open = flag("FLAG_WORLD_MAP_FUCHSIA_CITY") },
  { id = "hm6", hm = 6, badge = 6, move = 249, done = flag("FLAG_GOT_HM06"), open = flag("FLAG_SYS_SEVII_MAP_123") },
  { id = "hm7", hm = 7, badge = 7, move = 127, done = any({ item(ITEM.HM07), flag("FLAG_HIDE_FOUR_ISLAND_ICEFALL_CAVE_1F_HM07") }), open = flag("FLAG_SYS_SEVII_MAP_4567") },
  { id = "bicycle", done = flag("FLAG_GOT_BICYCLE"), open = flag("FLAG_GOT_BIKE_VOUCHER") },
  { id = "voucher", done = any({ flag("FLAG_GOT_BIKE_VOUCHER"), flag("FLAG_GOT_BICYCLE") }), open = flag("FLAG_WORLD_MAP_VERMILION_CITY") },
  { id = "oldrod", done = flag("FLAG_GOT_OLD_ROD"), open = flag("FLAG_WORLD_MAP_VERMILION_CITY") },
  { id = "vsseeker", done = flag("FLAG_GOT_VS_SEEKER"), open = flag("FLAG_WORLD_MAP_VERMILION_CITY") },
  { id = "coincase", done = flag("FLAG_GOT_COIN_CASE"), open = flag("FLAG_WORLD_MAP_CELADON_CITY") },
  { id = "tea", done = flag("FLAG_GOT_TEA"), open = flag("FLAG_WORLD_MAP_CELADON_CITY") },
  { id = "liftkey", done = any({ item(ITEM.LIFT_KEY), item(ITEM.SILPH_SCOPE), flag("FLAG_RESCUED_MR_FUJI") }), open = flag("FLAG_OPENED_ROCKET_HIDEOUT") },
  { id = "silphscope", done = any({ item(ITEM.SILPH_SCOPE), flag("FLAG_RESCUED_MR_FUJI") }), open = flag("FLAG_OPENED_ROCKET_HIDEOUT") },
  { id = "pokeflute", done = flag("FLAG_GOT_POKE_FLUTE"), open = flag("FLAG_RESCUED_MR_FUJI") },
  { id = "superrod", done = flag("FLAG_GOT_SUPER_ROD"), open = flag("FLAG_GOT_POKE_FLUTE") },
  { id = "goodrod", done = flag("FLAG_GOT_GOOD_ROD"), open = flag("FLAG_WORLD_MAP_FUCHSIA_CITY") },
  { id = "cardkey", done = any({ item(ITEM.CARD_KEY), flag("FLAG_HIDE_SAFFRON_ROCKETS") }), open = flag("FLAG_WORLD_MAP_SAFFRON_CITY") },
  { id = "secretkey", done = any({ item(ITEM.SECRET_KEY), flag("FLAG_BADGE07_GET") }), open = flag("FLAG_WORLD_MAP_CINNABAR_ISLAND") },
  { id = "tripass", done = any({ item(ITEM.TRI_PASS), flag("FLAG_SYS_SEVII_MAP_123") }), open = flag("FLAG_BADGE07_GET") },
  { id = "rainbowpass", done = any({ item(ITEM.RAINBOW_PASS), flag("FLAG_SYS_SEVII_MAP_4567") }), open = flag("FLAG_GOT_RUBY") },
}

-- What blocks the way, and what it takes: `hm` (with the badge and someone who
-- knows the move), `key` (an entry of J.items) or `badges`.
J.blocks = {
  { id = "trees", hm = "hm1" },
  { id = "dark", hm = "hm5" },
  { id = "fly", hm = "hm2" },
  { id = "water", hm = "hm3" },
  { id = "boulders", hm = "hm4" },
  { id = "rocks", hm = "hm6" },
  { id = "falls", hm = "hm7" },
  { id = "ship", key = "ssticket", have = any({ flag("FLAG_GOT_SS_TICKET"), item(ITEM.SS_TICKET) }), open = flag("FLAG_WORLD_MAP_VERMILION_CITY") },
  { id = "cycling", key = "bicycle" },
  { id = "lift", key = "liftkey" },
  { id = "ghosts", key = "silphscope" },
  { id = "snorlax", key = "pokeflute" },
  { id = "gates", key = "tea" },
  { id = "doors", key = "cardkey" },
  { id = "gym7", key = "secretkey" },
  { id = "badgegates", badges = 8, open = flag("FLAG_WORLD_MAP_VIRIDIAN_CITY") },
  { id = "sevii13", key = "tripass" },
  { id = "sevii47", key = "rainbowpass" },
}

-- Gifts for the number of kinds caught.
J.dex = {
  { id = "aide10", need = 10, done = flag("FLAG_GOT_HM05"), open = flag("FLAG_SYS_POKEDEX_GET") },
  { id = "aide20", need = 20, done = flag("FLAG_GOT_EVERSTONE_FROM_OAKS_AIDE"), open = flag("FLAG_SYS_POKEDEX_GET") },
  { id = "aide30", need = 30, done = flag("FLAG_GOT_ITEMFINDER"), open = flag("FLAG_SYS_POKEDEX_GET") },
  { id = "aide40", need = 40, done = flag("FLAG_GOT_AMULET_COIN_FROM_OAKS_AIDE"), open = flag("FLAG_SYS_POKEDEX_GET") },
  { id = "aide50", need = 50, done = flag("FLAG_GOT_EXP_SHARE_FROM_OAKS_AIDE"), open = flag("FLAG_SYS_POKEDEX_GET") },
  { id = "natdex", need = 60, done = flag("FLAG_SYS_NATIONAL_DEX"), open = GAME_CLEAR },
}

return J
