-- Minimal immediate-mode UI and layout with simple interactivity
local state = require("lib.state")
local detach = require("lib.detach")
local sandbox = require("lib.sandbox")
local canvases = require("lib.canvases")

local ui = {}

ui.color = {
  bg = { 18 / 255, 18 / 255, 20 / 255, 1 },           -- darker background
  panel = { 28 / 255, 28 / 255, 32 / 255, 1 },        -- lighter panel
  panelAlt = { 32 / 255, 32 / 255, 36 / 255, 1 },     -- nested elements
  text = { 230 / 255, 230 / 255, 230 / 255, 1 },      -- brighter text
  textDim = { 160 / 255, 160 / 255, 160 / 255, 1 },   -- secondary text
  accent = { 1, 0.6, 0.3, 1 },                        -- ORANGE accent color
  accentHover = { 1, 0.7, 0.4, 1 },                   -- lighter orange on hover
  warn = { 1, 0.5, 0.2, 1 },                          -- darker orange for warnings
  ok = { 0.4, 1, 0.5, 1 },                            -- green for success
  border = { 1, 1, 1, 0.1 },                          -- subtle borders
  shadow = { 0, 0, 0, 0.4 },                          -- shadow for depth
}

-- Optional external icon images (if present). We try to load PNGs at runtime.
ui.icons = { popout = nil, undock = nil, dock = nil }

local function load_icon(name)
  if ui.icons[name] ~= nil then
    return ui.icons[name]
  end
  local candidates = {
    "assets/icons/" .. name .. ".png",
    "assets/ui/" .. name .. ".png",
    "assets/" .. name .. ".png",
  }
  for _, p in ipairs(candidates) do
    if love.filesystem.getInfo(p) then
      local ok, img = pcall(love.graphics.newImage, p, { mipmaps = true })
      if ok and img then
        img:setFilter("linear", "linear", 4)
        ui.icons[name] = img
        return img
      end
    end
  end
  ui.icons[name] = false -- cache miss
  return false
end

ui.panels = {
  toolbar = { x = 0, y = 0, w = 0, h = 32 },
  io_inputs = { x = 0, y = 32, w = 320, h = 0 },
  game = { x = 320, y = 32, w = 0, h = 0 },
  io_outputs = { x = 0, y = 32, w = 320, h = 0 },
  debug_center = { x = 0, y = 0, w = 0, h = 0 },
  log = { x = 0, y = 0, w = 0, h = 120 },
}

-- Interactive hit regions
ui._boolRects = {}
ui._numRects = {}
ui._activeSlider = nil
ui._navRects = {}
ui._toolbarRects = {}
ui.leftTab = "inputs" -- for merged mode (Inputs | Outputs | Inspector)
ui.rightTab = "outputs" -- for non-merged mode (Outputs | Inspector)
ui._hoverTip = nil
ui.minimized = { inputs = false, outputs = false, game = false, debug = false, log = false }

-- Absolute on-screen rectangles of canvases (for hit testing)
-- { game = { x,y,w,h, scale }, debug = { x,y,w,h, scale } }
ui._canvasRects = { game = nil, debug = nil }

local function set_tooltip(text)
  if not text or text == "" then
    return
  end
  local mx, my = love.mouse.getPosition()
  ui._hoverTip = { text = text, x = mx + 14, y = my + 18 }
end

local function draw_panel(p)
  love.graphics.setColor(ui.color.panel)
  love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 4, 4)
end

local function text(x, y, s)
  love.graphics.setColor(ui.color.text)
  love.graphics.print(s, x, y)
end

local NAV_H = 24
local COLLAPSE_W = 28 -- width for collapsed side panels
local COLLAPSE_H = 22 -- height for collapsed top/bottom/stack panels

-- Rendering helper functions for modern UI
local function draw_panel_with_shadow(p)
  -- Draw subtle shadow
  love.graphics.setColor(ui.color.shadow)
  love.graphics.rectangle("fill", p.x + 3, p.y + 3, p.w, p.h, 6, 6)
  -- Draw panel
  love.graphics.setColor(ui.color.panel)
  love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 6, 6)
end

local function draw_rounded_button(x, y, w, h, color, hover)
  -- Flat design button with rounded corners
  love.graphics.setColor(hover and ui.color.accentHover or color)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)
end

-- Small toggle knob used by Inputs UI
local function draw_bool_toggle(x, y, val, isSimDriven)
  local r = 12
  -- Background: darker when simulator-driven
  love.graphics.setColor(isSimDriven and {0.12, 0.12, 0.12, 1} or {0.15, 0.15, 0.15, 1})
  love.graphics.rectangle("fill", x - 15, y - 15, 30, 30, 3, 3)
  -- Circle: dimmed when simulator-driven
  if val then
    love.graphics.setColor(isSimDriven and {0.5, 0.3, 0.15, 1} or ui.color.accent)
  else
    love.graphics.setColor(isSimDriven and {0.18, 0.18, 0.18, 1} or {0.25, 0.25, 0.25, 1})
  end
  love.graphics.circle("fill", x, y, r)
end

-- Section separator line
local function draw_section_separator(x, y, width)
  love.graphics.setColor(1, 0.6, 0.3, 0.15) -- Orange with 15% opacity
  love.graphics.setLineWidth(1)
  love.graphics.line(x + 8, y, x + width - 8, y)
end

-- Section header with orange accent color
local function draw_section_header(x, y, headerText)
  love.graphics.setFont(state.fonts.uiHeader)
  love.graphics.setColor(ui.color.accent) -- Orange
  love.graphics.print(headerText, x, y)
  love.graphics.setFont(state.fonts.ui) -- Reset to normal font
end

-- Icon: pop-out (undock). Draws a small window with a NE arrow escaping.
local function draw_icon_popout(x, y, size, color)
  local s = size or 16
  local px = math.floor(x) + 0.5
  local py = math.floor(y) + 0.5
  love.graphics.setLineWidth(1)
  love.graphics.setColor(color)
  -- window square (bottom-left)
  local w = math.floor(s * 0.55)
  love.graphics.rectangle("line", px, py + (s - w), w, w, 2, 2)
  -- arrow to NE
  local ax0 = px + math.floor(s * 0.35)
  local ay0 = py + math.floor(s * 0.35)
  local ax1 = px + s - 1
  local ay1 = py + 1
  love.graphics.line(ax0, ay0, ax1, ay1)
  -- arrow head
  love.graphics.polygon("fill", ax1, ay1, ax1 - 5, ay1, ax1, ay1 + 5)
end

-- Icon: dock (re-attach). Draws a window with an inward SW arrow.
local function draw_icon_dock(x, y, size, color)
  local s = size or 16
  local px = math.floor(x) + 0.5
  local py = math.floor(y) + 0.5
  love.graphics.setLineWidth(1)
  love.graphics.setColor(color)
  -- outer window
  love.graphics.rectangle("line", px, py, s, s, 2, 2)
  -- inward arrow SW
  local ax0 = px + s - 6
  local ay0 = py + 6
  local ax1 = px + 3
  local ay1 = py + s - 3
  love.graphics.line(ax0, ay0, ax1, ay1)
  love.graphics.polygon("fill", ax1, ay1, ax1 + 5, ay1, ax1, ay1 - 5)
end

-- Icon: download. Draws a down arrow with a tray.
local function draw_icon_download(x, y, size, color)
  local s = size or 16
  local px = math.floor(x) + 0.5
  local py = math.floor(y) + 0.5
  love.graphics.setLineWidth(1)
  love.graphics.setColor(color)
  -- tray at bottom
  love.graphics.line(px + 2, py + s - 2, px + s - 2, py + s - 2)
  -- down arrow
  local ax = px + s / 2
  local ay = py + 2
  local arrow_len = s - 6
  love.graphics.line(ax, ay, ax, ay + arrow_len)
  -- arrow head
  love.graphics.polygon("fill", ax, ay + arrow_len, ax - 4, ay + arrow_len - 4, ax + 4, ay + arrow_len - 4)
end

local function draw_nav_bar(p, title, which)
  -- which: 'game' | 'debug' | 'left' (merged tabs)
  love.graphics.setColor(0.16, 0.16, 0.18, 1)
  love.graphics.rectangle("fill", p.x, p.y, p.w, NAV_H, 4, 4)
  love.graphics.setColor(1, 1, 1, 0.08)
  love.graphics.rectangle("line", p.x + 0.5, p.y + 0.5, p.w - 1, NAV_H - 1, 4, 4)

  ui._navRects = ui._navRects or {}

  if which == "left" and ui.mergedOutputs then
    -- Split header into three equal clickable parts: I | O | Insp
    local third = math.floor(p.w / 3)
    local tabRects = {
      { x = p.x, y = p.y, w = third, h = NAV_H, label = "I", tab = "inputs" },
      { x = p.x + third, y = p.y, w = third, h = NAV_H, label = "O", tab = "outputs" },
      { x = p.x + third * 2, y = p.y, w = p.w - third * 2, h = NAV_H, label = "Insp", tab = "inspector" },
    }

    for _, tabDef in ipairs(tabRects) do
      local isActive = (ui.leftTab == tabDef.tab)
      love.graphics.setColor(isActive and ui.color.accent or { 0.22, 0.22, 0.26, 1 })
      love.graphics.rectangle("fill", tabDef.x, tabDef.y, tabDef.w, tabDef.h, 4, 4)
      love.graphics.setColor(1, 1, 1, isActive and 1 or 0.85)
      love.graphics.printf(tabDef.label, tabDef.x, tabDef.y + 3, tabDef.w, "center")
      ui._navRects["left_tab_" .. tabDef.tab] =
        { x = tabDef.x, y = tabDef.y, w = tabDef.w, h = tabDef.h, action = "left_tab", tab = tabDef.tab }
    end

    -- Divider lines between tabs
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.line(p.x + third, p.y + 2, p.x + third, p.y + NAV_H - 2)
    love.graphics.line(p.x + third * 2, p.y + 2, p.x + third * 2, p.y + NAV_H - 2)
  elseif which == "outputs" then
    -- Split header into two clickable halves: O | Insp (non-merged mode)
    -- Reserve space for minimize button on right
    local btnSpace = 24
    local availW = p.w - btnSpace
    local half = math.floor(availW / 2)
    local tabRects = {
      { x = p.x, y = p.y, w = half, h = NAV_H, label = "O", tab = "outputs" },
      { x = p.x + half, y = p.y, w = availW - half, h = NAV_H, label = "Insp", tab = "inspector" },
    }

    for _, tabDef in ipairs(tabRects) do
      local isActive = (ui.rightTab == tabDef.tab)
      love.graphics.setColor(isActive and ui.color.accent or { 0.22, 0.22, 0.26, 1 })
      love.graphics.rectangle("fill", tabDef.x, tabDef.y, tabDef.w, tabDef.h, 4, 4)
      love.graphics.setColor(1, 1, 1, isActive and 1 or 0.85)
      love.graphics.printf(tabDef.label, tabDef.x, tabDef.y + 3, tabDef.w, "center")
      ui._navRects["right_tab_" .. tabDef.tab] =
        { x = tabDef.x, y = tabDef.y, w = tabDef.w, h = tabDef.h, action = "right_tab", tab = tabDef.tab }
    end

    -- Divider line between tabs
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.line(p.x + half, p.y + 2, p.x + half, p.y + NAV_H - 2)
  else
    -- Standard title
    love.graphics.setColor(ui.color.text)
    love.graphics.print(title or "", p.x + 8, p.y + 5)

    -- Right-side buttons
    if which == "game" or which == "debug" then
      local btnSize = 18
      local spacing = 4
      local by = p.y + math.floor((NAV_H - btnSize) / 2)
      local right = p.x + p.w - 6
      -- Detach button (rightmost)
      local bx = right - btnSize
      local is_det = detach.is_enabled(which)

      -- Hover detection
      local mx, my = love.mouse.getPosition()
      local is_hover = (mx >= bx and my >= by and mx <= bx + btnSize and my <= by + btnSize)

      -- Button background
      local bg = is_det and ui.color.accent or { 0.22, 0.22, 0.26, 1 }
      local bg_hover = is_det and { 0.36, 0.62, 1.0, 1 } or { 0.28, 0.28, 0.34, 1 }
      love.graphics.setColor(is_hover and bg_hover or bg)
      love.graphics.rectangle("fill", bx, by, btnSize, btnSize, 4, 4)
      love.graphics.setColor(0, 0, 0, 0.35)
      love.graphics.rectangle("line", bx + 0.5, by + 0.5, btnSize - 1, btnSize - 1, 4, 4)

      -- Icon: prefer external PNG if provided, otherwise fallback to vector
      local pad = 3
      local target = btnSize - pad * 2
      local img = (is_det and (load_icon("dock") or load_icon("attach") or load_icon("dock_filled")))
        or (load_icon("undock") or load_icon("popout") or load_icon("arrow_ne"))
      if img and img ~= false then
        local iw, ih = img:getDimensions()
        local scale = math.min(target / iw, target / ih)
        local ox = (target - iw * scale) / 2
        local oy = (target - ih * scale) / 2
        love.graphics.setColor(1, 1, 1, is_hover and 1 or 0.95)
        love.graphics.draw(img, bx + pad + ox, by + pad + oy, 0, scale, scale)
      else
        local iconColor = is_det and { 1, 1, 1, 1 } or { 1, 1, 1, 0.95 }
        if is_det then
          draw_icon_dock(bx + pad, by + pad, target, iconColor)
        else
          draw_icon_popout(bx + pad, by + pad, target, iconColor)
        end
      end

      -- Use unique keys per control to avoid collisions with minimize/other buttons
      local det_tip = is_det and "Attach back to main window" or "Detach into separate window"
      ui._navRects["detach_" .. which] =
        { x = bx, y = by, w = btnSize, h = btnSize, action = "toggle_detach", which = which, tooltip = det_tip }
      if is_hover then
        set_tooltip(det_tip)
      end

      -- Minimize button (left of detach)
      bx = bx - spacing - btnSize
      local min_key = (which == "game") and "game" or ((which == "debug") and "debug" or which)
      local is_min = ui.minimized[min_key]
      local is_hover_min = (mx >= bx and my >= by and mx <= bx + btnSize and my <= by + btnSize)
      love.graphics.setColor(is_hover_min and { 0.28, 0.28, 0.34, 1 } or { 0.22, 0.22, 0.26, 1 })
      love.graphics.rectangle("fill", bx, by, btnSize, btnSize, 4, 4)
      love.graphics.setColor(0, 0, 0, 0.35)
      love.graphics.rectangle("line", bx + 0.5, by + 0.5, btnSize - 1, btnSize - 1, 4, 4)
      local minImg = load_icon(is_min and "add" or "remove")
      local iw, ih = 24, 24
      if minImg and minImg ~= false then
        iw, ih = minImg:getDimensions()
      end
      local scale = (btnSize - pad * 2) / math.max(iw, ih)
      love.graphics.setColor(1, 1, 1, is_hover_min and 1 or 0.95)
      if minImg and minImg ~= false then
        love.graphics.draw(minImg, bx + pad, by + pad, 0, scale, scale)
      else
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.rectangle("fill", bx + 4, by + btnSize / 2 - 1, btnSize - 8, 2)
      end
      local tip = is_min and ("Show " .. (title or which or "")) or ("Hide " .. (title or which or ""))
      ui._navRects["min_" .. which] =
        { x = bx, y = by, w = btnSize, h = btnSize, action = "toggle_min", which = min_key, tooltip = tip }
      if is_hover_min then
        set_tooltip(tip)
      end
    end
  end

  -- Minimize button for non-game/debug panels (left tabs, outputs, log)
  if which ~= "game" and which ~= "debug" then
    local btnSize = 18
    local by = p.y + math.floor((NAV_H - btnSize) / 2)
    local bx = p.x + p.w - (btnSize + 6)
    local mx, my = love.mouse.getPosition()
    local key = (which == "left") and "inputs"
      or (which == "outputs" and "outputs" or (which == "log" and "log" or (which == "inputs" and "inputs" or which)))
    if key then
      local is_min = ui.minimized[key]
      local is_hover = (mx >= bx and my >= by and mx <= bx + btnSize and my <= by + btnSize)
      love.graphics.setColor(is_hover and { 0.28, 0.28, 0.34, 1 } or { 0.22, 0.22, 0.26, 1 })
      love.graphics.rectangle("fill", bx, by, btnSize, btnSize, 4, 4)
      love.graphics.setColor(0, 0, 0, 0.35)
      love.graphics.rectangle("line", bx + 0.5, by + 0.5, btnSize - 1, btnSize - 1, 4, 4)
      local pad = 3
      local img = load_icon(is_min and "add" or "remove")
      if img and img ~= false then
        local iw, ih = img:getDimensions()
        local target = btnSize - pad * 2
        local scale = math.min(target / iw, target / ih)
        local ox = (target - iw * scale) / 2
        local oy = (target - ih * scale) / 2
        love.graphics.setColor(1, 1, 1, is_hover and 1 or 0.95)
        love.graphics.draw(img, bx + pad + ox, by + pad + oy, 0, scale, scale)
      else
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.rectangle("fill", bx + 4, by + btnSize / 2 - 1, btnSize - 8, 2)
      end
      local tip = is_min and "Show panel" or "Hide panel"
      ui._navRects["min_" .. which] =
        { x = bx, y = by, w = btnSize, h = btnSize, action = "toggle_min", which = key, tooltip = tip }
      if is_hover then
        set_tooltip(tip)
      end
    end
  end
end

local function panel_content_scissor(p)
  love.graphics.setScissor(p.x, p.y + NAV_H, p.w, p.h - NAV_H)
end

-- Collapsed placeholders ------------------------------------------------------
local function draw_collapsed_vertical(p, which, title)
  -- Slim vertical bar with a (+) to restore
  local w = math.max(1, p.w)
  local h = math.max(1, p.h)
  love.graphics.setColor(0.16, 0.16, 0.18, 1)
  love.graphics.rectangle("fill", p.x, p.y, w, h, 4, 4)
  love.graphics.setColor(1, 1, 1, 0.08)
  love.graphics.rectangle("line", p.x + 0.5, p.y + 0.5, w - 1, h - 1, 4, 4)
  local btn = { x = p.x + math.floor((w - 18) / 2), y = p.y + math.floor((h - 18) / 2), w = 18, h = 18 }
  local mx, my = love.mouse.getPosition()
  local is_hover = (mx >= btn.x and my >= btn.y and mx <= btn.x + btn.w and my <= btn.y + btn.h)
  love.graphics.setColor(is_hover and { 0.28, 0.28, 0.34, 1 } or { 0.22, 0.22, 0.26, 1 })
  love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 4, 4)
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("line", btn.x + 0.5, btn.y + 0.5, btn.w - 1, btn.h - 1, 4, 4)
  local img = load_icon("add")
  if img and img ~= false then
    local iw, ih = img:getDimensions()
    local pad = 3
    local target = btn.w - pad * 2
    local scale = math.min(target / iw, target / ih)
    local ox = (target - iw * scale) / 2
    local oy = (target - ih * scale) / 2
    love.graphics.setColor(1, 1, 1, is_hover and 1 or 0.95)
    love.graphics.draw(img, btn.x + pad + ox, btn.y + pad + oy, 0, scale, scale)
  else
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.rectangle("fill", btn.x + 4, btn.y + btn.h / 2 - 1, btn.w - 8, 2)
    love.graphics.rectangle("fill", btn.x + btn.w / 2 - 1, btn.y + 4, 2, btn.h - 8)
  end
  local tip = "Show " .. (title or which or "")
  ui._navRects[which .. "_collapsed"] =
    { x = btn.x, y = btn.y, w = btn.w, h = btn.h, action = "toggle_min", which = which, tooltip = tip }
  if is_hover then
    set_tooltip(tip)
  end
end

local function draw_collapsed_horizontal(p, which, title)
  -- Slim horizontal bar with a (+) to restore and title text
  local w = math.max(1, p.w)
  local h = math.max(COLLAPSE_H, p.h)
  love.graphics.setColor(0.16, 0.16, 0.18, 1)
  love.graphics.rectangle("fill", p.x, p.y, w, h, 4, 4)
  love.graphics.setColor(1, 1, 1, 0.08)
  love.graphics.rectangle("line", p.x + 0.5, p.y + 0.5, w - 1, h - 1, 4, 4)
  -- Title
  love.graphics.setColor(ui.color.text)
  love.graphics.print(title or "", p.x + 8, p.y + 5)
  -- Button on right
  local btn = { x = p.x + w - 6 - 18, y = p.y + math.floor((h - 18) / 2), w = 18, h = 18 }
  local mx, my = love.mouse.getPosition()
  local is_hover = (mx >= btn.x and my >= btn.y and mx <= btn.x + btn.w and my <= btn.y + btn.h)
  love.graphics.setColor(is_hover and { 0.28, 0.28, 0.34, 1 } or { 0.22, 0.22, 0.26, 1 })
  love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 4, 4)
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("line", btn.x + 0.5, btn.y + 0.5, btn.w - 1, btn.h - 1, 4, 4)
  local img = load_icon("add")
  if img and img ~= false then
    local iw, ih = img:getDimensions()
    local pad = 3
    local target = btn.w - pad * 2
    local scale = math.min(target / iw, target / ih)
    local ox = (target - iw * scale) / 2
    local oy = (target - ih * scale) / 2
    love.graphics.setColor(1, 1, 1, is_hover and 1 or 0.95)
    love.graphics.draw(img, btn.x + pad + ox, btn.y + pad + oy, 0, scale, scale)
  else
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.rectangle("fill", btn.x + 4, btn.y + btn.h / 2 - 1, btn.w - 8, 2)
    love.graphics.rectangle("fill", btn.x + btn.w / 2 - 1, btn.y + 4, 2, btn.h - 8)
  end
  local tip = "Show " .. (title or which or "")
  ui._navRects[which .. "_collapsed"] =
    { x = btn.x, y = btn.y, w = btn.w, h = btn.h, action = "toggle_min", which = which, tooltip = tip }
  if is_hover then
    set_tooltip(tip)
  end
end

-- Toolbar buttons (icon-only) -------------------------------------------------
local function draw_toolbar_icon_button(x, y, opts)
  -- opts: { name='play', active=false, action='toggle_run', tooltip='Play/Pause' }
  local btnSize = 22
  local pad = 3
  local bx, by = x, y
  local mx, my = love.mouse.getPosition()
  local is_hover = (mx >= bx and my >= by and mx <= bx + btnSize and my <= by + btnSize)
  local bg_base = opts.active and ui.color.accent or { 0.22, 0.22, 0.26, 1 }
  local bg_hover = opts.active and ui.color.accentHover or { 0.28, 0.28, 0.34, 1 }
  love.graphics.setColor(is_hover and bg_hover or bg_base)
  love.graphics.rectangle("fill", bx, by, btnSize, btnSize, 4, 4)
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("line", bx + 0.5, by + 0.5, btnSize - 1, btnSize - 1, 4, 4)

  -- icon draw
  local img = load_icon(opts.name)
  local target = btnSize - pad * 2
  if img and img ~= false then
    local iw, ih = img:getDimensions()
    local scale = math.min(target / iw, target / ih)
    local ox = (target - iw * scale) / 2
    local oy = (target - ih * scale) / 2
    love.graphics.setColor(1, 1, 1, is_hover and 1 or 0.95)
    love.graphics.draw(img, bx + pad + ox, by + pad + oy, 0, scale, scale)
  else
    -- fallback: vector icons
    love.graphics.setColor(1, 1, 1, 0.95)
    if opts.name == "download" then
      draw_icon_download(bx + pad, by + pad, target, { 1, 1, 1, 0.95 })
    else
      -- default: small triangle for play
      love.graphics.polygon("fill", bx + 7, by + 5, bx + 7, by + btnSize - 5, bx + btnSize - 5, by + btnSize / 2)
    end
  end

  -- register hit rect
  ui._toolbarRects[#ui._toolbarRects + 1] =
    { x = bx, y = by, w = btnSize, h = btnSize, action = opts.action, tooltip = opts.tooltip }
  if is_hover and opts.tooltip then
    set_tooltip(opts.tooltip)
  end

  return btnSize
end

-- Helper function to get channels for active tab
local function get_tab_channels(tabName)
  if not state.ioTabs.enabled then
    local all = {}
    for i = 1, 32 do all[i] = i end
    return all
  end

  for _, tab in ipairs(state.ioTabs.tabs) do
    if tab.name == tabName then
      if tab.channels == nil then
        -- "all" tab - show all 32 channels
        local all = {}
        for i = 1, 32 do all[i] = i end
        return all
      else
        return tab.channels
      end
    end
  end

  -- Default to all if tab not found
  local all = {}
  for i = 1, 32 do all[i] = i end
  return all
end

-- Draw tab bar for I/O panels
local function draw_tab_bar(p, which)
  if not state.ioTabs.enabled then return 0 end

  local font = love.graphics.getFont()
  local tabs = state.ioTabs.tabs
  local activeTab = which == "input" and state.ioTabs.activeInputTab or state.ioTabs.activeOutputTab
  local tabH = 24
  local y = p.y + NAV_H
  local x = p.x + 8

  for i, tab in ipairs(tabs) do
    local label = tab.label or tab.name or "Tab"
    local tabW = (font and font:getWidth(label) or (#label * 7)) + 16
    local isActive = (tab.name == activeTab)

    -- Draw tab button
    love.graphics.setColor(isActive and ui.color.accent or ui.color.panelAlt)
    love.graphics.rectangle("fill", x, y, tabW, tabH, 4, 4)

    -- Tab text
    love.graphics.setColor(ui.color.text)
    love.graphics.print(label, x + 8, y + 4)

    -- Register hit region
    ui._navRects["tab_" .. which .. "_" .. i] = {
      x = x, y = y, w = tabW, h = tabH,
      action = "io_tab",
      which = which,
      tab = tab.name
    }

    x = x + tabW + 4
  end

  return tabH  -- Return height used for layout adjustment
end

-- Shared content renderers (used for merged tab mode)
local function draw_inputs_content(p)
  local fontH = love.graphics.getFont() and love.graphics.getFont():getHeight() or 14
  local labelPad = 8

  -- Draw tab bar and adjust content position
  local tabBarH = draw_tab_bar(p, "input")
  local contentYOffset = tabBarH > 0 and (tabBarH + 8) or 0

  -- Get active channels based on tab selection
  local channels = get_tab_channels(state.ioTabs.activeInputTab)
  local channelSet = {}
  for _, ch in ipairs(channels) do
    channelSet[ch] = true
  end

  -- Bool inputs (click to toggle)
  draw_section_header(p.x + 8, p.y + NAV_H + contentYOffset + 6, "Bool Inputs")
  local headerH = state.fonts.uiHeader:getHeight()
  local boolInBaseY = p.y + NAV_H + contentYOffset + 6 + headerH + 12
  ui._boolRects = {}
  local mx, my = love.mouse.getPosition()

  for i = 1, 32 do
    if channelSet[i] then
      local col = (i - 1) % 8
      local row = math.floor((i - 1) / 8)
      local bx = p.x + 24 + col * 38
      local by = boolInBaseY + row * 40
      local isSimDriven = state.simulatorDriven.inputB[i]

      draw_bool_toggle(bx, by, state.inputB[i], isSimDriven)
      ui._boolRects[i] = { x = bx - 15, y = by - 15, w = 30, h = 30 }

      -- Add centered label inside toggle
      local font = love.graphics.getFont()
      local fontHeight = font:getHeight()
      if isSimDriven then
        -- Centered "S" overlay for simulator-driven: white when ON, orange when OFF
        local labelText = "S"
        local labelWidth = font:getWidth(labelText)
        love.graphics.setColor(state.inputB[i] and ui.color.text or ui.color.warn)
        love.graphics.print(labelText, bx - labelWidth/2, by - fontHeight/2)
      elseif not state.inputB[i] then
        -- Channel number only when inactive and not simulator-driven
        local labelText = string.format("%d", i)
        local labelWidth = font:getWidth(labelText)
        love.graphics.setColor(ui.color.textDim)
        love.graphics.print(labelText, bx - labelWidth/2, by - fontHeight/2)
      end
      -- Add tooltip on hover
      if mx >= bx - 15 and my >= by - 15 and mx < bx + 15 and my < by + 15 then
        local tooltipText = isSimDriven and string.format("Boolean Input %d\nControlled by simulator", i)
                                          or string.format("Boolean Input %d\nClick to toggle", i)
        set_tooltip(tooltipText)
      end
    end
  end

  -- Number inputs (sliders 0..1)
  local separatorY = boolInBaseY + 4 * 40 + 20
  draw_section_separator(p.x, separatorY, p.w)
  local numInLabelY = separatorY + 20
  draw_section_header(p.x + 8, numInLabelY, "Number Inputs (0..1)")
  ui._numRects = {}
  local sx = p.x + 8
  local sy = numInLabelY + headerH + 12
  local colW = (p.w - 16 - 8) / 2
  local sW = colW - 48 -- shrink slider width to leave space for value text to the right
  local sH = 12
  local rowGap = sH + 22 -- generous vertical spacing

  for i = 1, 32 do
    if channelSet[i] then
      local col = (i - 1) % 2
      local row = math.floor((i - 1) / 2)
      local rx = sx + col * colW
      local ry = sy + row * rowGap
      local v = math.max(0, math.min(1, state.inputN[i] or 0))
      local isSimDriven = state.simulatorDriven.inputN[i]

      -- Label with grayed-out color if simulator-driven
      love.graphics.setColor(isSimDriven and {0.3, 0.3, 0.3, 1} or ui.color.text)
      love.graphics.print(string.format("N%02d", i), rx, ry - (fontH + 2))

      -- Add "SIM" indicator for simulator-driven
      if isSimDriven then
        love.graphics.setColor(ui.color.warn)
        love.graphics.print("SIM", rx + 30, ry - (fontH + 2))
      end

      -- Slider background (darker if simulator-driven)
      love.graphics.setColor(isSimDriven and {0.12, 0.12, 0.12, 1} or {0.2, 0.2, 0.2, 1})
      love.graphics.rectangle("fill", rx, ry, sW, sH, 2, 2)
      -- Slider fill (dimmed if simulator-driven)
      if v > 0 then
        love.graphics.setColor(isSimDriven and {0.5, 0.3, 0.15, 1} or ui.color.accent)
        love.graphics.rectangle("fill", rx, ry, sW * v, sH, 2, 2)
      end
      -- Slider border
      love.graphics.setColor(isSimDriven and {0.3, 0.3, 0.3, 1} or ui.color.text)
      love.graphics.rectangle("line", rx, ry, sW, sH, 2, 2)
      love.graphics.print(string.format("%.2f", v), rx + sW + 8, ry - 1)
      ui._numRects[i] = { x = rx, y = ry, w = sW, h = sH }
      -- Add tooltip on hover
      if mx >= rx and my >= ry and mx < rx + sW and my < ry + sH then
        local tooltipText = isSimDriven and string.format("Number Input %d\nControlled by simulator", i)
                                          or string.format("Number Input %d (0.00 - 1.00)\nDrag or scroll to adjust", i)
        set_tooltip(tooltipText)
      end
    end
  end
end

local function draw_outputs_content(p)
  local fontH = love.graphics.getFont() and love.graphics.getFont():getHeight() or 14
  local labelPad = 8

  -- Draw tab bar and adjust content position
  local tabBarH = draw_tab_bar(p, "output")
  local contentYOffset = tabBarH > 0 and (tabBarH + 8) or 0

  -- Get active channels based on tab selection
  local channels = get_tab_channels(state.ioTabs.activeOutputTab)
  local channelSet = {}
  for _, ch in ipairs(channels) do
    channelSet[ch] = true
  end

  -- Bool outputs
  draw_section_header(p.x + 8, p.y + NAV_H + contentYOffset + 6, "Bool Outputs")
  local headerH = state.fonts.uiHeader:getHeight()
  local boolOutBaseY = p.y + NAV_H + contentYOffset + 6 + headerH + 12

  for i = 1, 32 do
    if channelSet[i] then
      local col = (i - 1) % 8
      local row = math.floor((i - 1) / 8)
      local bx = p.x + 24 + col * 38
      local by = boolOutBaseY + row * 40
      love.graphics.setColor(state.outputB[i] and ui.color.accent or { 0.2, 0.2, 0.2, 1 })
      love.graphics.circle("fill", bx, by, 10)
      -- Add label inside output (only when inactive)
      if not state.outputB[i] then
        love.graphics.setColor(ui.color.textDim)
        local labelText = string.format("%d", i)
        local font = love.graphics.getFont()
        local labelWidth = font:getWidth(labelText)
        local fontHeight = font:getHeight()
        love.graphics.print(labelText, bx - labelWidth/2, by - fontHeight/2)
      end
    end
  end

  -- Number outputs (text)
  local separatorY = boolOutBaseY + 4 * 40 + 20
  draw_section_separator(p.x, separatorY, p.w)
  local outLabelY = separatorY + 20
  draw_section_header(p.x + 8, outLabelY, "Number Outputs")
  local sx = p.x + 8
  local oy = outLabelY + headerH + 12
  local colW = (p.w - 16 - 8) / 2

  for i = 1, 32 do
    if channelSet[i] then
      local col = (i - 1) % 2
      local row = math.floor((i - 1) / 2)
      local tx = sx + col * colW
      local ty = oy + row * (fontH + 4)
      love.graphics.setColor(ui.color.text)
      love.graphics.print(string.format("O%02d %.3f", i, state.outputN[i] or 0), tx, ty)
    end
  end
end

-- Inspector panel: tree view of script globals and simulator state
local inspector_builtin_globals = {
  -- Safe globals from sandbox
  ["assert"] = true, ["error"] = true, ["ipairs"] = true, ["next"] = true,
  ["pairs"] = true, ["pcall"] = true, ["select"] = true, ["tonumber"] = true,
  ["tostring"] = true, ["type"] = true, ["unpack"] = true, ["xpcall"] = true,
  ["print"] = true,
  -- Safe tables
  ["math"] = true, ["string"] = true, ["table"] = true,
  -- Stormworks API
  ["input"] = true, ["output"] = true, ["property"] = true, ["screen"] = true,
  ["dbg"] = true, ["time"] = true,
  -- Internal
  ["_G"] = true, ["require"] = true, ["_input_simulator_typehint"] = true,
  -- Callback functions (user-defined but not data)
  ["onTick"] = true, ["onDraw"] = true, ["onAttatch"] = true, ["onDebugDraw"] = true,
}

local function is_array(t)
  if type(t) ~= "table" then return false end
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count == #t and count > 0
end

local function format_value(v, maxLen)
  maxLen = maxLen or 30
  local t = type(v)
  local str
  if t == "string" then
    str = '"' .. v:gsub("\n", "\\n"):gsub("\r", "\\r") .. '"'
  elseif t == "number" then
    if v == math.floor(v) then
      str = tostring(v)
    else
      str = string.format("%.4g", v)
    end
  elseif t == "boolean" then
    str = v and "true" or "false"
  elseif t == "nil" then
    str = "nil"
  elseif t == "table" then
    if is_array(v) then
      str = string.format("[array:%d]", #v)
    else
      local count = 0
      for _ in pairs(v) do count = count + 1 end
      str = string.format("{table:%d}", count)
    end
  elseif t == "function" then
    str = "<function>"
  else
    str = "<" .. t .. ">"
  end
  if #str > maxLen then
    str = str:sub(1, maxLen - 3) .. "..."
  end
  return str
end

-- Hit regions for inspector tree nodes
ui._inspectorRects = {}
ui._inspectorPinRects = {}
ui._inspectorPinsChanged = false
ui._inspectorValueRects = {} -- { path = { x, y, w, h, valueType, globalKey } }
ui._inspectorEdit = {
  active = false,
  path = nil,         -- full path like "script.myVar"
  globalKey = nil,    -- just the key name for top-level editing
  text = "",          -- current edit text
  valueType = nil,    -- "string", "number", "boolean"
  lastClickTime = 0,
  lastClickPath = nil,
}

local function draw_tree_node(p, path, key, value, indent, y, contentX, contentW)
  local fontH = love.graphics.getFont() and love.graphics.getFont():getHeight() or 14
  local lineH = fontH + 4
  local indentPx = indent * 16
  local x = contentX + indentPx

  -- Check if visible (within scissor region)
  local panelTop = p.y + NAV_H
  local panelBottom = p.y + p.h
  if y + lineH < panelTop or y > panelBottom then
    -- Still need to count lines for layout, but skip drawing
    local drawnLines = 1
    if type(value) == "table" and state.inspector.expanded[path] then
      local sorted_keys = {}
      for k in pairs(value) do table.insert(sorted_keys, k) end
      table.sort(sorted_keys, function(a, b)
        if type(a) == type(b) then
          if type(a) == "number" then return a < b end
          return tostring(a) < tostring(b)
        end
        return type(a) == "number"
      end)
      for _, k in ipairs(sorted_keys) do
        local childPath = path .. "." .. tostring(k)
        local _, childLines = draw_tree_node(p, childPath, k, value[k], indent + 1, y + drawnLines * lineH, contentX, contentW)
        drawnLines = drawnLines + childLines
      end
    end
    return y + lineH, drawnLines
  end

  local isTable = type(value) == "table"
  local isExpanded = state.inspector.expanded[path]

  -- Draw expand/collapse indicator for tables
  if isTable then
    local indicator = isExpanded and "v" or ">"
    love.graphics.setColor(ui.color.textDim)
    love.graphics.print(indicator, x, y)
  end

  -- Draw key
  local keyX = x + (isTable and 12 or 0)
  local keyStr = type(key) == "number" and string.format("[%d]", key) or tostring(key)
  love.graphics.setColor(ui.color.accent)
  love.graphics.print(keyStr, keyX, y)

  -- Draw colon and value
  local font = love.graphics.getFont()
  local keyW = font:getWidth(keyStr)
  local valX = keyX + keyW + 4
  love.graphics.setColor(ui.color.textDim)
  love.graphics.print(":", valX, y)
  valX = valX + 8

  local maxValW = contentX + contentW - valX - 8
  local t = type(value)
  local isEditable = (t == "string" or t == "number" or t == "boolean")
  local isEditing = ui._inspectorEdit.active and ui._inspectorEdit.path == path

  if isEditing then
    -- Draw edit field
    local editW = math.min(200, maxValW)
    local editH = lineH - 2
    -- Background
    love.graphics.setColor(ui.color.panelAlt)
    love.graphics.rectangle("fill", valX, y, editW, editH, 2)
    -- Border
    love.graphics.setColor(ui.color.accent)
    love.graphics.rectangle("line", valX, y, editW, editH, 2)
    -- Text
    love.graphics.setColor(ui.color.text)
    local displayText = ui._inspectorEdit.text
    -- Add cursor
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
      displayText = displayText .. "|"
    end
    love.graphics.print(displayText, valX + 4, y + 1)
  else
    -- Draw static value
    local valStr = format_value(value, math.floor(maxValW / 7))
    if isTable then
      love.graphics.setColor(ui.color.text)
    else
      if t == "number" then
        love.graphics.setColor(0.6, 0.8, 1, 1)
      elseif t == "string" then
        love.graphics.setColor(0.8, 1, 0.6, 1)
      elseif t == "boolean" then
        love.graphics.setColor(1, 0.7, 0.5, 1)
      else
        love.graphics.setColor(ui.color.textDim)
      end
    end
    love.graphics.print(valStr, valX, y)

    -- Register editable value hit rect
    if isEditable then
      local valW = font:getWidth(valStr)
      ui._inspectorValueRects[path] = {
        x = valX, y = y, w = valW, h = lineH,
        valueType = t, path = path
      }
    end
  end

  -- Register hit region for expandable nodes
  if isTable then
    ui._inspectorRects[path] = {
      x = x, y = y, w = contentW - indentPx, h = lineH,
      action = "toggle_expand", path = path
    }
  end

  -- Recursively draw children if expanded
  local drawnLines = 1
  if isTable and isExpanded then
    local sorted_keys = {}
    for k in pairs(value) do table.insert(sorted_keys, k) end
    table.sort(sorted_keys, function(a, b)
      if type(a) == type(b) then
        if type(a) == "number" then return a < b end
        return tostring(a) < tostring(b)
      end
      return type(a) == "number"
    end)
    for _, k in ipairs(sorted_keys) do
      local childPath = path .. "." .. tostring(k)
      local _, childLines = draw_tree_node(p, childPath, k, value[k], indent + 1, y + drawnLines * lineH, contentX, contentW)
      drawnLines = drawnLines + childLines
    end
  end

  return y + lineH, drawnLines
end

-- Helper: Check if a global is pinned
local function is_global_pinned(name)
  for _, p in ipairs(state.inspector.pinnedGlobals or {}) do
    if p == name then return true end
  end
  return false
end

-- Helper: Draw a single inspector row with pin button
local function draw_inspector_row(p, item, y, contentX, contentW, lineH, fontH)
  local isPinned = is_global_pinned(item.key)
  local pinW = 14

  -- Draw pin button
  local pinX = contentX
  if isPinned then
    love.graphics.setColor(ui.color.accent)
    love.graphics.print("*", pinX, y)
  else
    love.graphics.setColor(ui.color.textDim)
    love.graphics.print("o", pinX, y)
  end

  -- Register pin button hit region
  ui._inspectorPinRects[item.key] = {
    x = pinX, y = y, w = pinW, h = lineH,
    globalName = item.key, isPinned = isPinned
  }

  -- Draw the tree node (offset by pin button width)
  local path = "script." .. tostring(item.key)
  local _, lines = draw_tree_node(p, path, item.key, item.value, 0, y, contentX + pinW + 2, contentW - pinW - 2)

  return lines
end

local function draw_inspector_content(p)
  local fontH = love.graphics.getFont() and love.graphics.getFont():getHeight() or 14
  local lineH = fontH + 4
  local headerH = state.fonts.uiHeader and state.fonts.uiHeader:getHeight() or fontH

  -- Clear previous hit regions
  ui._inspectorRects = {}
  ui._inspectorPinRects = {}
  ui._inspectorValueRects = {}

  local contentX = p.x + 8
  local contentW = p.w - 16
  local y = p.y + NAV_H + 8 - (state.inspector.scrollOffset * lineH)

  -- Draw hide-functions toggle button in top right
  local btnW = 24
  local btnH = 16
  local btnX = p.x + p.w - btnW - 8
  local btnY = p.y + NAV_H + 4
  local hideFn = state.inspector.hideFunctions
  if hideFn then
    love.graphics.setColor(ui.color.panel)
  else
    love.graphics.setColor(ui.color.accent[1], ui.color.accent[2], ui.color.accent[3], 0.3)
  end
  love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 3)
  if hideFn then
    love.graphics.setColor(ui.color.textDim)
  else
    love.graphics.setColor(ui.color.accent)
  end
  love.graphics.print("fn", btnX + 4, btnY + 1)
  ui._navRects["inspector_hide_fn"] = {
    x = btnX, y = btnY, w = btnW, h = btnH,
    action = "toggle_hide_functions"
  }

  -- Gather script globals with origin info
  local pinned = {}
  local mainGlobals = {}
  local moduleGlobals = {} -- { [modname] = { items } }

  if sandbox.env then
    for k, v in pairs(sandbox.env) do
      if not inspector_builtin_globals[k] then
        -- Apply hideFunctions filter
        if state.inspector.hideFunctions and type(v) == "function" then
          -- Skip functions
        else
          local origin = sandbox.globalOrigins and sandbox.globalOrigins[k] or "main"
          local item = { key = k, value = v, origin = origin }

          if is_global_pinned(k) then
            table.insert(pinned, item)
          elseif origin == "main" then
            table.insert(mainGlobals, item)
          else
            moduleGlobals[origin] = moduleGlobals[origin] or {}
            table.insert(moduleGlobals[origin], item)
          end
        end
      end
    end
  end

  -- Sort each group
  local function sortItems(items)
    table.sort(items, function(a, b) return tostring(a.key) < tostring(b.key) end)
  end
  sortItems(pinned)
  sortItems(mainGlobals)
  for _, items in pairs(moduleGlobals) do
    sortItems(items)
  end

  -- Section: Pinned (if any)
  if #pinned > 0 then
    if y + headerH > p.y + NAV_H then
      draw_section_header(contentX, y, "Pinned")
    end
    y = y + headerH + 8
    for _, item in ipairs(pinned) do
      local lines = draw_inspector_row(p, item, y, contentX, contentW, lineH, fontH)
      y = y + lines * lineH
    end
    y = y + 8
    draw_section_separator(p.x, y, p.w)
    y = y + 12
  end

  -- Section: Script Globals (main script only)
  if y + headerH > p.y + NAV_H then
    draw_section_header(contentX, y, "Script Globals")
  end
  y = y + headerH + 8

  if #mainGlobals == 0 and not next(moduleGlobals) and #pinned == 0 then
    love.graphics.setColor(ui.color.textDim)
    love.graphics.print("(no globals)", contentX + 8, y)
    y = y + lineH
  else
    for _, item in ipairs(mainGlobals) do
      local lines = draw_inspector_row(p, item, y, contentX, contentW, lineH, fontH)
      y = y + lines * lineH
    end
  end

  -- Section: Module globals (grouped by require path)
  if state.inspector.groupByOrigin and next(moduleGlobals) then
    local sortedModules = {}
    for modname in pairs(moduleGlobals) do
      table.insert(sortedModules, modname)
    end
    table.sort(sortedModules)

    for _, modname in ipairs(sortedModules) do
      local items = moduleGlobals[modname]
      if #items > 0 then
        y = y + 8
        draw_section_separator(p.x, y, p.w)
        y = y + 12
        if y + headerH > p.y + NAV_H then
          draw_section_header(contentX, y, "require('" .. modname .. "')")
        end
        y = y + headerH + 8
        for _, item in ipairs(items) do
          local lines = draw_inspector_row(p, item, y, contentX, contentW, lineH, fontH)
          y = y + lines * lineH
        end
      end
    end
  end

  -- Section: Simulator (if present)
  if sandbox.sim then
    y = y + 12
    draw_section_separator(p.x, y, p.w)
    y = y + 12

    if y + headerH > p.y + NAV_H then
      draw_section_header(contentX, y, "Simulator")
    end
    y = y + headerH + 8

    -- Show simulator config if available
    if sandbox.sim.cfg then
      local _, lines = draw_tree_node(p, "sim.cfg", "cfg", sandbox.sim.cfg, 0, y, contentX, contentW)
      y = y + lines * lineH
    end

    -- Show simulator hooks info
    if sandbox.sim.hooks then
      local hooks = {}
      for hookName, fn in pairs(sandbox.sim.hooks) do
        if type(fn) == "function" then
          table.insert(hooks, hookName)
        end
      end
      if #hooks > 0 then
        table.sort(hooks)
        love.graphics.setColor(ui.color.textDim)
        love.graphics.print("hooks: " .. table.concat(hooks, ", "), contentX + 8, y)
        y = y + lineH
      end
    end
  end

  -- Store total content height for scroll bounds
  ui._inspectorContentHeight = y - (p.y + NAV_H + 8 - (state.inspector.scrollOffset * lineH))
end

function ui.layout(w, h)
  ui.panels.toolbar = { x = 12, y = 12, w = w - 24, h = 28 }

  -- Bottom section: log at bottom (hide if minimized)
  local logH_full = math.min(200, math.floor(h * 0.25))
  local logH = ui.minimized.log and COLLAPSE_H or logH_full
  ui.panels.log = { x = 12, y = h - (logH + 12), w = w - 24, h = logH }

  -- Middle row: inputs (left), game (center), outputs (right)
  local midTop = ui.panels.toolbar.y + ui.panels.toolbar.h + 10
  local midBottom = ui.panels.log.y - 10
  local midH = midBottom - midTop

  local leftW = ui.minimized.inputs and COLLAPSE_W or 320
  local rightW = ui.mergedOutputs and 0 or (ui.minimized.outputs and COLLAPSE_W or 320)
  local gameWpx = state.tilesX * state.tileSize * state.gameCanvasScale
  local gameHpx = state.tilesY * state.tileSize * state.gameCanvasScale
  local dbgWpx = state.userDebugCanvasEnabled and (state.debugCanvasW * state.debugCanvasScale) or 0
  local dbgHpx = state.userDebugCanvasEnabled and (state.debugCanvasH * state.debugCanvasScale) or 0
  local centerW = math.max(gameWpx + 16, dbgWpx + 16, 200)
  local availableCenterW = math.max(200, w - 24 - leftW - rightW - 20)

  -- Merge outputs into inputs when width is too small
  ui.mergedOutputs = false
  if availableCenterW < 260 or w < 980 then
    -- Not enough room for three columns; collapse to two columns (Inputs + Game)
    ui.mergedOutputs = true
    rightW = 0
    availableCenterW = math.max(200, w - 24 - leftW - 10)
  end

  centerW = math.min(centerW, availableCenterW)

  ui.panels.io_inputs = { x = 12, y = midTop, w = leftW, h = midH }
  -- Center stacking: Game first if not minimized; Debug below if enabled and not minimized
  local centerX = ui.panels.io_inputs.x + leftW + (leftW > 0 and 10 or 0)
  local nextY = midTop
  local gameH = ui.minimized.game and COLLAPSE_H or math.min(midH, gameHpx + 16 + NAV_H)
  local debugH = state.userDebugCanvasEnabled and (ui.minimized.debug and COLLAPSE_H or (dbgHpx + 16 + NAV_H)) or 0
  ui.panels.game = { x = centerX, y = nextY, w = centerW, h = gameH }
  nextY = nextY + (gameH > 0 and (gameH + (debugH > 0 and 10 or 0)) or 0)
  ui.panels.debug_center = { x = centerX, y = nextY, w = centerW, h = debugH }
  if ui.mergedOutputs then
    -- Outputs handled inside left panel via tabs; skip right panel sizing
    ui.panels.io_outputs = { x = ui.panels.io_inputs.x, y = ui.panels.io_inputs.y, w = leftW, h = midH }
  else
    -- Always align outputs to right edge (both expanded and minimized)
    local outputsX = w - 12 - rightW
    ui.panels.io_outputs = { x = outputsX, y = midTop, w = rightW, h = midH }
  end

  -- Debug logging
  if state.debugOverlayEnabled then
    print(string.format(
      "[UI Layout] Window: %dx%d | Game: %dx%d @ %.1fx | Debug: %s | Minimized: I=%s G=%s O=%s D=%s L=%s",
      w, h,
      state.gameCanvasW or 0, state.gameCanvasH or 0, state.gameCanvasScale or 1,
      state.userDebugCanvasEnabled and "ON" or "OFF",
      ui.minimized.inputs and "Y" or "N",
      ui.minimized.game and "Y" or "N",
      ui.minimized.outputs and "Y" or "N",
      ui.minimized.debug and "Y" or "N",
      ui.minimized.log and "Y" or "N"
    ))
  end
end

function ui.draw_toolbar()
  local p = ui.panels.toolbar
  draw_panel(p)
  ui._toolbarRects = {}
  ui._navRects = {} -- reset nav/hit regions each frame to avoid stale overlaps
  ui._hoverTip = nil
  local x = p.x + 8
  local y = p.y + math.floor((p.h - 22) / 2)

  -- Play/Pause
  x = x
    + draw_toolbar_icon_button(x, y, {
      name = state.running and "pause" or "play",
      active = state.running,
      action = "toggle_run",
      tooltip = state.running and "Pause [Space]" or "Play [Space]",
    })
    + 6

  -- Step
  x = x
    + draw_toolbar_icon_button(x, y, {
      name = "step",
      active = false,
      action = "step",
      tooltip = "Step [N]",
    })
    + 6

  -- Reload
  x = x
    + draw_toolbar_icon_button(x, y, {
      name = "refresh",
      active = false,
      action = "reload",
      tooltip = "Reload [R]",
    })
    + 12

  -- Debug toggle
  x = x
    + draw_toolbar_icon_button(x, y, {
      name = "bug",
      active = state.userDebugCanvasEnabled,
      action = "toggle_debug",
      tooltip = (state.userDebugCanvasEnabled and "Disable Debug Canvas [D]" or "Enable Debug Canvas [D]"),
    })
    + 16

  -- Scale controls
  love.graphics.setColor(ui.color.text)
  love.graphics.print(string.format("Scale: %dx", state.gameCanvasScale), x, p.y + 6)
  x = x + 90
  x = x
    + draw_toolbar_icon_button(x, y, {
      name = "remove",
      active = false,
      action = "scale_minus",
      tooltip = "Scale - [-]",
    })
    + 6
  x = x
    + draw_toolbar_icon_button(x, y, {
      name = "add",
      active = false,
      action = "scale_plus",
      tooltip = "Scale + [+]",
    })
    + 16

  -- Static info (tiles, tick)
  love.graphics.setColor(ui.color.text)
  love.graphics.print(string.format("Tiles: %dx%d", state.tilesX, state.tilesY), x, p.y + 6)
  x = x + 120
  love.graphics.print(string.format("Tick: %d", state.tickRate), x, p.y + 6)
  x = x + 80
  
  -- Error counter display
  if state.errorCount > 0 and state.errorSignature then
    local errColor = state.errorCount >= state.maxErrorRepeats and ui.color.warn or { 1, 0.8, 0.3, 1 }
    love.graphics.setColor(errColor)
    love.graphics.print(string.format("Error: %d/%d", state.errorCount, state.maxErrorRepeats), x, p.y + 6)
    x = x + 100
  end
  
  -- Tick rate controls (adjust onTick rate; onDraw remains tied to frame rate)
  x = x
    + draw_toolbar_icon_button(x, y, {
      name = "remove",
      active = false,
      action = "tick_minus",
      tooltip = "Slow down tick (halve) [ [ ]",
    })
    + 6
  x = x
    + draw_toolbar_icon_button(x, y, {
      name = "add",
      active = false,
      action = "tick_plus",
      tooltip = "Speed up tick (double) [ ] ]",
    })
    + 16

  -- Export button
  x = x
    + draw_toolbar_icon_button(x, y, {
      name = "download",
      active = state.export.showModal,
      action = "toggle_export_modal",
      tooltip = "Export Canvas [E]",
    })
end

-- Inputs panel: with optional tabbed merge for Outputs
function ui.draw_inputs()
  local p = ui.panels.io_inputs
  if ui.minimized.inputs then
    draw_collapsed_vertical(p, "inputs", "Inputs")
    return
  end
  draw_panel(p)
  if ui.mergedOutputs then
    draw_nav_bar(p, "", "left")
  else
    draw_nav_bar(p, "Inputs", "inputs")
  end
  panel_content_scissor(p)

  if ui.mergedOutputs and ui.leftTab == "outputs" then
    draw_outputs_content(p)
  elseif ui.mergedOutputs and ui.leftTab == "inspector" then
    draw_inspector_content(p)
  else
    draw_inputs_content(p)
  end

  love.graphics.setScissor()
end

-- Outputs panel: hidden when merged (content shown inside left panel via tab)
function ui.draw_outputs()
  if ui.mergedOutputs then
    return
  end
  local p = ui.panels.io_outputs
  if ui.minimized.outputs then
    draw_collapsed_vertical(p, "outputs", "Outputs")
    return
  end
  draw_panel(p)
  draw_nav_bar(p, "Outputs", "outputs")
  panel_content_scissor(p)
  if ui.rightTab == "inspector" then
    draw_inspector_content(p)
  else
    draw_outputs_content(p)
  end
  love.graphics.setScissor()
end

function ui.draw_game_canvas()
  local p = ui.panels.game
  if ui.minimized.game then
    draw_collapsed_horizontal(p, "game", "Game")
    ui._canvasRects.game = nil
    return { x = p.x + 8, y = p.y + NAV_H + 8 }
  end
  draw_panel(p)
  draw_nav_bar(p, "Game", "game")
  -- inner rect where canvas is drawn
  local cx = p.x + 8
  local cy = p.y + NAV_H + 8
  -- cache rect for hit testing
  local gw = state.tilesX * state.tileSize
  local gh = state.tilesY * state.tileSize
  ui._canvasRects.game = {
    x = cx,
    y = cy,
    w = gw * state.gameCanvasScale,
    h = gh * state.gameCanvasScale,
    scale = state.gameCanvasScale,
  }
  return { x = cx, y = cy }
end

function ui.draw_debug_canvas_center()
  local p = ui.panels.debug_center
  if p.h <= 0 then
    ui._canvasRects.debug = nil
    return { x = p.x + 8, y = p.y + NAV_H + 8 }
  end
  if ui.minimized.debug then
    draw_collapsed_horizontal(p, "debug", "Debug")
    ui._canvasRects.debug = nil
    return { x = p.x + 8, y = p.y + NAV_H + 8 }
  end
  draw_panel(p)
  draw_nav_bar(p, "Debug", "debug")
  local cx = p.x + 8
  local cy = p.y + NAV_H + 8
  -- cache rect for hit testing
  if state.userDebugCanvasEnabled then
    ui._canvasRects.debug = {
      x = cx,
      y = cy,
      w = state.debugCanvasW * state.debugCanvasScale,
      h = state.debugCanvasH * state.debugCanvasScale,
      scale = state.debugCanvasScale,
    }
  else
    ui._canvasRects.debug = nil
  end
  return { x = cx, y = cy }
end

-- Helper function for log color coding
local scriptColors = {}
local function hashString(s)
  local h = 0
  for i = 1, #s do h = h + s:byte(i) end
  return h
end

local function hslToRgb(h, s, l)
  local function hue2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1/6 then return p + (q - p) * 6 * t end
    if t < 1/2 then return q end
    if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
    return p
  end
  local q = l < 0.5 and l * (1 + s) or l + s - l * s
  local p = 2 * l - q
  return hue2rgb(p, q, h + 1/3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1/3), 1
end

local function getLogColor(source)
  if source == "system" then
    return {0.5, 0.5, 0.5, 1}
  elseif source == "main" then
    return ui.color.ok
  else
    if not scriptColors[source] then
      math.randomseed(hashString(source))
      local h = math.random()
      scriptColors[source] = {hslToRgb(h, 0.7, 0.6)}
    end
    return scriptColors[source]
  end
end

function ui.draw_log(logger)
  local p = ui.panels.log
  if ui.minimized.log then
    draw_collapsed_horizontal(p, "log", "Log")
  else
    draw_panel(p)

    -- Enhanced nav bar with controls
    local font = love.graphics.getFont()
    local fontH = font and font:getHeight() or 14
    local mx, my = love.mouse.getPosition()

    -- Draw base nav bar
    love.graphics.setColor(ui.color.panelAlt)
    love.graphics.rectangle("fill", p.x, p.y, p.w, NAV_H, 4, 4)

    -- Title
    love.graphics.setColor(ui.color.text)
    love.graphics.print("Log", p.x + 8, p.y + 4)

    -- Buttons from right to left
    local btnSize = 18
    local btnY = p.y + math.floor((NAV_H - btnSize) / 2)
    local btnX = p.x + p.w - btnSize - 6

    -- Minimize button
    local minHover = (mx >= btnX and my >= btnY and mx < btnX + btnSize and my < btnY + btnSize)
    love.graphics.setColor(minHover and {0.35,0.35,0.4,1} or {0.22,0.22,0.26,1})
    love.graphics.rectangle("fill", btnX, btnY, btnSize, btnSize, 4, 4)
    love.graphics.setColor(ui.color.text)
    love.graphics.print("-", btnX + 6, btnY + 1)
    ui._navRects["log_min"] = {x=btnX, y=btnY, w=btnSize, h=btnSize, action="toggle_min", which="log"}
    btnX = btnX - btnSize - 4

    -- Auto-scroll toggle button
    local scrollIcon = state.logUI.autoScroll and "↓" or "||"
    local scrollHover = (mx >= btnX and my >= btnY and mx < btnX + btnSize and my < btnY + btnSize)
    love.graphics.setColor(scrollHover and ui.color.accentHover or (state.logUI.autoScroll and ui.color.accent or {0.22,0.22,0.26,1}))
    love.graphics.rectangle("fill", btnX, btnY, btnSize, btnSize, 4, 4)
    love.graphics.setColor(ui.color.text)
    love.graphics.print(scrollIcon, btnX + 4, btnY + 1)
    ui._navRects["log_autoscroll"] = {x=btnX, y=btnY, w=btnSize, h=btnSize, action="toggle_autoscroll", tooltip="Toggle auto-scroll"}
    if scrollHover then set_tooltip("Toggle auto-scroll to bottom") end
    btnX = btnX - btnSize - 4

    -- Clear button
    local clearHover = (mx >= btnX and my >= btnY and mx < btnX + btnSize and my < btnY + btnSize)
    love.graphics.setColor(clearHover and {0.4,0.2,0.2,1} or {0.22,0.22,0.26,1})
    love.graphics.rectangle("fill", btnX, btnY, btnSize, btnSize, 4, 4)
    love.graphics.setColor(ui.color.text)
    love.graphics.setLineWidth(2)
    love.graphics.line(btnX + 4, btnY + 4, btnX + btnSize - 4, btnY + btnSize - 4)
    love.graphics.line(btnX + btnSize - 4, btnY + 4, btnX + 4, btnY + btnSize - 4)
    ui._navRects["log_clear"] = {x=btnX, y=btnY, w=btnSize, h=btnSize, action="clear_log", tooltip="Clear log"}
    if clearHover then set_tooltip("Clear all logs") end
    btnX = btnX - btnSize - 8

    -- Search box
    local searchW = 150
    local searchH = 18
    local searchX = btnX - searchW
    local searchY = p.y + math.floor((NAV_H - searchH) / 2)
    local searchActive = state.logUI.searchActive
    love.graphics.setColor(searchActive and {0.22,0.22,0.26,1} or {0.16,0.16,0.18,1})
    love.graphics.rectangle("fill", searchX, searchY, searchW, searchH, 2, 2)
    local displayText = (#state.logUI.searchText > 0) and state.logUI.searchText or "Search..."
    love.graphics.setColor((#state.logUI.searchText > 0) and ui.color.text or {0.5,0.5,0.5,1})
    love.graphics.print(displayText, searchX + 6, searchY + 2)
    ui._navRects["log_search"] = {x=searchX, y=searchY, w=searchW, h=searchH, action="activate_search"}
    btnX = searchX - 8

    -- Toggle system logs button
    local sysW = 80
    local sysX = p.x + 60
    local sysCollapsed = state.logUI.collapsedSources.system or false
    local sysLabel = sysCollapsed and "Show Sys" or "Hide Sys"
    local sysHover = (mx >= sysX and my >= btnY and mx < sysX + sysW and my < btnY + btnSize)
    love.graphics.setColor(sysHover and ui.color.panelAlt or {0.18,0.18,0.20,1})
    love.graphics.rectangle("fill", sysX, btnY, sysW, btnSize, 4, 4)
    love.graphics.setColor(ui.color.textDim)
    love.graphics.print(sysLabel, sysX + 8, btnY + 2)
    ui._navRects["toggle_system_logs"] = {x=sysX, y=btnY, w=sysW, h=btnSize, action="toggle_system_logs"}

    -- Draw log content with scrolling
    local lines = logger.getLines(1000)
    local visibleH = p.h - NAV_H - 8
    local visibleLines = math.floor(visibleH / fontH)
    local totalLines = #lines

    -- Filter lines
    local filteredLines = {}
    local pattern = state.logUI.searchText:lower()
    for i = 1, totalLines do
      local entry = lines[i]
      if type(entry) == "table" then
        -- Skip collapsed sources
        if state.logUI.collapsedSources[entry.source] then
          goto continue
        end
        -- Apply search filter
        if #pattern > 0 then
          if not entry.text:lower():find(pattern, 1, true) then
            goto continue
          end
        end
        table.insert(filteredLines, entry)
      end
      ::continue::
    end

    local filteredCount = #filteredLines

    -- Calculate visible range
    local startIdx, endIdx
    if state.logUI.autoScroll then
      startIdx = math.max(1, filteredCount - visibleLines + 1)
      endIdx = filteredCount
    else
      local bottomLine = filteredCount - state.logUI.scrollOffset
      startIdx = math.max(1, bottomLine - visibleLines + 1)
      endIdx = math.min(filteredCount, bottomLine)
    end

    -- Render logs
    love.graphics.setScissor(p.x, p.y + NAV_H, p.w - 12, p.h - NAV_H)
    local y = p.y + NAV_H + 4
    for i = startIdx, endIdx do
      local entry = filteredLines[i]
      if type(entry) == "table" then
        local color = getLogColor(entry.source)
        love.graphics.setColor(color)
        love.graphics.print(entry.text, p.x + 8, y)
        y = y + fontH
      end
    end
    love.graphics.setScissor()

    -- Draw scrollbar if needed
    if filteredCount > visibleLines then
      local scrollBarX = p.x + p.w - 10
      local scrollBarY = p.y + NAV_H + 4
      local scrollBarH = p.h - NAV_H - 8
      local thumbH = math.max(20, scrollBarH * (visibleLines / filteredCount))
      local scrollRange = filteredCount - visibleLines
      local thumbY = scrollBarY + (scrollBarH - thumbH) * (1 - state.logUI.scrollOffset / scrollRange)

      -- Track
      love.graphics.setColor(0.15, 0.15, 0.15, 0.8)
      love.graphics.rectangle("fill", scrollBarX, scrollBarY, 6, scrollBarH, 3, 3)
      -- Thumb
      love.graphics.setColor(ui.color.accent)
      love.graphics.rectangle("fill", scrollBarX, thumbY, 6, thumbH, 3, 3)
    end
  end

  -- Draw tooltip overlay if any
  if ui._hoverTip and ui._hoverTip.text then
    local padx, pady = 8, 6
    local text = ui._hoverTip.text
    local font = love.graphics.getFont()

    -- Split text by newlines and measure properly
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
      table.insert(lines, line)
    end

    local tw = 0
    for _, line in ipairs(lines) do
      local lw = font:getWidth(line)
      if lw > tw then tw = lw end
    end

    local lineHeight = font:getHeight()
    local th = lineHeight * #lines

    local x = ui._hoverTip.x
    local y = ui._hoverTip.y
    -- keep on screen
    local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
    if x + tw + padx * 2 > ww - 8 then
      x = ww - (tw + padx * 2) - 8
    end
    if y + th + pady * 2 > wh - 8 then
      y = wh - (th + pady * 2) - 8
    end

    -- Background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, tw + padx * 2, th + pady * 2, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, tw + padx * 2 - 1, th + pady * 2 - 1, 4, 4)

    -- Print each line
    love.graphics.setColor(1, 1, 1, 1)
    for i, line in ipairs(lines) do
      love.graphics.print(line, x + padx, y + pady + (i - 1) * lineHeight)
    end
  end
end

function ui.mousepressed(mx, my, button)
  -- Update canvas touch state for game/debug on any mouse button
  local function update_touch(which)
    local rect = ui._canvasRects and ui._canvasRects[which]
    local t = state.touch and state.touch[which]
    if not t then return end
    if rect then
      local inside = (mx >= rect.x and my >= rect.y and mx < rect.x + rect.w and my < rect.y + rect.h)
      t.inside = inside
      local scale = rect.scale or 1
      local lx = math.floor((mx - rect.x) / scale)
      local ly = math.floor((my - rect.y) / scale)
      if lx < 0 then lx = 0 end; if ly < 0 then ly = 0 end
      local maxx = math.max(0, math.floor(rect.w / scale) - 1)
      local maxy = math.max(0, math.floor(rect.h / scale) - 1)
      t.x = math.min(maxx, lx)
      t.y = math.min(maxy, ly)
      if button == 1 then t.left = inside and true or false end
      if button == 2 then t.right = inside and true or false end
    else
      t.inside = false
    end
  end
  update_touch('game')
  if state.userDebugCanvasEnabled then update_touch('debug') end

  if button ~= 1 then
    return
  end

  -- Export modal buttons (handle first to prevent clicking through)
  if state.export.showModal and ui._modalRects then
    for _, r in ipairs(ui._modalRects) do
      if r and (mx >= r.x and my >= r.y and mx <= r.x + r.w and my <= r.y + r.h) then
        if r.action == "export_format_png" then
          state.export.format = "png"
          return
        elseif r.action == "export_format_jpg" then
          state.export.format = "jpg"
          return
        elseif r.action == "export_canvas_game" then
          state.export.capture = "game"
          return
        elseif r.action == "export_canvas_debug" then
          state.export.capture = "debug"
          return
        elseif r.action == "export_canvas_both" then
          state.export.capture = "both"
          return
        elseif r.action == "perform_export" then
          -- Set flag for main.lua to handle
          state.export.doExport = true
          return
        elseif r.action == "cancel_export" then
          state.export.showModal = false
          return
        end
      end
    end
    -- If modal is open and we clicked outside the modal, close it
    local modal_w, modal_h = love.graphics.getWidth(), love.graphics.getHeight()
    local modalW, modalH = 300, 250
    local mx_pos = math.floor((modal_w - modalW) / 2)
    local my_pos = math.floor((modal_h - modalH) / 2)
    if not (mx >= mx_pos and my >= my_pos and mx < mx_pos + modalW and my < my_pos + modalH) then
      state.export.showModal = false
    end
    return
  end

  -- Toolbar buttons
  if ui._toolbarRects then
    for _, r in ipairs(ui._toolbarRects) do
      if r and (mx >= r.x and my >= r.y and mx <= r.x + r.w and my <= r.y + r.h) then
        if r.action == "toggle_run" then
          state.running = not state.running
          return
        elseif r.action == "step" then
          state.singleStep = true
          return
        elseif r.action == "reload" then
          sandbox.reload()
          return
        elseif r.action == "toggle_debug" then
          state.userDebugCanvasEnabled = not state.userDebugCanvasEnabled
          canvases.recreateAll()
          return
        elseif r.action == "scale_minus" then
          state.gameCanvasScale = math.max(1, state.gameCanvasScale - 1)
          return
        elseif r.action == "scale_plus" then
          state.gameCanvasScale = math.min(8, state.gameCanvasScale + 1)
          return
        elseif r.action == "tick_minus" then
          local factor = (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and 10 or 20
          state.tickRate = math.max(10, math.floor(state.tickRate - factor))
          return
        elseif r.action == "tick_plus" then
          local factor = (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and 10 or 20
          state.tickRate = math.min(480, math.floor(state.tickRate + factor))
          return
        elseif r.action == "toggle_export_modal" then
          state.export.showModal = not state.export.showModal
          return
        end
      end
    end
  end
  -- Nav bars (detach buttons / tabs)
  if ui._navRects then
    for _, r in pairs(ui._navRects) do
      if r and (mx >= r.x and my >= r.y and mx <= r.x + r.w and my <= r.y + r.h) then
        if r.action == "toggle_detach" and r.which then
          local detach_mod = require("lib.detach")
          detach_mod.toggle(r.which)
          return
        elseif r.action == "toggle_min" and r.which then
          ui.minimized[r.which] = not ui.minimized[r.which]
          return
        elseif r.action == "left_tab" and r.tab then
          ui.leftTab = r.tab
          return
        elseif r.action == "right_tab" and r.tab then
          ui.rightTab = r.tab
          return
        elseif r.action == "io_tab" and r.which and r.tab then
          if r.which == "input" then
            state.ioTabs.activeInputTab = r.tab
          else
            state.ioTabs.activeOutputTab = r.tab
          end
          return
        elseif r.action == "toggle_autoscroll" then
          state.logUI.autoScroll = not state.logUI.autoScroll
          if state.logUI.autoScroll then
            state.logUI.scrollOffset = 0
          end
          return
        elseif r.action == "clear_log" then
          local logger = require("lib.logger")
          logger.lines = {}
          state.logUI.scrollOffset = 0
          state.logUI.autoScroll = true
          return
        elseif r.action == "activate_search" then
          state.logUI.searchActive = not state.logUI.searchActive
          if not state.logUI.searchActive then
            state.logUI.searchText = ""
          end
          return
        elseif r.action == "toggle_system_logs" then
          state.logUI.collapsedSources.system = not (state.logUI.collapsedSources.system or false)
          return
        elseif r.action == "toggle_hide_functions" then
          state.inspector.hideFunctions = not state.inspector.hideFunctions
          return
        end
      end
    end
  end
  -- Inspector value double-click to edit
  if ui._inspectorValueRects then
    for path, r in pairs(ui._inspectorValueRects) do
      if r and (mx >= r.x and my >= r.y and mx <= r.x + r.w and my <= r.y + r.h) then
        local now = love.timer.getTime()
        local isDoubleClick = (now - ui._inspectorEdit.lastClickTime < 0.3 and ui._inspectorEdit.lastClickPath == path)
        ui._inspectorEdit.lastClickTime = now
        ui._inspectorEdit.lastClickPath = path

        if isDoubleClick then
          -- Extract global key from path (script.myVar -> myVar)
          local globalKey = path:match("^script%.([^%.]+)$")
          if globalKey and sandbox.env and sandbox.env[globalKey] then
            local value = sandbox.env[globalKey]
            local valueType = type(value)
            -- Initialize edit mode
            ui._inspectorEdit.active = true
            ui._inspectorEdit.path = path
            ui._inspectorEdit.globalKey = globalKey
            ui._inspectorEdit.valueType = valueType
            if valueType == "string" then
              ui._inspectorEdit.text = value
            elseif valueType == "number" then
              ui._inspectorEdit.text = tostring(value)
            elseif valueType == "boolean" then
              ui._inspectorEdit.text = tostring(value)
            end
          end
          return
        end
      end
    end
  end
  -- Inspector tree node expand/collapse
  if ui._inspectorRects then
    for path, r in pairs(ui._inspectorRects) do
      if r and (mx >= r.x and my >= r.y and mx <= r.x + r.w and my <= r.y + r.h) then
        if r.action == "toggle_expand" and r.path then
          state.inspector.expanded[r.path] = not state.inspector.expanded[r.path]
          return
        end
      end
    end
  end
  -- Inspector pin toggle
  if ui._inspectorPinRects then
    for globalName, r in pairs(ui._inspectorPinRects) do
      if r and (mx >= r.x and my >= r.y and mx <= r.x + r.w and my <= r.y + r.h) then
        -- Toggle pin state
        if r.isPinned then
          -- Remove from pinned
          local newPinned = {}
          for _, p in ipairs(state.inspector.pinnedGlobals or {}) do
            if p ~= globalName then
              table.insert(newPinned, p)
            end
          end
          state.inspector.pinnedGlobals = newPinned
        else
          -- Add to pinned
          state.inspector.pinnedGlobals = state.inspector.pinnedGlobals or {}
          table.insert(state.inspector.pinnedGlobals, globalName)
        end
        ui._inspectorPinsChanged = true
        return
      end
    end
  end
  -- Bool toggles (inputs only)
  for i, rect in ipairs(ui._boolRects) do
    if rect and (mx >= rect.x and my >= rect.y and mx <= rect.x + rect.w and my <= rect.y + rect.h) then
      -- Ignore if simulator-driven
      if not state.simulatorDriven.inputB[i] then
        state.inputB[i] = not state.inputB[i]
      end
      return
    end
  end
  -- Number sliders (inputs only)
  for i, rect in ipairs(ui._numRects) do
    if rect and (mx >= rect.x and my >= rect.y and mx <= rect.x + rect.w and my <= rect.y + rect.h) then
      -- Ignore if simulator-driven
      if not state.simulatorDriven.inputN[i] then
        ui._activeSlider = { idx = i, rect = rect }
        local v = (mx - rect.x) / rect.w
        state.inputN[i] = math.max(0, math.min(1, v))
      end
      return
    end
  end
end

function ui.mousereleased(mx, my, button)
  -- Update touch release for canvas areas
  local function update_release(which)
    local rect = ui._canvasRects and ui._canvasRects[which]
    local t = state.touch and state.touch[which]
    if not t then return end
    if rect then
      local inside = (mx >= rect.x and my >= rect.y and mx < rect.x + rect.w and my < rect.y + rect.h)
      t.inside = inside
      local scale = rect.scale or 1
      local lx = math.floor((mx - rect.x) / scale)
      local ly = math.floor((my - rect.y) / scale)
      if lx < 0 then lx = 0 end; if ly < 0 then ly = 0 end
      local maxx = math.max(0, math.floor(rect.w / scale) - 1)
      local maxy = math.max(0, math.floor(rect.h / scale) - 1)
      t.x = math.min(maxx, lx)
      t.y = math.min(maxy, ly)
    else
      t.inside = false
    end
    if button == 1 then t.left = false end
    if button == 2 then t.right = false end
  end
  update_release('game')
  if state.userDebugCanvasEnabled then update_release('debug') end

  if button == 1 then
    ui._activeSlider = nil
  end
end

function ui.mousemoved(mx, my, dx, dy)
  -- Track pointer movement over canvases
  local function update_move(which)
    local rect = ui._canvasRects and ui._canvasRects[which]
    local t = state.touch and state.touch[which]
    if not t then return end
    if rect then
      local inside = (mx >= rect.x and my >= rect.y and mx < rect.x + rect.w and my < rect.y + rect.h)
      t.inside = inside
      local scale = rect.scale or 1
      local lx = math.floor((mx - rect.x) / scale)
      local ly = math.floor((my - rect.y) / scale)
      if lx < 0 then lx = 0 end; if ly < 0 then ly = 0 end
      local maxx = math.max(0, math.floor(rect.w / scale) - 1)
      local maxy = math.max(0, math.floor(rect.h / scale) - 1)
      t.x = math.min(maxx, lx)
      t.y = math.min(maxy, ly)
      -- reflect current button held state only when inside rect
      t.left = inside and love.mouse.isDown(1) or false
      t.right = inside and love.mouse.isDown(2) or false
    else
      t.inside = false
      t.left = false
      t.right = false
    end
  end
  update_move('game')
  if state.userDebugCanvasEnabled then update_move('debug') end

  if ui._activeSlider then
    local i = ui._activeSlider.idx
    local rect = ui._activeSlider.rect
    local v = (mx - rect.x) / rect.w
    state.inputN[i] = math.max(0, math.min(1, v))
  end
  -- Update tooltip position during hover
  if ui._hoverTip then
    ui._hoverTip.x = mx + 14
    ui._hoverTip.y = my + 18
  end
end

function ui.wheelmoved(dx, dy)
  if dy == 0 then
    return
  end
  local mx, my = love.mouse.getPosition()

  -- Check if scrolling over log panel
  local p = ui.panels.log
  if not ui.minimized.log and mx >= p.x and my >= p.y and mx < p.x + p.w and my < p.y + p.h then
    -- Scrolling up disables auto-scroll
    if state.logUI.autoScroll and dy < 0 then
      state.logUI.autoScroll = false
      state.logUI.scrollOffset = 0
    end

    if not state.logUI.autoScroll then
      state.logUI.scrollOffset = math.max(0, state.logUI.scrollOffset - dy)
      -- Clamp to max scroll
      local logger = require("lib.logger")
      local lines = logger.getLines(1000)
      local font = love.graphics.getFont()
      local fontH = font and font:getHeight() or 14
      local visibleH = p.h - NAV_H - 8
      local visibleLines = math.floor(visibleH / fontH)
      local maxScroll = math.max(0, #lines - visibleLines)
      state.logUI.scrollOffset = math.min(maxScroll, state.logUI.scrollOffset)
    end
    return
  end

  -- Check if scrolling over inspector panel (merged mode: left panel with inspector tab, non-merged: right panel with inspector tab)
  local inspectorPanel = nil
  if ui.mergedOutputs and ui.leftTab == "inspector" then
    inspectorPanel = ui.panels.io_inputs
  elseif not ui.mergedOutputs and ui.rightTab == "inspector" then
    inspectorPanel = ui.panels.io_outputs
  end
  if inspectorPanel and not ui.minimized.inputs and not ui.minimized.outputs then
    local ip = inspectorPanel
    if mx >= ip.x and my >= ip.y and mx < ip.x + ip.w and my < ip.y + ip.h then
      -- Scroll inspector content
      state.inspector.scrollOffset = state.inspector.scrollOffset - dy
      -- Clamp to valid range
      local font = love.graphics.getFont()
      local fontH = font and font:getHeight() or 14
      local lineH = fontH + 4
      local visibleH = ip.h - NAV_H
      local visibleLines = math.floor(visibleH / lineH)
      local maxLines = math.max(0, math.floor((ui._inspectorContentHeight or 0) / lineH) - visibleLines + 2)
      state.inspector.scrollOffset = math.max(0, math.min(maxLines, state.inspector.scrollOffset))
      return
    end
  end

  -- Number slider scrolling
  for i, rect in ipairs(ui._numRects) do
    if rect and (mx >= rect.x and my >= rect.y and mx <= rect.x + rect.w and my <= rect.y + rect.h) then
      -- Ignore if simulator-driven
      if not state.simulatorDriven.inputN[i] then
        local step = 0.02 * dy
        state.inputN[i] = math.max(0, math.min(1, (state.inputN[i] or 0) + step))
      end
      return
    end
  end
end

-- Export modal dialog
function ui.draw_export_modal()
  if not state.export.showModal then
    return
  end

  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local modalW, modalH = 300, 250
  local mx_pos = math.floor((w - modalW) / 2)
  local my_pos = math.floor((h - modalH) / 2)
  local mx, my = love.mouse.getPosition()

  -- Dim background
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", 0, 0, w, h)

  -- Modal panel
  love.graphics.setColor(ui.color.panel)
  love.graphics.rectangle("fill", mx_pos, my_pos, modalW, modalH, 8, 8)
  love.graphics.setColor(1, 1, 1, 0.1)
  love.graphics.rectangle("line", mx_pos + 0.5, my_pos + 0.5, modalW - 1, modalH - 1, 8, 8)

  -- Title
  love.graphics.setColor(ui.color.text)
  love.graphics.print("Export Canvas", mx_pos + 16, my_pos + 12)

  -- Initialize modal rects if not already
  ui._modalRects = {}

  local y = my_pos + 45

  -- Format selection
  love.graphics.setColor(ui.color.text)
  love.graphics.print("Format:", mx_pos + 16, y)
  y = y + 25

  local fmt_x = mx_pos + 16
  local btn_w = 60
  local btn_h = 30
  local btn_gap = 10

  -- PNG button
  local png_hover = (mx >= fmt_x and my >= y and mx < fmt_x + btn_w and my < y + btn_h)
  local png_active = (state.export.format == "png")
  love.graphics.setColor(png_active and ui.color.accent or (png_hover and { 0.28, 0.28, 0.34, 1 } or { 0.22, 0.22, 0.26, 1 }))
  love.graphics.rectangle("fill", fmt_x, y, btn_w, btn_h, 4, 4)
  love.graphics.setColor(ui.color.text)
  love.graphics.print("PNG", fmt_x + 18, y + 8)
  table.insert(ui._modalRects, { x = fmt_x, y = y, w = btn_w, h = btn_h, action = "export_format_png" })

  -- JPG button
  local jpg_x = fmt_x + btn_w + btn_gap
  local jpg_hover = (mx >= jpg_x and my >= y and mx < jpg_x + btn_w and my < y + btn_h)
  local jpg_active = (state.export.format == "jpg")
  love.graphics.setColor(jpg_active and ui.color.accent or (jpg_hover and { 0.28, 0.28, 0.34, 1 } or { 0.22, 0.22, 0.26, 1 }))
  love.graphics.rectangle("fill", jpg_x, y, btn_w, btn_h, 4, 4)
  love.graphics.setColor(ui.color.text)
  love.graphics.print("JPG", jpg_x + 18, y + 8)
  table.insert(ui._modalRects, { x = jpg_x, y = y, w = btn_w, h = btn_h, action = "export_format_jpg" })

  y = y + btn_h + 20

  -- Canvas selection
  love.graphics.setColor(ui.color.text)
  love.graphics.print("Canvas:", mx_pos + 16, y)
  y = y + 25

  local canvas_x = mx_pos + 16
  local canvas_btn_w = 65

  -- Game button
  local game_hover = (mx >= canvas_x and my >= y and mx < canvas_x + canvas_btn_w and my < y + btn_h)
  local game_active = (state.export.capture == "game")
  love.graphics.setColor(game_active and ui.color.accent or (game_hover and { 0.28, 0.28, 0.34, 1 } or { 0.22, 0.22, 0.26, 1 }))
  love.graphics.rectangle("fill", canvas_x, y, canvas_btn_w, btn_h, 4, 4)
  love.graphics.setColor(ui.color.text)
  love.graphics.print("Game", canvas_x + 14, y + 8)
  table.insert(ui._modalRects, { x = canvas_x, y = y, w = canvas_btn_w, h = btn_h, action = "export_canvas_game" })

  -- Debug button
  local debug_x = canvas_x + canvas_btn_w + btn_gap
  local debug_disabled = not state.userDebugCanvasEnabled
  local debug_hover = (mx >= debug_x and my >= y and mx < debug_x + canvas_btn_w and my < y + btn_h)
  local debug_active = (state.export.capture == "debug")
  love.graphics.setColor(debug_disabled and { 0.15, 0.15, 0.15, 1 } or (debug_active and ui.color.accent or (debug_hover and { 0.28, 0.28, 0.34, 1 } or { 0.22, 0.22, 0.26, 1 })))
  love.graphics.rectangle("fill", debug_x, y, canvas_btn_w, btn_h, 4, 4)
  love.graphics.setColor(debug_disabled and { 0.4, 0.4, 0.4, 1 } or ui.color.text)
  love.graphics.print("Debug", debug_x + 10, y + 8)
  if not debug_disabled then
    table.insert(ui._modalRects, { x = debug_x, y = y, w = canvas_btn_w, h = btn_h, action = "export_canvas_debug" })
  end

  -- Both button
  local both_x = debug_x + canvas_btn_w + btn_gap
  local both_disabled = not state.userDebugCanvasEnabled
  local both_hover = (mx >= both_x and my >= y and mx < both_x + canvas_btn_w and my < y + btn_h)
  local both_active = (state.export.capture == "both")
  love.graphics.setColor(both_disabled and { 0.15, 0.15, 0.15, 1 } or (both_active and ui.color.accent or (both_hover and { 0.28, 0.28, 0.34, 1 } or { 0.22, 0.22, 0.26, 1 })))
  love.graphics.rectangle("fill", both_x, y, canvas_btn_w, btn_h, 4, 4)
  love.graphics.setColor(both_disabled and { 0.4, 0.4, 0.4, 1 } or ui.color.text)
  love.graphics.print("Both", both_x + 16, y + 8)
  if not both_disabled then
    table.insert(ui._modalRects, { x = both_x, y = y, w = canvas_btn_w, h = btn_h, action = "export_canvas_both" })
  end

  y = y + btn_h + 25

  -- Export and Cancel buttons
  local export_x = mx_pos + 16
  local export_w = 100
  local export_h = 35
  local export_hover = (mx >= export_x and my >= y and mx < export_x + export_w and my < y + export_h)
  love.graphics.setColor(export_hover and ui.color.ok or { 0.2, 0.6, 0.25, 1 })
  love.graphics.rectangle("fill", export_x, y, export_w, export_h, 4, 4)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print("Export", export_x + 26, y + 10)
  table.insert(ui._modalRects, { x = export_x, y = y, w = export_w, h = export_h, action = "perform_export" })

  local cancel_x = export_x + export_w + 10
  local cancel_hover = (mx >= cancel_x and my >= y and mx < cancel_x + export_w and my < y + export_h)
  love.graphics.setColor(cancel_hover and { 0.35, 0.35, 0.35, 1 } or { 0.25, 0.25, 0.25, 1 })
  love.graphics.rectangle("fill", cancel_x, y, export_w, export_h, 4, 4)
  love.graphics.setColor(ui.color.text)
  love.graphics.print("Cancel", cancel_x + 26, y + 10)
  table.insert(ui._modalRects, { x = cancel_x, y = y, w = export_w, h = export_h, action = "cancel_export" })
end

-- Export toast notification
function ui.draw_export_toast()
  if not state.export.lastPath or not state.export.lastTime then
    return
  end

  local elapsed = love.timer.getTime() - state.export.lastTime
  if elapsed > 3 then
    return
  end

  local alpha = math.min(1, (3 - elapsed) / 0.5) -- Fade out in last 0.5s
  local filename = state.export.lastPath:match("([^/\\]+)$") or state.export.lastPath
  local text = "Exported: " .. filename
  local font = love.graphics.getFont()
  local tw = font:getWidth(text)
  local w = love.graphics.getWidth()
  local x = math.floor((w - tw - 32) / 2)
  local y = 60

  love.graphics.setColor(0.2, 0.6, 0.3, 0.9 * alpha)
  love.graphics.rectangle("fill", x, y, tw + 32, 32, 6, 6)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.print(text, x + 16, y + 8)
end

---@brief Draw debug overlay showing panel boundaries and hit areas
function ui.draw_debug_overlay()
  if not state.debugOverlayEnabled then return end

  love.graphics.setLineWidth(1)

  -- 1. Draw panel boundaries
  for name, panel in pairs(ui.panels) do
    if panel.w > 0 and panel.h > 0 then
      love.graphics.setColor(1, 0, 0, 0.4)  -- Red with transparency
      love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h)

      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.print(
        string.format("%s: %d,%d %dx%d", name, panel.x, panel.y, panel.w, panel.h),
        panel.x + 4, panel.y + 4
      )
    end
  end

  -- 2. Draw canvas hit rectangles
  for which, rect in pairs(ui._canvasRects) do
    if rect then
      love.graphics.setColor(0, 1, 0, 0.4)  -- Green
      love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.print(
        string.format("%s canvas: scale=%.1fx", which, rect.scale),
        rect.x + 4, rect.y + rect.h - 20
      )
    end
  end

  -- 3. Draw boolean input hit areas
  for i, rect in pairs(ui._boolRects) do
    if rect then
      love.graphics.setColor(0, 0.5, 1, 0.3)  -- Blue
      love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
    end
  end

  -- 4. Draw number input hit areas (sliders)
  for i, rect in pairs(ui._numRects) do
    if rect then
      love.graphics.setColor(1, 1, 0, 0.3)  -- Yellow
      love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
    end
  end

  -- 5. Draw navigation bar hit areas
  for key, rect in pairs(ui._navRects) do
    if rect then
      love.graphics.setColor(1, 0, 1, 0.3)  -- Magenta
      love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
    end
  end

  -- 6. Draw toolbar button hit areas
  for key, rect in pairs(ui._toolbarRects) do
    if rect then
      love.graphics.setColor(0, 1, 1, 0.3)  -- Cyan
      love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
    end
  end

  -- 7. Draw legend in top-right corner
  local legendX = love.graphics.getWidth() - 220
  local legendY = 40
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", legendX - 4, legendY - 4, 216, 120)

  local function legendItem(text, color, y)
    love.graphics.setColor(color[1], color[2], color[3], 0.8)
    love.graphics.rectangle("fill", legendX, y, 16, 16)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(text, legendX + 20, y + 2)
  end

  legendItem("Panels", {1, 0, 0}, legendY)
  legendItem("Canvas rects", {0, 1, 0}, legendY + 18)
  legendItem("Bool inputs", {0, 0.5, 1}, legendY + 36)
  legendItem("Number inputs", {1, 1, 0}, legendY + 54)
  legendItem("Nav bars", {1, 0, 1}, legendY + 72)
  legendItem("Toolbar", {0, 1, 1}, legendY + 90)
end

return ui
