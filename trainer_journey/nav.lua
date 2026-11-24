-- nav.lua: the arrow on the game screen that points the way to the objective.
--
-- Every map is a point joined to others by its edges (map connections), its
-- doors, caves and stairs (warps) and, once you hold the passes, the
-- Seagallop ferry between harbors. The cheapest way from the current map to
-- the objective's map gives the first link to take; on the current map the
-- arrow points at that link: a door, the edge of the map, or the objective's
-- own cell once you are on its map. When the point is on screen a marker
-- bobs over it; otherwise an arrow sits at the border of the game picture,
-- on the line from the player towards it, with the number of steps.
return function(env)
  local G = love.graphics
  local floor, max, min, abs, sqrt = math.floor, math.max, math.min, math.abs, math.sqrt
  local Nav = {}

  local function opt(name)
    local ok, value = pcall(require, name)
    return ok and value or nil
  end
  local function try(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
  end

  local FERRY_KANTO = "FR_SSANNE_EXTERIOR" -- the Vermilion pier, where the Seagallop leaves
  local FERRY_123 = { "SEVII_ONE_ISLAND_HARBOR", "FR_TWO_ISLAND_HARBOR", "FR_THREE_ISLAND_HARBOR" }
  local FERRY_4567 = { "FR_FOUR_ISLAND_HARBOR", "FR_FIVE_ISLAND_HARBOR", "FR_SIX_ISLAND_HARBOR", "FR_SEVEN_ISLAND_HARBOR" }

  local function maps()
    local game = env.game()
    return game and game.data and type(game.data.maps) == "table" and game.data.maps or nil
  end
  local function mapDef(id)
    local all = maps()
    return all and all[id] or nil
  end

  -- The links out of a map. `ferries` is the set of harbors the passes open.
  local function links(id, ferries, Conn)
    local out = {}
    local def = mapDef(id)
    if not def then return out end
    for _, c in ipairs(Conn and try(Conn.each, def) or {}) do
      out[#out + 1] = { kind = "conn", to = c.map, dir = c.dir, offset = c.offset or 0, cost = 1 }
    end
    local seen = {}
    for _, w in ipairs(type(def.warps) == "table" and def.warps or {}) do
      local to = w.destMap or w.map
      if type(to) == "string" and to ~= id and not seen[to] and tonumber(w.x) and tonumber(w.y) then
        seen[to] = true
        out[#out + 1] = { kind = "warp", to = to, cost = 3 }
      end
    end
    if ferries[id] then
      for harbor in pairs(ferries) do
        if harbor ~= id then out[#out + 1] = { kind = "ferry", to = harbor, cost = 8 } end
      end
    end
    return out
  end

  -- The first link from `from` on the cheapest way to `goal`, or nil.
  local planCache = {}
  local function plan(from, goal, ferries, ferryKey)
    local key = from .. ">" .. goal .. "|" .. ferryKey
    if planCache.key == key then return planCache.hop end
    local Conn = opt("src.core.game3.connections")
    local dist, first, done = { [from] = 0 }, {}, {}
    local hop
    for _ = 1, 1500 do
      local at, best
      for id, d in pairs(dist) do
        if not done[id] and (not best or d < best) then at, best = id, d end
      end
      if not at then break end
      if at == goal then hop = first[at] break end
      done[at] = true
      for _, link in ipairs(links(at, ferries, Conn)) do
        if not done[link.to] then
          local d = best + link.cost
          if not dist[link.to] or d < dist[link.to] then dist[link.to], first[link.to] = d, first[at] or link end
        end
      end
    end
    planCache = { key = key, hop = hop }
    return hop
  end
  Nav.plan = plan

  local function clamp(v, lo, hi) return max(lo, min(hi, v)) end

  -- Where the arrow points on the current map for an objective { map, x, y }:
  -- { x, y } (a cell, maybe just outside the map for an edge), { here = true }
  -- when the objective's map has no cell to show, { ferry = true }, or nil.
  function Nav.point(goal, r)
    local Map, Player = opt("src.core.game3.map"), opt("src.core.game3.player")
    local current = Map and Map.current
    if not (goal and current and Player and tonumber(Player.cellX)) then return nil end
    local px, py = Player.cellX, Player.cellY
    if current == goal.map then
      if goal.x then return { x = goal.x, y = goal.y, final = true } end
      return { here = true }
    end
    local ferries, parts = {}, {}
    if r and r.ferry123 then
      ferries[FERRY_KANTO] = true
      for _, h in ipairs(FERRY_123) do ferries[h] = true end
      parts[#parts + 1] = "a"
    end
    if r and r.ferry4567 then
      ferries[FERRY_KANTO] = true
      for _, h in ipairs(FERRY_4567) do ferries[h] = true end
      parts[#parts + 1] = "b"
    end
    local hop = plan(current, goal.map, ferries, table.concat(parts))
    if not hop then return nil end
    if hop.kind == "ferry" then return { ferry = true } end
    local def = mapDef(current)
    if hop.kind == "warp" then
      local best, bd
      for _, w in ipairs(def and type(def.warps) == "table" and def.warps or {}) do
        if (w.destMap or w.map) == hop.to and tonumber(w.x) then
          local d = abs(w.x - px) + abs(w.y - py)
          if not bd or d < bd then best, bd = w, d end
        end
      end
      return best and { x = best.x, y = best.y } or nil
    end
    -- an edge: the nearest cell past it that the neighbouring map lies along
    local Conn = opt("src.core.game3.connections")
    local w, h = 0, 0
    if Conn then w, h = try(Conn.sizeOf, def) end
    local nw, nh = 0, 0
    if Conn then nw, nh = try(Conn.sizeOf, mapDef(hop.to)) end
    w, h, nw, nh = tonumber(w) or 0, tonumber(h) or 0, tonumber(nw) or 0, tonumber(nh) or 0
    local o = hop.offset or 0
    if hop.dir == "north" or hop.dir == "south" then
      local lo, hi = max(0, o), (w > 0 and min(w - 1, o + max(nw, 1) - 1) or px)
      return { x = clamp(px, lo, max(lo, hi)), y = hop.dir == "north" and -1 or h, edge = hop.dir }
    else
      local lo, hi = max(0, o), (h > 0 and min(h - 1, o + max(nh, 1) - 1) or py)
      return { x = hop.dir == "west" and -1 or w, y = clamp(py, lo, max(lo, hi)), edge = hop.dir }
    end
  end

  ---------------------------------------------------------------------------
  -- Drawing
  ---------------------------------------------------------------------------
  local fonts = {}
  local function font(size)
    size = max(8, floor(size + 0.5))
    if not fonts[size] then fonts[size] = env.font(size) end
    return fonts[size]
  end
  local INK = { 0.31, 0.61, 0.97 }
  local EDGE = { 0.04, 0.06, 0.09 }

  local function label(text, x, y, s, anchorX, anchorY)
    local f = font(max(10, 4.5 * s))
    G.setFont(f)
    local pad = max(2, s)
    local w, h = f:getWidth(text) + pad * 2, f:getHeight()
    local lx, ly = x - w * anchorX, y - h * anchorY
    G.setColor(EDGE[1], EDGE[2], EDGE[3], 0.78)
    G.rectangle("fill", lx, ly, w, h, h / 2, h / 2)
    G.setColor(1, 1, 1, 0.95)
    G.print(text, floor(lx + pad), floor(ly))
  end

  -- An arrowhead with a notch at the back, pointing along (ux, uy), its tip at (x, y).
  local function arrow(x, y, ux, uy, size)
    local bx, by = x - ux * size, y - uy * size
    local nx, ny = -uy * size * 0.5, ux * size * 0.5
    local lx, ly, rx, ry = bx + nx, by + ny, bx - nx, by - ny
    local cx, cy = x - ux * size * 0.62, y - uy * size * 0.62
    G.setColor(EDGE[1], EDGE[2], EDGE[3], 0.85)
    G.setLineWidth(max(1, size * 0.16))
    G.setLineJoin("miter")
    G.polygon("line", x, y, lx, ly, cx, cy, rx, ry)
    G.setColor(INK[1], INK[2], INK[3], 0.95)
    G.polygon("fill", x, y, lx, ly, cx, cy)
    G.polygon("fill", x, y, cx, cy, rx, ry)
  end

  -- `point` from Nav.point; `viewport` from the render.hud hook.
  function Nav.draw(point, viewport, clock, texts)
    if not (point and viewport) then return end
    local Player, View = opt("src.core.game3.player"), package.loaded["src.core.game3.field_view"]
    local s = tonumber(viewport.scale) or 1
    local gx, gy = tonumber(viewport.gameX) or 0, tonumber(viewport.gameY) or 0
    local gw, gh = tonumber(viewport.gameWidth) or 240 * s, tonumber(viewport.gameHeight) or 160 * s
    local u = max(1, s) -- size unit: one game pixel
    G.push("all")
    G.setScissor(floor(gx), floor(gy), floor(gw), floor(gh))
    if point.ferry then
      label(texts.ferry, gx + gw / 2, gy + 3 * u, u, 0.5, 0)
      G.pop()
      return
    end
    if point.here or not Player then G.pop(); return end
    local panX, panY = View and View.cameraPanX or 0, View and View.cameraPanY or 0
    local cx, cy = gx + gw / 2 - panX * s, gy + gh / 2 - panY * s
    local ppx, ppy = tonumber(Player.px) or Player.cellX * 16, tonumber(Player.py) or Player.cellY * 16
    local tx, ty = cx + (point.x * 16 - ppx) * s, cy + (point.y * 16 - ppy) * s
    local steps = abs(point.x - Player.cellX) + abs(point.y - Player.cellY)
    local text = texts.steps(steps)
    local margin = 7 * u
    if tx > gx + margin and tx < gx + gw - margin and ty > gy + margin and ty < gy + gh - margin then
      -- on screen: a marker bobbing over the cell
      local bob = math.sin((clock or 0) * 5) * 1.5 * u
      local size = 4.5 * u
      arrow(tx, ty - 5 * u + bob, 0, 1, size)
      if steps > 0 then label(text, tx, ty - 5 * u - size + bob - u, u, 0.5, 1) end
    else
      -- off screen: at the border, on the line from the player
      local dx, dy = tx - cx, ty - cy
      local len = sqrt(dx * dx + dy * dy)
      if len < 1 then G.pop(); return end
      local ux, uy = dx / len, dy / len
      local hw, hh = gw / 2 - margin, gh / 2 - margin
      local k = math.huge
      if abs(ux) > 1e-6 then k = min(k, hw / abs(ux)) end
      if abs(uy) > 1e-6 then k = min(k, hh / abs(uy)) end
      local ax, ay = gx + gw / 2 + ux * k, gy + gh / 2 + uy * k
      local size = 5 * u
      arrow(ax, ay, ux, uy, size)
      label(text, ax - ux * (size + 2 * u), ay - uy * (size + 2 * u), u, 0.5 + ux * 0.5, 0.5 + uy * 0.5)
    end
    G.pop()
  end

  function Nav.reset() planCache = {} end
  return Nav
end
