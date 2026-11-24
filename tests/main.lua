-- Checks for Trainer Journey: a stand-in save (flags, bag, Pokédex, party) and
-- a stand-in Trainer Desk that only records the panels and draws them.
local OUT = os.getenv("TEST_OUT") or "/tmp/journey_out"
local DIR = os.getenv("JOURNEY_MOD")
local FLAGS_TABLE = os.getenv("FLAGS_TABLE") or "/tmp/gd/flags_table.lua"
local G = love.graphics
local function reader(dir) return function(name) local f = io.open(dir .. "/" .. name, "rb"); if not f then return nil end; local s = f:read("*a"); f:close(); return s end end
function love.errorhandler(msg) print("HARNESS ERROR", msg, debug.traceback()); return function() return 1 end end
local function check(cond, msg) if not cond then error("CHECK FAILED: " .. msg, 2) end; print("ok  " .. msg) end

function love.load()
  os.execute("mkdir -p " .. OUT)
  local names = dofile(FLAGS_TABLE).FLAGS
  local store = { flags = {} }
  local function set(name, on) store.flags[assert(names[name], name)] = on ~= false or nil end
  local family = "frlg"
  package.preload["src.core.game3.scripting.flags"] = function() return { IDS = names,
    getFlag = function(s, _, id) return s.flags[id] == true end } end
  package.preload["src.core.game3.scripting.space"] = function() return { getStore = function() return store end } end
  package.preload["src.core.game3.bag"] = function() return { get = function(bag, id) return bag[id] or 0 end } end
  package.preload["src.core.game3.dex"] = function() return { countCaught = function(dex, which) assert(which == "kanto"); return dex.caught end } end
  -- maps: the game's warps and connections, a made-up size for each map
  local ENGINE = os.getenv("ENGINE_SRC") or "/tmp/eng"
  package.preload["src.core.game3.connections"] = function() return dofile(ENGINE .. "/src/core/game3/connections.lua") end
  local warps = dofile(os.getenv("WARPS_TABLE") or "/tmp/gd/warps.lua")
  local conns = dofile(os.getenv("CONNECTIONS_TABLE") or "/tmp/gd/connections.lua")
  local mapdefs = {}
  for id, list in pairs(warps) do mapdefs[id] = { warps = list, connections = conns[id] or {}, midLayout = { width = 40, height = 40 } } end
  local MapStub, PlayerStub = { current = nil }, { cellX = 5, cellY = 5, px = 80, py = 80 }
  package.preload["src.core.game3.map"] = function() return MapStub end
  package.preload["src.core.game3.player"] = function() return PlayerStub end
  local battling = false
  package.preload["src.core.game3.battle"] = function() return { isActive = function() return battling end } end
  package.preload["src.world.game3.WorldAPI"] = function() return { new = function() return {
    availableFieldActions = function() return {}, nil end } end } end
  package.preload["src.core.game3.profile"] = function() return { forSession = function() return { family = family } end } end

  local logs = {}
  -- the stand-in dock
  local panels, active = {}, true
  local dock = { exports = { dock = { api = 1, active = function() return active end,
    register = function(def) panels[def.id] = def end, unregister = function(id) panels[id] = nil end,
    theme = function() return { colors = {} } end } } }
  local registry = { trainer_desk = dock }
  -- load the mod with the registry visible to find()
  local cache = {}
  local mod
  do
    local read = reader(DIR)
    mod = { id = "trainer_journey", options_ = {}, hooks_ = {}, events_ = {}, exports = {}, cache_ = cache, registry = registry }
    mod.read = function(_, n) return read(n) end
    mod.options = { define = function(_, s) for _, row in ipairs(s) do if mod.options_[row.key] == nil then mod.options_[row.key] = row.default end end
      if os.getenv("TEST_LANG") then mod.options_.language = os.getenv("TEST_LANG") end end,
      get = function(_, k) return mod.options_[k] end }
    mod.hooks = { wrap = function(_, n, f) mod.hooks_[n] = f end }
    mod.events = { on = function(_, n, f) mod.events_[n] = f end }
    mod.log = { warn = function(_, f, ...) logs[#logs + 1] = f:format(...); print("WARN", logs[#logs]) end, info = function() end }
    mod.cache = { read = function(_, k) return mod.cache_[k] end, write = function(_, k, v) mod.cache_[k] = v; return true end }
    mod.find = function(other) return registry[other] end
    assert(loadstring(read("main.lua"), "@trainer_journey/main.lua"))()(mod)
  end

  local session = { bag = {}, dex = { caught = 0 }, party = { { species = 4, moves = { 10, 45 } } } }
  local game = { generation = 3, session = session, data = { maps = mapdefs } }
  local function update() mod.hooks_["core.update"](function() end, game, 1 / 60) end
  local function model() return mod.exports.debugModel() end
  local function find(list, id) for _, row in ipairs(list) do if row.id == id then return row end end end

  update()
  check(next(panels) == nil, "nothing is docked before a game is running")
  mod.events_["game.ready"]({ game = game })
  update()
  check(panels["trainer_journey.journey"] and panels["trainer_journey.next"], "both panels are docked")
  check(panels["trainer_journey.next"].side == "right" and panels["trainer_journey.journey"].pointer ~= nil, "panel sides and pointer")

  local m = model()
  check(m.next and m.next.id == "starter", "a new game starts with choosing a Pokémon")
  check(m.spoilers == false, "upcoming steps are hidden by default")
  local masked = 0
  for _, row in ipairs(m.lists.story) do if row.masked then masked = masked + 1 end end
  check(masked == #m.lists.story - 1, "only the current step is named: " .. masked)

  set("FLAG_SYS_POKEMON_GET"); set("FLAG_SYS_POKEDEX_GET"); set("FLAG_BADGE01_GET")
  m = model()
  check(m.next.id == "cerulean" and m.story.done == 3 and m.badges == 1, "flags move the journey on: " .. m.next.id)
  check(find(m.lists.dex, "aide10").note:find("10", 1, true), "the first aide waits for 10 kinds")

  -- Pokédex gifts
  session.dex.caught = 12
  m = model()
  check(find(m.lists.dex, "aide10").status == "ready", "10 kinds caught: the gift is ready")
  check(m.ready[1] and m.ready[1].kind == "dex", "the ready gift is listed first on the next-step panel")

  -- an HM to teach
  set("FLAG_WORLD_MAP_CERULEAN_CITY"); set("FLAG_BADGE02_GET"); set("FLAG_GOT_SS_TICKET"); set("FLAG_GOT_HM01")
  m = model()
  local teach
  for _, r in ipairs(m.ready) do if r.kind == "teach" then teach = r end end
  check(teach ~= nil, "HM01 and the Cascade Badge but nobody knows Cut: teach it")
  check(find(m.lists.blocks, "trees").status == "open", "small trees still need someone with Cut")
  session.party[1].moves = { 15, 45 }
  m = model()
  check(find(m.lists.blocks, "trees").status == "done", "with Cut known, small trees can be passed")
  for _, r in ipairs(m.ready) do check(r.kind ~= "teach", "nothing left to teach") end
  check(m.next.id == "surge", "on to Lt. Surge: " .. m.next.id)

  -- a key item in the bag finishes a step that has no flag of its own
  for _, name in ipairs({ "FLAG_BADGE03_GET", "FLAG_WORLD_MAP_LAVENDER_TOWN", "FLAG_WORLD_MAP_CELADON_CITY", "FLAG_BADGE04_GET" }) do set(name) end
  m = model()
  check(m.next.id == "hideout", "after Erika: the Rocket Hideout")
  session.bag[359] = 1
  m = model()
  check(m.next.id == "tower" and find(m.lists.items, "silphscope").status == "done", "the Silph Scope in the bag finishes the hideout")

  -- optional side trip
  for _, name in ipairs({ "FLAG_RESCUED_MR_FUJI", "FLAG_GOT_POKE_FLUTE", "FLAG_WORLD_MAP_FUCHSIA_CITY", "FLAG_BADGE05_GET", "FLAG_GOT_HM03", "FLAG_GOT_HM04",
    "FLAG_WORLD_MAP_SAFFRON_CITY", "FLAG_HIDE_SAFFRON_ROCKETS", "FLAG_BADGE06_GET", "FLAG_WORLD_MAP_CINNABAR_ISLAND", "FLAG_BADGE07_GET" }) do set(name) end
  m = model()
  check(m.next.id == "giovanni", "the optional Sevii trip does not stand in the way: " .. m.next.id)
  check(find(m.lists.story, "sevii").status == "open" and not find(m.lists.story, "sevii").masked, "the Sevii trip is open and shown")

  -- the journey panel: draw, switch tabs and the spoiler switch with the pointer
  local canvas = G.newCanvas(480, 432)
  local function draw(id, w, h, name)
    w, h = w or 480, h or 432
    local c = G.newCanvas(w, h)
    G.setCanvas(c); G.clear(0, 0, 0, 1)
    local depth = G.getStackDepth()
    panels[id].draw(1, w, h)
    check(G.getStackDepth() == depth, "the stack is balanced after drawing " .. id)
    G.setCanvas()
    if name then local f = io.open(OUT .. "/" .. name .. ".png", "wb"); f:write(c:newImageData():encode("png"):getString()); f:close() end
    return c
  end
  local lang = os.getenv("TEST_LANG") or "en"
  draw("trainer_journey.journey", 480, 432, "journey-story-" .. lang)
  draw("trainer_journey.next", 480, 240, "next-" .. lang)
  local P = panels["trainer_journey.journey"].pointer
  P("down", 15 + 92 * 2, 20) -- the Obstacles tab
  draw("trainer_journey.journey", 480, 432, "journey-blocks-" .. lang)
  check(mod.exports.panel.state.tab == "blocks", "a tab click switches the list")
  P("down", 100, 410) -- the switch
  check(cache.spoilers == "1", "the spoiler switch is remembered")
  m = model()
  for _, list in pairs(m.lists) do for _, row in ipairs(list) do check(not row.masked, "nothing is hidden with spoilers shown: " .. row.id) end end
  P("down", 15 + 92 * 1, 20)
  draw("trainer_journey.journey", 480, 432, "journey-items-" .. lang)
  P("down", 15 + 92 * 3, 20)
  draw("trainer_journey.journey", 480, 432, "journey-post-" .. lang)
  P("down", 100, 410)
  check(cache.spoilers == "0", "and switched back")
  -- other sizes
  draw("trainer_journey.journey", 300, 600, "journey-narrow-" .. lang)
  draw("trainer_journey.next", 320, 420, "next-tall-" .. lang)

  -- the end of the story and the post-game
  for _, name in ipairs({ "FLAG_BADGE08_GET", "FLAG_WORLD_MAP_INDIGO_PLATEAU_EXTERIOR", "FLAG_DEFEATED_LORELEI", "FLAG_DEFEATED_BRUNO" }) do set(name) end
  m = model()
  check(m.next.id == "elite" and m.next.note and m.next.note:find("2", 1, true), "the Elite Four shows who is beaten")
  check(find(m.lists.post, "natdex").status == "later", "the post-game waits for the Hall of Fame")
  set("FLAG_SYS_GAME_CLEAR")
  session.dex.caught = 45
  m = model()
  check(m.next.id == "natdex" and m.next.note:find("45", 1, true), "after the league: the National Pokédex, with the count")
  draw("trainer_journey.next", 480, 240, "next-post-" .. lang)

  -- the arrow
  local Nav = mod.exports.nav
  local function at(map, x, y) MapStub.current, PlayerStub.cellX, PlayerStub.cellY, PlayerStub.px, PlayerStub.py = map, x, y, x * 16, y * 16 end
  at("FR_PALLET_TOWN", 10, 10)
  local p = Nav.point({ map = "FR_PEWTER_CITY_GYM", x = 6, y = 5 }, {})
  check(p and p.edge == "north" and p.y == -1, "from Pallet Town the way to Pewter Gym goes north")
  at("FR_VIRIDIAN_CITY", 20, 20)
  p = Nav.point({ map = "FR_VIRIDIAN_CITY_MART", x = 2, y = 3 }, {})
  local martDoor
  for _, w in ipairs(warps.FR_VIRIDIAN_CITY) do if w.destMap == "FR_VIRIDIAN_CITY_MART" then martDoor = w end end
  check(p and p.x == martDoor.x and p.y == martDoor.y, "in Viridian City the arrow points at the Mart door")
  at("FR_VIRIDIAN_CITY_MART", 4, 7)
  p = Nav.point({ map = "FR_VIRIDIAN_CITY_MART", x = 2, y = 3 }, {})
  check(p and p.final and p.x == 2, "inside, it points at the clerk")
  check(Nav.point({ map = "FR_CERULEAN_CITY" }, {}) ~= nil and Nav.point({ map = "FR_VIRIDIAN_CITY_MART" }, {}).here, "on the objective map without a cell: here")
  at("FR_VERMILION_CITY", 20, 20)
  check(Nav.point({ map = "SEVII_ONE_ISLAND_POKECENTER", x = 15, y = 6 }, {}) == nil, "no way to the Sevii Islands without a pass")
  p = Nav.point({ map = "SEVII_ONE_ISLAND_POKECENTER", x = 15, y = 6 }, { ferry123 = true })
  check(p and p.x ~= nil, "with the Tri-Pass the way goes to the pier")
  at("FR_SSANNE_EXTERIOR", 30, 8)
  check(Nav.point({ map = "SEVII_ONE_ISLAND_POKECENTER", x = 15, y = 6 }, { ferry123 = true }).ferry, "at the pier: take the ferry")
  -- drawing over a game picture, on screen and off screen
  local hud = mod.hooks_["render.hud"]
  local vp = { width = 720, height = 480, gameX = 0, gameY = 0, gameWidth = 720, gameHeight = 480, scale = 3 }
  local function hudShot(name)
    local c = G.newCanvas(720, 480)
    G.setCanvas(c); G.clear(0.35, 0.55, 0.35, 1)
    G.setColor(0.9, 0.9, 0.9); G.rectangle("fill", 345, 225, 30, 30) -- the player
    hud(function() end, game, vp)
    G.setCanvas()
    local f = io.open(OUT .. "/arrow-" .. name .. ".png", "wb"); f:write(c:newImageData():encode("png"):getString()); f:close()
  end
  -- current goal in this game is the National Pokédex: needs 60, so no goal; give it 60
  session.dex.caught = 60
  m = model()
  check(m.goal and m.goal.map == "FR_OAKS_LAB", "the goal follows the step: " .. tostring(m.goal and m.goal.map))
  at("FR_OAKS_LAB", 6, 8)
  hudShot("near-" .. lang)
  at("FR_OAKS_LAB", 6, 12)
  PlayerStub.cellX = 20; PlayerStub.px = 320
  hudShot("far-" .. lang)
  at("FR_ROUTE_1", 10, 30)
  hudShot("edge-" .. lang)
  battling = true
  hudShot("battle-" .. lang)
  battling = false
  -- the switch in the panel, and the option winning again when it changes
  check(mod.exports.arrowOn() == true, "the arrow is on by default")
  draw("trainer_journey.journey", 480, 432)
  P("down", 300, 410)
  check(mod.exports.arrowOn() == false and cache.arrow == "0,1", "the panel switch turns it off and is remembered")
  mod.options_.arrow = false; update(); mod.options_.arrow = true; update()
  check(mod.exports.arrowOn() == true, "changing the option sets it again")

  -- a game the guide does not know
  family = "rse"
  m = model()
  check(m.supported == false, "Ruby/Sapphire/Emerald are not guided")
  draw("trainer_journey.next", 480, 240)
  family = "frlg"

  -- without the dock the panels go away
  active = false
  update()
  check(next(panels) == nil, "panels are taken away when the dock is off")
  active = true
  update()
  check(panels["trainer_journey.journey"] ~= nil, "and come back with it")
  check(#logs == 0, "nothing was logged: " .. table.concat(logs, "; "))
  print("ALL JOURNEY CHECKS PASSED")
  love.event.quit(0)
end
