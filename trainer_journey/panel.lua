-- Trainer Journey's two panels, drawn into Trainer Desk panels.
--
-- "Journey" has five lists (story, HMs and key items, obstacles, post-game,
-- Pokédex rewards), a box with the chosen entry's full text and the switch
-- that shows or hides upcoming steps. "Next step" shows the current objective
-- and what can be picked up now. Both are laid out on a fixed sheet and
-- stretched to the room the dock gives them; whatever is clickable is kept as
-- a rectangle while drawing and looked up when the pointer goes down.
return function(env)
  local G = love.graphics
  local T, F = env.T, env.F
  local floor, max, min = math.floor, math.max, math.min
  local Panel = { W = 480, H = 432, NW = 480, NH = 240 }

  local fonts = {}
  local function font(size)
    size = max(8, floor(size + 0.5))
    if not fonts[size] then fonts[size] = env.font(size) end
    return fonts[size]
  end
  local function hex(value)
    return { tonumber(value:sub(1, 2), 16) / 255, tonumber(value:sub(3, 4), 16) / 255, tonumber(value:sub(5, 6), 16) / 255 }
  end
  -- The same look as the other panels of the IDE.
  local C = {
    bg = hex("0f1216"), card = hex("1b1f26"), line = hex("2f3742"),
    text = hex("e6ebf2"), muted = hex("9aa5b4"), accent = hex("4f9cf7"),
    go = hex("2f9e58"), warn = hex("d1912a"), off = hex("252b34"),
  }
  function Panel.theme(colors)
    if type(colors) ~= "table" then return end
    C.bg, C.card, C.off = colors.panel or C.bg, colors.dock or C.card, colors.tabActive or C.off
    C.text, C.muted = colors.textActive or C.text, colors.text or C.muted
    C.accent = colors.accent or C.accent
  end

  -- Sheet coordinates to the room: positions follow the room, text the smaller scale.
  local kx, ky, kf, ox, oy = 1, 1, 1, 0, 0
  local hits = {}
  local function fit(w, h, sw, sh)
    w, h = tonumber(w) or sw, tonumber(h) or sh
    kx, ky = max(0.6, min(2.4, w / sw)), max(0.6, min(2.4, h / sh))
    kf = max(0.75, min(1.5, min(kx, ky)))
    ox, oy = max(0, floor((w - sw * kx) / 2)), max(0, floor((h - sh * ky) / 2))
    return w, h
  end
  local function color(c, a) G.setColor(c[1], c[2], c[3], a or 1) end
  local function box(x, y, w, h, c, r)
    color(c)
    local radius = min((r or 6) * kf, h * ky / 2, w * kx / 2)
    G.rectangle("fill", floor(ox + x * kx), floor(oy + y * ky), floor(w * kx + 0.5), floor(h * ky + 0.5), radius, radius)
  end
  local function chars(str)
    local out = {}
    for ch in tostring(str):gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = ch end
    return out
  end
  -- One line: what does not fit loses its end.
  local function shorten(f, str, room)
    str = tostring(str)
    if f:getWidth(str) <= room then return str end
    local list = chars(str)
    while #list > 0 and f:getWidth(table.concat(list) .. "..") > room do list[#list] = nil end
    return table.concat(list) .. ".."
  end
  local function line(str, x, y, c, size, limit, align)
    local f = font((size or 13) * kf)
    G.setFont(f)
    color(c or C.text)
    local room = max(1, limit * kx)
    str = shorten(f, str, room)
    local px = ox + x * kx
    if align == "right" then px = px + room - f:getWidth(str)
    elseif align == "center" then px = px + (room - f:getWidth(str)) / 2 end
    G.print(str, floor(px), floor(oy + y * ky))
  end
  -- Wrapped text, at most `lines` lines; the last one is cut when there is more.
  -- Returns the height used on the sheet.
  local function para(str, x, y, c, size, limit, lines)
    local f = font((size or 13) * kf)
    G.setFont(f)
    color(c or C.text)
    local room = max(1, limit * kx)
    local _, wrapped = f:getWrap(tostring(str), room)
    local shown = min(#wrapped, lines or #wrapped)
    for index = 1, shown do
      local text = wrapped[index]
      if index == shown and shown < #wrapped then text = shorten(f, text .. " " .. wrapped[index + 1], room) end
      G.print(text, floor(ox + x * kx), floor(oy + y * ky + (index - 1) * f:getHeight()))
    end
    return shown * f:getHeight() / ky
  end
  local function centred(str, x, y, w, h, c, size)
    local f = font((size or 13) * kf)
    G.setFont(f)
    color(c or C.text)
    local room = max(1, w * kx - 6 * kf)
    str = shorten(f, str, room)
    G.print(str, floor(ox + x * kx + (w * kx - f:getWidth(str)) / 2), floor(oy + y * ky + (h * ky - f:getHeight()) / 2))
  end
  local function hit(x, y, w, h, action)
    hits[#hits + 1] = { x = ox + x * kx, y = oy + y * ky, w = w * kx, h = h * ky, action = action }
  end
  local function button(label, x, y, w, h, fill, action, size, ink)
    box(x, y, w, h, fill or C.off, 6)
    centred(label, x, y, w, h, ink or C.text, size or 12)
    if action then hit(x, y, w, h, action) end
  end
  local function toggle(label, x, y, w, value, action)
    box(x, y, w, 24, C.card)
    line(label, x + 8, y + 5, C.text, 12, w - 64)
    local sw, sh = 36 * kf, 18 * kf
    local sx, sy = ox + (x + w) * kx - sw - 8 * kf, oy + y * ky + (24 * ky - sh) / 2
    color(value and C.accent or C.line)
    G.rectangle("fill", sx, sy, sw, sh, sh / 2, sh / 2)
    color(C.text)
    G.circle("fill", value and sx + sw - sh / 2 or sx + sh / 2, sy + sh / 2, sh / 2 - 3 * kf)
    hit(x, y, w, 24, action)
  end
  local function pill(label, x, y, fill, ink)
    local f = font(10 * kf)
    local w = f:getWidth(tostring(label)) / kx + 12
    box(x, y, w, 16, fill, 8)
    centred(label, x, y, w, 16, ink or C.text, 10)
    return w
  end
  -- A round mark for a row's state.
  local MARK = { done = "go", current = "accent", ready = "warn", open = "accent", later = "line" }
  local function mark(status, x, y)
    local c = C[MARK[status] or "line"]
    local cx, cy, r = ox + x * kx, oy + y * ky, 7 * kf
    color(c)
    if status == "open" then
      G.setLineWidth(2 * kf); G.circle("line", cx, cy, r - kf)
    else
      G.circle("fill", cx, cy, r)
    end
    if status == "done" then
      color(C.bg)
      G.setLineWidth(2 * kf)
      G.line(cx - 3.5 * kf, cy, cx - 1 * kf, cy + 3 * kf, cx + 4 * kf, cy - 3 * kf)
    elseif status == "current" then
      color(C.bg)
      G.polygon("fill", cx - 2 * kf, cy - 4 * kf, cx - 2 * kf, cy + 4 * kf, cx + 4 * kf, cy)
    end
  end
  local function message(text, w, h, sw, sh)
    color(C.bg); G.rectangle("fill", 0, 0, w, h)
    para(text, 16, sh / 2 - 20, C.muted, 13, sw - 32, 4)
  end

  ---------------------------------------------------------------------------
  -- Journey
  ---------------------------------------------------------------------------
  local TABS = { "story", "items", "blocks", "post", "dex" }
  local state = { tab = "story", page = 1, selected = {}, perPage = 6 }

  -- The rows to show: with spoilers hidden, what comes later is one summary row.
  local function visible(list)
    local rows, hidden = {}, 0
    for _, row in ipairs(list or {}) do
      if row.masked then hidden = hidden + 1 else rows[#rows + 1] = row end
    end
    if hidden > 0 then rows[#rows + 1] = { summary = true, count = hidden, status = "later" } end
    return rows
  end
  local function headline(m, tab)
    if tab == "story" then return F("STORY_PROGRESS", m.story.done, m.story.total, m.badges)
    elseif tab == "post" then
      local cleared = false
      for _, row in ipairs(m.lists.story) do if row.id == "elite" then cleared = row.status == "done" end end
      return cleared and F("POST_PROGRESS", m.post.done, m.post.total) or T("AFTER_LEAGUE")
    elseif tab == "dex" then return F("CAUGHT_NOW", m.caught)
    end
    local have, total = 0, 0
    for _, row in ipairs(m.lists[tab]) do
      total = total + 1
      if row.status == "done" then have = have + 1 end
    end
    return F(tab == "items" and "HAVE_PROGRESS" or "READY_PROGRESS", have, total)
  end
  local function defaultPick(rows)
    for index, row in ipairs(rows) do if row.status == "current" or row.status == "ready" then return index end end
    for index, row in ipairs(rows) do if row.status == "open" then return index end end
    return nil
  end

  function Panel.drawJourney(clock, w, h)
    hits = {}
    w, h = fit(w, h, Panel.W, Panel.H)
    G.push("all")
    G.setLineStyle("smooth")
    local m = env.model(clock)
    if m.error then message(F("PANEL_ERROR", m.error), w, h, Panel.W, Panel.H); G.pop(); return end
    if m.waiting then message(T("WAITING"), w, h, Panel.W, Panel.H); G.pop(); return end
    if not m.supported then message(T("UNSUPPORTED"), w, h, Panel.W, Panel.H); G.pop(); return end
    color(C.bg); G.rectangle("fill", 0, 0, w, h)
    local tabs = T("TABS")
    for index, key in ipairs(TABS) do
      local x = 10 + (index - 1) * 92
      local on = state.tab == key
      button(type(tabs) == "table" and tabs[key] or key, x, 8, 89, 28, on and C.accent or C.card, function()
        if state.tab ~= key then state.tab, state.page, state.paged = key, 1, false end
      end, 12)
    end
    line(headline(m, state.tab), 12, 42, C.muted, 11, 340)

    local rows = visible(m.lists[state.tab])
    local per = state.perPage
    local pages = max(1, math.ceil(#rows / per))
    -- the page with the chosen row, when nobody turned the pages yet
    local pick = state.selected[state.tab]
    if pick and (pick > #rows or rows[pick].summary) then pick = nil end
    if not pick then
      pick = defaultPick(rows)
      if pick and not state.paged then state.page = math.ceil(pick / per) end
    end
    state.page = max(1, min(pages, state.page))
    local first = (state.page - 1) * per
    for slot = 1, per do
      local index = first + slot
      local row = rows[index]
      if not row then break end
      local y = 60 + (slot - 1) * 42
      local chosen = index == pick
      box(10, y, 460, 38, chosen and C.off or C.card, 6)
      mark(row.status, 24, y + 19)
      if row.summary then
        line(F(state.tab == "story" and "MORE_STEPS" or "MORE_LATER", row.count), 40, y + 4, C.muted, 13, 420)
        line(T("SPOILERS_HINT"), 40, y + 21, C.muted, 11, 420)
      else
        local right = 462
        if row.optional then
          local pw = font(10 * kf):getWidth(T("OPTIONAL")) / kx + 12
          pill(T("OPTIONAL"), right - pw, y + 4, C.off, C.muted)
          right = right - pw - 6
        end
        if row.pinned then
          local pw = font(10 * kf):getWidth(T("PINNED")) / kx + 12
          pill(T("PINNED"), right - pw, y + 4, C.accent, C.text)
          right = right - pw - 6
        end
        line(row.title, 40, y + 3, row.status == "later" and C.muted or C.text, 13, right - 40)
        line(row.note or row.hint, 40, y + 21, row.status == "ready" and C.warn or C.muted, 11, 420)
        hit(10, y, 460, 38, function() state.selected[state.tab] = index end)
      end
    end
    -- the chosen row in full
    local chosen = pick and rows[pick]
    box(10, 316, 460, 78, C.card, 6)
    if chosen then
      local room = 440
      if chosen.canPin then
        -- make it the goal the arrow leads to, or let it go
        room = 300
        button(T(chosen.pinned and "UNFOLLOW" or "FOLLOW"), 330, 320, 132, 22, chosen.pinned and C.warn or C.accent, function()
          env.setPin(not chosen.pinned and chosen.key or nil)
        end, 11)
      end
      line(chosen.title, 20, 322, C.text, 13, room)
      local used = para(chosen.hint ~= "" and chosen.hint or (chosen.note or ""), 20, 340, C.muted, 12, 440, 2)
      local extra = chosen.note or chosen.field
      if extra and chosen.hint ~= "" then line(extra, 20, 342 + used, chosen.status == "ready" and C.warn or C.accent, 11, 440) end
    else
      para(T("PICK_A_ROW"), 20, 330, C.muted, 12, 440, 3)
    end
    toggle(T("SHOW_UPCOMING"), 10, 400, 228, m.spoilers, function() env.setSpoilers(not env.spoilers()) end)
    toggle(T("SHOW_ARROW"), 242, 400, 228, env.arrow(), function() env.setArrow(not env.arrow()) end)
    if pages > 1 then
      for index, label in ipairs({ "<", ">" }) do
        local bx = index == 1 and 380 or 446
        local live = (index == 1 and state.page > 1) or (index == 2 and state.page < pages)
        button(label, bx, 39, 24, 18, live and C.off or C.card, live and function()
          state.page, state.paged = state.page + (index == 1 and -1 or 1), true
        end or nil, 11, live and C.text or C.line)
      end
      centred(state.page .. "/" .. pages, 404, 39, 42, 18, C.muted, 10)
    end
    G.pop()
  end

  ---------------------------------------------------------------------------
  -- Next step
  ---------------------------------------------------------------------------
  function Panel.drawNext(clock, w, h)
    w, h = fit(w, h, Panel.NW, Panel.NH)
    G.push("all")
    G.setLineStyle("smooth")
    local m = env.model(clock)
    if m.error then message(F("PANEL_ERROR", m.error), w, h, Panel.NW, Panel.NH); G.pop(); return end
    if m.waiting then message(T("WAITING"), w, h, Panel.NW, Panel.NH); G.pop(); return end
    if not m.supported then message(T("UNSUPPORTED"), w, h, Panel.NW, Panel.NH); G.pop(); return end
    color(C.bg); G.rectangle("fill", 0, 0, w, h)
    line(T("NEXT_LABEL"), 14, 10, C.accent, 11, 220)
    line(F("BADGES_CAUGHT", m.badges, m.caught), 240, 10, C.muted, 11, 226, "right")
    local step = m.pinned or m.next
    local y = 28
    if m.pinned then
      -- the player's own goal on top; the story's next step stays in sight
      color(C.bg); G.rectangle("fill", 0, 0, w, 24 * ky)
      line(T("PINNED_LABEL"), 14, 10, C.accent, 11, 220)
      line(F("BADGES_CAUGHT", m.badges, m.caught), 240, 10, C.muted, 11, 226, "right")
    end
    if step then
      line(step.title, 14, y, C.text, 17, 452)
      y = y + 26
      y = y + para(step.hint, 14, y, C.muted, 12, 452, 4) + 4
      if step.note then line(step.note, 14, y, C.accent, 11, 452); y = y + 16 end
      if m.pinned and m.next then line(F("STORY_NEXT", m.next.title), 14, y, C.muted, 11, 452); y = y + 16 end
    else
      line(T("ALL_DONE"), 14, y, C.go, 17, 452)
      y = y + 26
      y = y + para(T("ALL_DONE_HINT"), 14, y, C.muted, 12, 452, 3) + 4
    end
    -- the story so far
    local done, total = m.story.done + m.post.done, m.story.total + m.post.total
    y = max(y + 4, 134)
    box(14, y, 452, 8, C.card, 4)
    if total > 0 and done > 0 then box(14, y, max(8, 452 * done / total), 8, C.go, 4) end
    line(F("JOURNEY_PROGRESS", done, total), 14, y + 12, C.muted, 10, 452)
    y = y + 30
    -- what can be done now on the way
    local ready = m.ready or {}
    if #ready > 0 then
      line(T("READY_NOW"), 14, y, C.warn, 11, 452)
      y = y + 16
      local room = max(1, floor((Panel.NH - 6 - y) / 15))
      local shown = #ready > room and room - 1 or #ready
      for index = 1, shown do
        line("• " .. ready[index].text, 18, y, C.text, 11, 448)
        y = y + 15
      end
      if shown < #ready then line(F("AND_MORE", #ready - shown), 18, y, C.muted, 11, 448) end
    end
    G.pop()
  end

  function Panel.pointer(action, x, y, amount)
    if action == "wheel" then
      state.page, state.paged = state.page + ((tonumber(amount) or 0) > 0 and -1 or 1), true
      if state.page < 1 then state.page = 1 end
      return
    end
    if action ~= "down" then return end
    for index = #hits, 1, -1 do
      local at = hits[index]
      if x >= at.x and x < at.x + at.w and y >= at.y and y < at.y + at.h then
        at.action()
        return
      end
    end
  end
  Panel.state = state
  return Panel
end
