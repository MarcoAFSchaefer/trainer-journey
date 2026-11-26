-- Trainer Journey: where to go next in FireRed and LeafGreen.
--
-- The journey is data (journey.lua): story steps, HMs and key items, what
-- blocks the way, the post-game and the Pokédex rewards, each with conditions
-- on the save's event flags, badges, bag and Pokédex. This file reads the save
-- and turns the data into a model; panel.lua draws it. Nothing in the game is
-- changed.
--
-- Two panels live in the Trainer Desk window: "Journey" (every list, with the
-- choice of showing or hiding upcoming steps) and "Next step" (the current
-- objective and what can be picked up now). Without Trainer Desk there is
-- nowhere to draw them and the mod does nothing.
return function(mod)
  local floor, max, min = math.floor, math.max, math.min
  local function load_(name, ...)
    return assert(load(assert(mod:read(name)), "@trainer_journey/" .. name))()(...)
  end

  mod.options:define({
    { key = "language", label = "LANGUAGE", type = "choice", default = "en",
      choices = { { "ENGLISH", "en" }, { "ESPANOL", "es" }, { "PORTUGUES", "pt" }, { "JAPANESE", "ja" } },
      description = "Language of the guide's panels." },
    { key = "arrow", label = "ARROW TO THE OBJECTIVE", type = "toggle", default = true,
      description = "An arrow at the border of the game screen points the way to the next objective. The Journey panel has the same switch." },
  })
  local function option(key)
    local ok, value = pcall(function() return mod.options:get(key) end)
    if ok then return value end
    return nil
  end
  local I18n = assert(load(assert(mod:read("i18n.lua")), "@trainer_journey/i18n.lua"))()(mod, function() return option("language") end)
  local T, F = I18n.T, I18n.F
  local J = assert(load(assert(mod:read("journey.lua")), "@trainer_journey/journey.lua"))()

  local function try(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
  end
  local function opt(name)
    local ok, value = pcall(require, name)
    return ok and value or nil
  end

  ---------------------------------------------------------------------------
  -- Reading the save
  ---------------------------------------------------------------------------
  local game
  -- Spoilers: hidden unless the player chose to see upcoming steps.
  local settings = { spoilers = false }
  do
    local saved = mod.cache and mod.cache.read and mod.cache:read("spoilers")
    settings.spoilers = saved == "1"
  end
  -- The arrow: the mod option sets it, the panel's switch changes it until the
  -- option itself is changed again.
  local function arrowOption() return option("arrow") ~= false end
  do
    local saved = mod.cache and mod.cache.read and mod.cache:read("arrow")
    local on, from = tostring(saved or ""):match("^([01]),([01])$")
    local now = arrowOption() and "1" or "0"
    settings.arrow = (on and from == now) and on == "1" or arrowOption()
  end
  local function setArrow(on)
    settings.arrow = on and true or false
    if mod.cache and mod.cache.write then
      mod.cache:write("arrow", (settings.arrow and "1" or "0") .. "," .. (arrowOption() and "1" or "0"))
    end
  end
  local lastOption = arrowOption()
  local function syncArrowOption()
    local now = arrowOption()
    if now ~= lastOption then lastOption = now; setArrow(now) end
  end
  -- A goal of the player's own choosing ("items:hm3"): the arrow and the Next
  -- step panel follow it until it is done or let go.
  -- What belongs to one save. The game keeps a store for mods per save slot
  -- (mod.storage); the shared cache (mod.cache) is the same for every save and
  -- for every copy of the game that is open. A save that has nothing of its own
  -- yet starts from what the shared cache holds, and from then on keeps its own.
  local PerSave = { values = nil, id = nil, checked = -math.huge, listeners = {}, dirty = false, wrote = 0 }
  local function perSaveFlush()
    if not (PerSave.dirty and PerSave.values) then return end
    PerSave.dirty, PerSave.wrote = false, love.timer.getTime()
    pcall(mod.storage.write, mod.storage, PerSave.game, "state", PerSave.values)
  end
  -- Which save is open: asked when the session changes, at most every few seconds.
  local function perSaveBind(g)
    if not (type(g) == "table" and g.session and g.save and g.phase == "field"
        and type(mod.storage) == "table" and mod.storage.context and mod.storage.read and mod.storage.write) then return end
    local now = love.timer.getTime()
    if PerSave.dirty and now - PerSave.wrote >= 2 then perSaveFlush() end
    if PerSave.session == g.session or now - PerSave.checked < 5 then return end
    PerSave.session, PerSave.checked = g.session, now
    local ok, context = pcall(mod.storage.context, mod.storage, g)
    local id = ok and type(context) == "table" and context.playthroughId or nil
    if id and id ~= PerSave.id then
      perSaveFlush()
      local okRead, data = pcall(mod.storage.read, mod.storage, g, "state")
      PerSave.id, PerSave.game, PerSave.values = id, g, okRead and type(data) == "table" and data or {}
      for _, listener in ipairs(PerSave.listeners) do pcall(listener) end
    end
  end
  local function perSaveRead(key)
    local own = PerSave.values and PerSave.values[key]
    if type(own) == "string" then return own end
    return mod.cache and mod.cache.read and mod.cache:read(key) or nil
  end
  -- `soon`: written at once (a setting); otherwise within two seconds (a counter).
  local function perSaveWrite(key, text, soon)
    if not PerSave.values then
      -- no save open yet: the shared cache, as it always was
      if mod.cache and mod.cache.write then mod.cache:write(key, text) end
      return
    end
    if PerSave.values[key] == text then return end
    PerSave.values[key], PerSave.dirty = text, true
    if soon then perSaveFlush() end
  end
  local function loadPin()
    local saved = perSaveRead("pin")
    settings.pin = type(saved) == "string" and saved:match("^%a+:[%w_]+$") or nil
  end
  loadPin()
  PerSave.listeners[#PerSave.listeners + 1] = loadPin   -- another save was opened: its own goal
  local function setPin(key)
    settings.pin = key
    perSaveWrite("pin", key or "", true)
  end
  local function setSpoilers(on)
    settings.spoilers = on and true or false
    if mod.cache and mod.cache.write then mod.cache:write("spoilers", settings.spoilers and "1" or "0") end
  end

  local function supported(session)
    local Profile = opt("src.core.game3.profile")
    local profile = Profile and try(Profile.forSession, session)
    return not (type(profile) == "table" and profile.family == "rse")
  end

  -- What the conditions look at, read once per model.
  local function reader()
    local s = game and game.session
    if not s then return nil end
    local Space, Flags = opt("src.core.game3.scripting.space"), opt("src.core.game3.scripting.flags")
    local Bag, Dex = opt("src.core.game3.bag"), opt("src.core.game3.dex")
    local store = Space and try(Space.getStore) or s
    local ids = Flags and Flags.IDS or {}
    local active = Flags and Flags.active and try(Flags.active, s)
    if type(active) == "table" and type(active.IDS) == "table" then ids = active.IDS end
    local r = { flags = {} }
    function r.flag(name)
      local known = r.flags[name]
      if known ~= nil then return known end
      local id = ids[name]
      known = id ~= nil and Flags ~= nil and try(Flags.getFlag, store, nil, id) == true or false
      r.flags[name] = known
      return known
    end
    function r.item(id)
      local bag = s.bag
      if not (bag and Bag) then return false end
      local n = try(Bag.get, bag, id)
      if type(n) == "table" then n = n.qty or n.quantity or n.count end
      if tonumber(n) then return tonumber(n) > 0 end
      return try(Bag.has, bag, id, 1) == true
    end
    r.badges = 0
    for n = 1, 8 do if r.flag(string.format("FLAG_BADGE%02d_GET", n)) then r.badges = r.badges + 1 end end
    r.hasBadge = function(n) return r.flag(string.format("FLAG_BADGE%02d_GET", n)) end
    r.ferry123 = r.flag("FLAG_SYS_SEVII_MAP_123") or r.item(J.ITEM.TRI_PASS)
    r.ferry4567 = r.flag("FLAG_SYS_SEVII_MAP_4567") or r.item(J.ITEM.RAINBOW_PASS)
    r.caught = Dex and s.dex and tonumber(try(Dex.countCaught, s.dex, "kanto")) or 0
    -- who in the party knows a move, by move id
    r.knows = {}
    for _, mon in ipairs(type(s.party) == "table" and s.party or {}) do
      for _, move in ipairs(type(mon) == "table" and type(mon.moves) == "table" and mon.moves or {}) do
        local id = type(move) == "table" and (move.id or move.move) or move
        if tonumber(id) then r.knows[tonumber(id)] = true end
      end
    end
    return r
  end

  local function met(c, r)
    if c == nil then return true end
    if c.flag then return r.flag(c.flag) end
    if c.item then return r.item(c.item) end
    if c.badges then return r.badges >= c.badges end
    if c.caught then return r.caught >= c.caught end
    if c.on then
      local ok, Map = pcall(require, "src.core.game3.map")
      return ok and type(Map) == "table" and Map.current == c.on
    end
    if c.any then
      for _, part in ipairs(c.any) do if met(part, r) then return true end end
      return false
    end
    if c.all then
      for _, part in ipairs(c.all) do if not met(part, r) then return false end end
      return true
    end
    return false
  end

  ---------------------------------------------------------------------------
  -- The model
  ---------------------------------------------------------------------------
  local function texts(group, id)
    local t = T(group)
    local entry = type(t) == "table" and t[id]
    if type(entry) ~= "table" then return id, "" end
    return entry[1] or id, entry[2] or ""
  end
  local function moveName(hm)
    local names = T("MOVES")
    return type(names) == "table" and names[hm] or hm
  end
  local function badgeName(n)
    local names = T("BADGES")
    return type(names) == "table" and names[n] or ("#" .. n)
  end

  -- An ordered list (story, post-game): done, the current step, open optional
  -- steps, and what comes later.
  local function chain(list, group, r, kind, gate)
    local rows, current, done, total = {}, nil, 0, 0
    for _, step in ipairs(list) do
      local title, hint = texts(group, step.id)
      local row = { id = step.id, kind = kind, title = title, hint = hint, optional = step.optional == true, def = step }
      if met(step.done, r) then
        row.status = "done"
      elseif gate ~= nil and not met(gate, r) and not step.optional then
        row.status = "later"
      elseif step.optional then
        row.status = met(step.open, r) and "open" or "later"
      elseif not current and met(step.open, r) then
        row.status, current = "current", row
      else
        row.status = "later"
      end
      if not step.optional then
        total = total + 1
        if row.status == "done" then done = done + 1 end
      end
      if step.parts then
        local beaten = 0
        for _, name in ipairs(step.parts) do if r.flag(name) then beaten = beaten + 1 end end
        if row.status ~= "done" and beaten > 0 then row.note = F("BEATEN", beaten, #step.parts) end
      end
      if step.need and row.status ~= "done" then row.note = F("CAUGHT_OF", r.caught, step.need) end
      rows[#rows + 1] = row
    end
    return { rows = rows, current = current, done = done, total = total }
  end

  local function buildItems(r)
    local rows, byId = {}, {}
    for _, entry in ipairs(J.items) do
      local title, hint = texts("ITEMS", entry.id)
      local row = { id = entry.id, kind = "item", title = title, hint = hint, hm = entry.hm, def = entry }
      if met(entry.done, r) then row.status = "done"
      elseif met(entry.open, r) then row.status = "open"
      else row.status = "later" end
      if entry.hm then
        local badge = r.hasBadge(entry.badge)
        -- once you have it: whether it works outside battle, and whether anyone knows it
        row.field = F(badge and "FIELD_OK" or "FIELD_NEEDS", badgeName(entry.badge))
        row.badgeOk, row.knows = badge, r.knows[entry.move] == true
        if row.status == "done" and badge and not row.knows then row.field = row.field .. " · " .. T("NOBODY_KNOWS") end
        if row.status == "done" then row.note = row.field end
      end
      rows[#rows + 1] = row
      byId[entry.id] = { row = row, def = entry }
    end
    return rows, byId
  end

  local function buildBlocks(r, items)
    local rows, teach = {}, {}
    for _, entry in ipairs(J.blocks) do
      local title, hint = texts("BLOCKS", entry.id)
      local row = { id = entry.id, kind = "block", title = title, hint = hint }
      local missing, revealed = {}, false
      if entry.hm then
        local it = items[entry.hm]
        local have = it.row.status == "done"
        revealed = it.row.status ~= "later"
        if not have then missing[#missing + 1] = it.row.title end
        if not r.hasBadge(it.def.badge) then missing[#missing + 1] = badgeName(it.def.badge) end
        if have and r.hasBadge(it.def.badge) and not r.knows[it.def.move] then
          missing[#missing + 1] = F("TEACH", moveName(entry.hm))
          teach[#teach + 1] = entry.hm
        end
      elseif entry.key then
        local it = items[entry.key]
        local have = entry.have and met(entry.have, r) or (it and it.row.status == "done")
        revealed = have or (entry.open and met(entry.open, r)) or (it and it.row.status ~= "later")
        if not have then missing[#missing + 1] = it and it.row.title or texts("ITEMS", entry.key) end
      elseif entry.badges then
        revealed = met(entry.open, r)
        if r.badges < entry.badges then missing[#missing + 1] = F("BADGES_OF", r.badges, entry.badges) end
      end
      row.status = #missing == 0 and "done" or (revealed and "open" or "later")
      row.note = #missing == 0 and T("READY") or F("NEEDS", table.concat(missing, ", "))
      rows[#rows + 1] = row
    end
    return rows, teach
  end

  local function buildDex(r)
    local rows = {}
    for _, entry in ipairs(J.dex) do
      local title, hint = texts("DEX", entry.id)
      local row = { id = entry.id, kind = "dex", title = title, hint = hint, need = entry.need, have = r.caught, def = entry }
      if met(entry.done, r) then row.status, row.note = "done", T("GOT_IT")
      elseif not met(entry.open, r) then row.status, row.note = "open", T(entry.id == "natdex" and "AFTER_LEAGUE" or "AFTER_DEX")
      elseif r.caught >= entry.need then row.status, row.note = "ready", T("GO_GET_IT")
      else row.status, row.note = "open", F("MORE_TO_CATCH", entry.need - r.caught, r.caught, entry.need) end
      rows[#rows + 1] = row
    end
    return rows
  end

  local function model()
    local out = { supported = true, spoilers = settings.spoilers }
    local r = reader()
    if not r then out.waiting = true; return out end
    if not supported(game.session) then out.supported = false; return out end
    out.badges, out.caught = r.badges, r.caught
    local story = chain(J.story, "STEPS", r, "story")
    local post = chain(J.post, "STEPS", r, "post", { flag = "FLAG_SYS_GAME_CLEAR" })
    local items, byId = buildItems(r)
    local blocks, teach = buildBlocks(r, byId)
    out.lists = { story = story.rows, items = items, blocks = blocks, post = post.rows, dex = buildDex(r) }
    out.story, out.post = story, post
    out.next = story.current or post.current
    -- where the arrow leads: the first destination of the step that applies
    out.ferry123, out.ferry4567 = r.ferry123, r.ferry4567
    for _, dest in ipairs(out.next and out.next.def.go or {}) do
      if dest.when == nil or met(dest.when, r) then out.goal = dest break end
    end
    out.finished = story.current == nil and post.current == nil
    -- Ready now: rewards waiting, things that can be picked up, moves to teach.
    local ready = {}
    for _, row in ipairs(out.lists.dex) do
      if row.status == "ready" then ready[#ready + 1] = { kind = "dex", text = F("READY_GIFT", row.title, row.hint) } end
    end
    for _, hm in ipairs(teach) do
      ready[#ready + 1] = { kind = "teach", text = F("READY_TEACH", moveName(hm), badgeName(byId[hm].def.badge)) }
    end
    for _, row in ipairs(items) do
      if row.status == "open" and row.id ~= "hm5" then ready[#ready + 1] = { kind = "item", text = F("READY_ITEM", row.title, row.hint) } end
    end
    for _, row in ipairs(story.rows) do
      if row.optional and row.status == "open" then ready[#ready + 1] = { kind = "side", text = F("READY_SIDE", row.title) } end
    end
    out.ready = ready
    -- The player's own goal, while it is still to do, leads the arrow.
    for name, list in pairs(out.lists) do
      for _, row in ipairs(list) do
        row.key = name .. ":" .. row.id
        row.canPin = row.status ~= "done" and type(row.def) == "table" and type(row.def.go) == "table"
        if settings.pin == row.key then
          if row.status == "done" then setPin(nil) else row.pinned, out.pinned = true, row end
        end
      end
    end
    if out.pinned then
      out.goal = nil
      for _, dest in ipairs(out.pinned.def.go) do
        if dest.when == nil or met(dest.when, r) then out.goal = dest break end
      end
    end
    -- With spoilers hidden, what comes later is only counted, never named.
    for _, list in pairs(out.lists) do
      for _, row in ipairs(list) do row.masked = not settings.spoilers and row.status == "later" end
    end
    return out
  end

  ---------------------------------------------------------------------------
  -- Panels
  ---------------------------------------------------------------------------
  local cached, cachedAt = nil, -1
  local function current(clock)
    clock = tonumber(clock) or 0
    if not cached or clock - cachedAt >= 0.5 or clock < cachedAt or cached.spoilers ~= settings.spoilers or cached.pinKey ~= settings.pin then
      local ok, value = pcall(model)
      cached = ok and value or { error = tostring(value) }
      cached.pinKey = settings.pin
      cachedAt = clock
    end
    return cached
  end
  local function refresh() cached = nil end
  local Panel = load_("panel.lua", { T = T, F = F, font = I18n.font, model = current, refresh = refresh,
    spoilers = function() return settings.spoilers end, setSpoilers = setSpoilers,
    pin = function() return settings.pin end, setPin = function(key) setPin(key); refresh() end,
    arrow = function() return settings.arrow end, setArrow = setArrow })
  local failed
  local Nav = load_("nav.lua", { font = I18n.font, game = function() return game end })

  -- Only on the field, with nothing else going on: no battle, menu, message or script.
  local world
  local function fieldIdle()
    local Battle, World = opt("src.core.game3.battle"), opt("src.world.game3.WorldAPI")
    if Battle and try(Battle.isActive) == true then return false end
    if not World then return false end
    world = world or try(World.new, game, "trainer_journey")
    if not world then return false end
    local list, why = try(world.availableFieldActions, world)
    return type(list) == "table" and why == nil
  end
  local arrowTexts = { steps = function(n) return F("ARROW_STEPS", n) end }
  mod.hooks:wrap("render.hud", function(nextHook, g, viewport)
    nextHook(g, viewport)
    if not (settings.arrow and game) then return end
    -- nobody follows an arrow while Trainer Pilot is playing: leave the frame alone
    local pilot = mod.find and mod.find("trainer_pilot")
    if pilot and type(pilot.exports) == "table" and type(pilot.exports.bot) == "table" and pilot.exports.bot.running == true then return end
    local ok, err = pcall(function()
      local m = current(love.timer.getTime())
      if not (m.goal and fieldIdle()) then return end
      arrowTexts.ferry = T("ARROW_FERRY")
      Nav.draw(Nav.point(m.goal, m), viewport, love.timer.getTime(), arrowTexts)
    end)
    if not ok and not failed then
      failed = true
      mod.log:warn("Trainer Journey arrow stopped: %s", tostring(err))
    end
  end, 870)

  local docked
  local function dockApi()
    if not mod.find then return nil end
    local other = mod.find("trainer_desk")
    local api = other and other.exports and other.exports.dock
    if type(api) == "table" and api.api == 1 and api.active() then return api end
  end
  local function undock()
    if not docked then return end
    pcall(docked.api.unregister, "trainer_journey.journey")
    pcall(docked.api.unregister, "trainer_journey.next")
    docked = nil
  end
  local function syncDock(api)
    local language = tostring(option("language"))
    if docked and docked.api == api and docked.language == language then return end
    undock()
    local function themed(draw)
      return function(clock, w, h)
        if api.theme then Panel.theme(api.theme().colors) end
        return draw(clock, w, h)
      end
    end
    api.register({
      icon = (function()
        -- The Journey Badge, this mod's mark in the Trainer Badges family: drawn
        -- here, on a 100-unit square, so no picture file is needed.
        local G = love.graphics
        local SHAPE, LIGHT, DARK = { 50,4, 62,38, 96,50, 62,62, 50,96, 38,62, 4,50, 38,38 }, { 50,4, 62,38, 50,50, 38,38 }, { 50,96, 62,62, 50,50, 38,62 }
        local function fillAt(pts, x, y, k, f)
          local t = {}
          for i = 1, #pts, 2 do
            t[i], t[i + 1] = x + (50 + (pts[i] - 50) * f) * k, y + (50 + (pts[i + 1] - 50) * f) * k
          end
          local ok, tris = pcall(love.math.triangulate, t)
          if ok then for _, tri in ipairs(tris) do G.polygon("fill", tri) end end
        end
        return function(x, y, size, alpha)
          local k, a = size / 100, alpha or 1
          local r, g, b, a0 = G.getColor()
          G.setColor(0.85, 0.88, 0.92, a); fillAt(SHAPE, x, y, k, 1)
          G.setColor(0.96, 0.48, 0.16, a); fillAt(SHAPE, x, y, k, 0.8)
          G.setColor(1, 1, 1, 0.3 * a); fillAt(LIGHT, x, y, k, 0.8)
          G.setColor(0, 0, 0, 0.28 * a); fillAt(DARK, x, y, k, 0.8)
          G.setColor(r, g, b, a0)
        end
      end)(),
      id = "trainer_journey.next", title = T("TITLE_NEXT"), width = Panel.NW, height = Panel.NH, pixel = 1,
      responsive = true, interval = 0.25, side = "right", draw = themed(Panel.drawNext) })
    api.register({
      icon = (function()
        -- The Journey Badge, this mod's mark in the Trainer Badges family: drawn
        -- here, on a 100-unit square, so no picture file is needed.
        local G = love.graphics
        local SHAPE, LIGHT, DARK = { 50,4, 62,38, 96,50, 62,62, 50,96, 38,62, 4,50, 38,38 }, { 50,4, 62,38, 50,50, 38,38 }, { 50,96, 62,62, 50,50, 38,62 }
        local function fillAt(pts, x, y, k, f)
          local t = {}
          for i = 1, #pts, 2 do
            t[i], t[i + 1] = x + (50 + (pts[i] - 50) * f) * k, y + (50 + (pts[i + 1] - 50) * f) * k
          end
          local ok, tris = pcall(love.math.triangulate, t)
          if ok then for _, tri in ipairs(tris) do G.polygon("fill", tri) end end
        end
        return function(x, y, size, alpha)
          local k, a = size / 100, alpha or 1
          local r, g, b, a0 = G.getColor()
          G.setColor(0.85, 0.88, 0.92, a); fillAt(SHAPE, x, y, k, 1)
          G.setColor(0.96, 0.48, 0.16, a); fillAt(SHAPE, x, y, k, 0.8)
          G.setColor(1, 1, 1, 0.3 * a); fillAt(LIGHT, x, y, k, 0.8)
          G.setColor(0, 0, 0, 0.28 * a); fillAt(DARK, x, y, k, 0.8)
          G.setColor(r, g, b, a0)
        end
      end)(),
      id = "trainer_journey.journey", title = T("TITLE_JOURNEY"), width = Panel.W, height = Panel.H, pixel = 1,
      responsive = true, interval = 0.25, side = "bottom", pointer = Panel.pointer, draw = themed(Panel.drawJourney) })
    docked = { api = api, language = language }
  end

  mod.hooks:wrap("core.update", function(nextHook, updateGame, dt)
    pcall(perSaveBind, updateGame)
    if not failed then
      local ok, err = pcall(function()
        syncArrowOption()
        local api = game and dockApi()
        if api then syncDock(api) else undock() end
      end)
      if not ok then
        failed = true
        mod.log:warn("Trainer Journey stopped: %s", tostring(err))
      end
    end
    return nextHook(updateGame, dt)
  end, 870)
  mod.hooks:wrap("core.quit_to_launcher", function(nextHook)
    game, world = nil, nil
    pcall(undock)
    return nextHook()
  end, 870)
  mod.events:on("game.ready", function(payload)
    game, cached, world = payload and payload.game, nil, nil
    Nav.reset()
  end)

  mod.exports = mod.exports or {}
  mod.exports.debugModel = function() cached = nil; return current(0) end
  mod.exports.debugSetGame = function(g) game, cached = g, nil end
  mod.exports.panel = Panel
  mod.exports.setSpoilers = setSpoilers
  mod.exports.setArrow = setArrow
  mod.exports.setPin = setPin
  mod.exports.nav = Nav
  mod.exports.arrowOn = function() return settings.arrow end
end
