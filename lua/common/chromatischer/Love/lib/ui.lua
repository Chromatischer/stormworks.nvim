-- Minimal immediate-mode UI and layout with simple interactivity
local state = require('lib.state')
local detach = require('lib.detach')
local sandbox = require('lib.sandbox')
local canvases = require('lib.canvases')

local ui = {}

ui.color = {
  bg = {22/255, 22/255, 24/255, 1},
  panel = {30/255, 30/255, 34/255, 1},
  text = {220/255, 220/255, 220/255, 1},
  accent = {80/255, 160/255, 255/255, 1},
  warn = {1, 0.5, 0.2, 1},
  ok = {0.3, 0.9, 0.4, 1},
}

-- Optional external icon images (if present). We try to load PNGs at runtime.
ui.icons = { popout = nil, undock = nil, dock = nil }

local function load_icon(name)
  if ui.icons[name] ~= nil then return ui.icons[name] end
  local candidates = {
    "assets/icons/"..name..".png",
    "assets/ui/"..name..".png",
    "assets/"..name..".png",
  }
  for _,p in ipairs(candidates) do
    if love.filesystem.getInfo(p) then
      local ok, img = pcall(love.graphics.newImage, p, {mipmaps=true})
      if ok and img then
        img:setFilter('linear', 'linear', 4)
        ui.icons[name] = img
        return img
      end
    end
  end
  ui.icons[name] = false -- cache miss
  return false
end

ui.panels = {
  toolbar = {x=0,y=0,w=0,h=32},
  io_inputs = {x=0,y=32,w=320,h=0},
  game = {x=320,y=32,w=0,h=0},
  io_outputs = {x=0,y=32,w=320,h=0},
  debug_center = {x=0,y=0,w=0,h=0},
  log = {x=0,y=0,w=0,h=120},
}

-- Interactive hit regions
ui._boolRects = {}
ui._numRects = {}
ui._activeSlider = nil
ui._navRects = {}
ui._toolbarRects = {}
ui.leftTab = 'inputs' -- for merged mode (Inputs | Outputs)

local function draw_panel(p)
  love.graphics.setColor(ui.color.panel)
  love.graphics.rectangle('fill', p.x, p.y, p.w, p.h, 4, 4)
end

local function text(x,y, s)
  love.graphics.setColor(ui.color.text)
  love.graphics.print(s, x, y)
end

local NAV_H = 24

-- Small toggle knob used by Inputs UI
local function draw_bool_toggle(x,y,val)
  local r = 8
  love.graphics.setColor(0.15,0.15,0.15,1)
  love.graphics.rectangle('fill', x-10, y-10, 20, 20, 3,3)
  love.graphics.setColor(val and ui.color.ok or {0.25,0.25,0.25,1})
  love.graphics.circle('fill', x, y, r)
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
  love.graphics.rectangle('line', px, py + (s - w), w, w, 2, 2)
  -- arrow to NE
  local ax0 = px + math.floor(s * 0.35)
  local ay0 = py + math.floor(s * 0.35)
  local ax1 = px + s - 1
  local ay1 = py + 1
  love.graphics.line(ax0, ay0, ax1, ay1)
  -- arrow head
  love.graphics.polygon('fill', ax1, ay1, ax1-5, ay1, ax1, ay1+5)
end

-- Icon: dock (re-attach). Draws a window with an inward SW arrow.
local function draw_icon_dock(x, y, size, color)
  local s = size or 16
  local px = math.floor(x) + 0.5
  local py = math.floor(y) + 0.5
  love.graphics.setLineWidth(1)
  love.graphics.setColor(color)
  -- outer window
  love.graphics.rectangle('line', px, py, s, s, 2, 2)
  -- inward arrow SW
  local ax0 = px + s - 6
  local ay0 = py + 6
  local ax1 = px + 3
  local ay1 = py + s - 3
  love.graphics.line(ax0, ay0, ax1, ay1)
  love.graphics.polygon('fill', ax1, ay1, ax1+5, ay1, ax1, ay1-5)
end

local function draw_nav_bar(p, title, which)
  -- which: 'game' | 'debug' | 'left' (merged tabs)
  love.graphics.setColor(0.16,0.16,0.18,1)
  love.graphics.rectangle('fill', p.x, p.y, p.w, NAV_H, 4,4)
  love.graphics.setColor(1,1,1,0.08)
  love.graphics.rectangle('line', p.x+0.5, p.y+0.5, p.w-1, NAV_H-1, 4,4)

  ui._navRects = ui._navRects or {}

  if which == 'left' and ui.mergedOutputs then
    -- Split header into two equal clickable halves: I | O
    local mid = p.x + math.floor(p.w/2)
    local leftR = {x=p.x, y=p.y, w=mid - p.x, h=NAV_H}
    local rightR = {x=mid, y=p.y, w=p.x + p.w - mid, h=NAV_H}

    -- Left half (I)
    local leftActive = (ui.leftTab == 'inputs')
    love.graphics.setColor(leftActive and ui.color.accent or {0.22,0.22,0.26,1})
    love.graphics.rectangle('fill', leftR.x, leftR.y, leftR.w, leftR.h, 4,4)
    love.graphics.setColor(1,1,1, leftActive and 1 or 0.85)
    love.graphics.printf('I', leftR.x, leftR.y+3, leftR.w, 'center')
    ui._navRects['left_tab_inputs'] = {x=leftR.x, y=leftR.y, w=leftR.w, h=leftR.h, action='left_tab', tab='inputs'}

    -- Right half (O)
    local rightActive = (ui.leftTab == 'outputs')
    love.graphics.setColor(rightActive and ui.color.accent or {0.22,0.22,0.26,1})
    love.graphics.rectangle('fill', rightR.x, rightR.y, rightR.w, rightR.h, 4,4)
    love.graphics.setColor(1,1,1, rightActive and 1 or 0.85)
    love.graphics.printf('O', rightR.x, rightR.y+3, rightR.w, 'center')
    ui._navRects['left_tab_outputs'] = {x=rightR.x, y=rightR.y, w=rightR.w, h=rightR.h, action='left_tab', tab='outputs'}

    -- Divider line in middle for clarity
    love.graphics.setColor(0,0,0,0.25)
    love.graphics.line(mid, p.y+2, mid, p.y+NAV_H-2)
  else
    -- Standard title
    love.graphics.setColor(ui.color.text)
    love.graphics.print(title or '', p.x+8, p.y+5)

    -- Right-side detach button (improved glyph + hover state)
    if which == 'game' or which == 'debug' then
      local btnSize = 18
      local bx = p.x + p.w - (btnSize + 6)
      local by = p.y + math.floor((NAV_H - btnSize)/2)
      local is_det = detach.is_enabled(which)

      -- Hover detection
      local mx,my = love.mouse.getPosition()
      local is_hover = (mx >= bx and my >= by and mx <= bx+btnSize and my <= by+btnSize)

      -- Button background
      local bg = is_det and ui.color.accent or {0.22,0.22,0.26,1}
      local bg_hover = is_det and {0.36,0.62,1.0,1} or {0.28,0.28,0.34,1}
      love.graphics.setColor(is_hover and bg_hover or bg)
      love.graphics.rectangle('fill', bx, by, btnSize, btnSize, 4,4)
      love.graphics.setColor(0,0,0,0.35)
      love.graphics.rectangle('line', bx+0.5, by+0.5, btnSize-1, btnSize-1, 4,4)

      -- Icon: prefer external PNG if provided, otherwise fallback to vector
      local pad = 3
      local target = btnSize - pad*2
      local img = (is_det and (load_icon('dock') or load_icon('attach') or load_icon('dock_filled'))) or
                  (load_icon('undock') or load_icon('popout') or load_icon('arrow_ne'))
      if img and img ~= false then
        local iw, ih = img:getDimensions()
        local scale = math.min(target/iw, target/ih)
        local ox = (target - iw*scale)/2
        local oy = (target - ih*scale)/2
        love.graphics.setColor(1,1,1, is_hover and 1 or 0.95)
        love.graphics.draw(img, bx+pad+ox, by+pad+oy, 0, scale, scale)
      else
        local iconColor = is_det and {1,1,1,1} or {1,1,1,0.95}
        if is_det then
          draw_icon_dock(bx+pad, by+pad, target, iconColor)
        else
          draw_icon_popout(bx+pad, by+pad, target, iconColor)
        end
      end

      ui._navRects[which] = {x=bx, y=by, w=btnSize, h=btnSize, action='toggle_detach', which=which}
    end
  end
end

local function panel_content_scissor(p)
  love.graphics.setScissor(p.x, p.y+NAV_H, p.w, p.h-NAV_H)
end

-- Toolbar buttons (icon-only) -------------------------------------------------
local function draw_toolbar_icon_button(x, y, opts)
  -- opts: { name='play', active=false, action='toggle_run', tooltip='Play/Pause' }
  local btnSize = 22
  local pad = 3
  local bx, by = x, y
  local mx,my = love.mouse.getPosition()
  local is_hover = (mx >= bx and my >= by and mx <= bx+btnSize and my <= by+btnSize)
  local bg_base = opts.active and ui.color.accent or {0.22,0.22,0.26,1}
  local bg_hover = opts.active and {0.36,0.62,1.0,1} or {0.28,0.28,0.34,1}
  love.graphics.setColor(is_hover and bg_hover or bg_base)
  love.graphics.rectangle('fill', bx, by, btnSize, btnSize, 4,4)
  love.graphics.setColor(0,0,0,0.35)
  love.graphics.rectangle('line', bx+0.5, by+0.5, btnSize-1, btnSize-1, 4,4)

  -- icon draw
  local img = load_icon(opts.name)
  local target = btnSize - pad*2
  if img and img ~= false then
    local iw, ih = img:getDimensions()
    local scale = math.min(target/iw, target/ih)
    local ox = (target - iw*scale)/2
    local oy = (target - ih*scale)/2
    love.graphics.setColor(1,1,1, is_hover and 1 or 0.95)
    love.graphics.draw(img, bx+pad+ox, by+pad+oy, 0, scale, scale)
  else
    -- fallback: small triangle for play
    love.graphics.setColor(1,1,1,0.95)
    love.graphics.polygon('fill', bx+7, by+5, bx+7, by+btnSize-5, bx+btnSize-5, by+btnSize/2)
  end

  -- register hit rect
  ui._toolbarRects[#ui._toolbarRects+1] = {x=bx, y=by, w=btnSize, h=btnSize, action=opts.action}

  return btnSize
end

-- Shared content renderers (used for merged tab mode)
local function draw_inputs_content(p)
  local fontH = love.graphics.getFont() and love.graphics.getFont():getHeight() or 14
  local labelPad = 8

  -- Bool inputs (click to toggle)
  text(p.x+8, p.y+NAV_H+6, "Bool Inputs")
  local boolInBaseY = p.y + NAV_H + 6 + fontH + labelPad
  ui._boolRects = {}
  for i=1,32 do
    local col = (i-1)%8
    local row = math.floor((i-1)/8)
    local bx = p.x+18 + col*28
    local by = boolInBaseY + row*24
    draw_bool_toggle(bx, by, state.inputB[i])
    ui._boolRects[i] = {x=bx-12,y=by-12,w=24,h=24}
  end

  -- Number inputs (sliders 0..1)
  local numInLabelY = boolInBaseY + 4*24 + 16
  text(p.x+8, numInLabelY, "Number Inputs (0..1)")
  ui._numRects = {}
  local sx = p.x+8
  local sy = numInLabelY + fontH + labelPad
  local colW = (p.w-16-8)/2
  local sW = colW - 48 -- shrink slider width to leave space for value text to the right
  local sH = 12
  local rowGap = sH + 18 -- generous vertical spacing
  for i=1,32 do
    local col = (i-1)%2
    local row = math.floor((i-1)/2)
    local rx = sx + col*colW
    local ry = sy + row*rowGap
    local v = math.max(0, math.min(1, state.inputN[i] or 0))
    love.graphics.setColor(ui.color.text)
    love.graphics.print(string.format("N%02d", i), rx, ry - (fontH + 2))
    love.graphics.setColor(0.2,0.2,0.2,1)
    love.graphics.rectangle('fill', rx, ry, sW, sH, 2,2)
    love.graphics.setColor(ui.color.accent)
    love.graphics.rectangle('fill', rx, ry, sW * v, sH, 2,2)
    love.graphics.setColor(ui.color.text)
    love.graphics.rectangle('line', rx, ry, sW, sH, 2,2)
    love.graphics.print(string.format("%.2f", v), rx + sW + 8, ry - 1)
    ui._numRects[i] = {x=rx,y=ry,w=sW,h=sH}
  end
end

local function draw_outputs_content(p)
  local fontH = love.graphics.getFont() and love.graphics.getFont():getHeight() or 14
  local labelPad = 8

  -- Bool outputs
  text(p.x+8, p.y+NAV_H+6, "Bool Outputs")
  local boolOutBaseY = p.y + NAV_H + 6 + fontH + labelPad
  for i=1,32 do
    local col = (i-1)%8
    local row = math.floor((i-1)/8)
    local bx = p.x+18 + col*28
    local by = boolOutBaseY + row*24
    love.graphics.setColor(state.outputB[i] and ui.color.ok or {0.2,0.2,0.2,1})
    love.graphics.circle('fill', bx, by, 6)
  end

  -- Number outputs (text)
  local outLabelY = boolOutBaseY + 4*24 + 16
  text(p.x+8, outLabelY, "Number Outputs")
  local sx = p.x+8
  local oy = outLabelY + fontH + 4
  local colW = (p.w-16-8)/2
  for i=1,32 do
    local col = (i-1)%2
    local row = math.floor((i-1)/2)
    local tx = sx + col*colW
    local ty = oy + row*(fontH + 4)
    love.graphics.setColor(ui.color.text)
    love.graphics.print(string.format("O%02d %.3f", i, state.outputN[i] or 0), tx, ty)
  end
end

function ui.layout(w,h)
  ui.panels.toolbar = {x=8,y=8,w=w-16,h=28}

  -- Bottom section: log at bottom
  local logH = math.min(140, math.floor(h * 0.18))
  ui.panels.log = {x=8, y=h - logH - 8, w=w-16, h=logH}

  -- Middle row: inputs (left), game (center), outputs (right)
  local midTop = ui.panels.toolbar.y + ui.panels.toolbar.h + 8
  local midBottom = ui.panels.log.y - 8
  local midH = midBottom - midTop

  local leftW = 320
  local rightW = 320
  local gameWpx = state.tilesX*state.tileSize*state.gameCanvasScale
  local gameHpx = state.tilesY*state.tileSize*state.gameCanvasScale
  local dbgWpx = state.debugCanvasEnabled and (state.debugCanvasW*state.debugCanvasScale) or 0
  local dbgHpx = state.debugCanvasEnabled and (state.debugCanvasH*state.debugCanvasScale) or 0
  local centerW = math.max(gameWpx + 16, dbgWpx + 16, 200)
  local availableCenterW = math.max(200, w - 16 - leftW - rightW - 16)

  -- Merge outputs into inputs when width is too small
  ui.mergedOutputs = false
  if availableCenterW < 260 or w < 980 then
    -- Not enough room for three columns; collapse to two columns (Inputs + Game)
    ui.mergedOutputs = true
    rightW = 0
    availableCenterW = math.max(200, w - 16 - leftW - 8)
  end

  centerW = math.min(centerW, availableCenterW)

  ui.panels.io_inputs = {x=8, y=midTop, w=leftW, h=midH}
  ui.panels.game = {x=ui.panels.io_inputs.x + leftW + 8, y=midTop, w=centerW, h=math.min(midH, gameHpx + 16 + NAV_H)}
  local debugY = ui.panels.game.y + ui.panels.game.h + (state.debugCanvasEnabled and 8 or 0)
  local debugH = state.debugCanvasEnabled and (dbgHpx + 16 + NAV_H) or 0
  ui.panels.debug_center = {x=ui.panels.game.x, y=debugY, w=centerW, h=debugH}
  if ui.mergedOutputs then
    -- Outputs handled inside left panel via tabs; skip right panel sizing
    ui.panels.io_outputs = {x=ui.panels.io_inputs.x, y=ui.panels.io_inputs.y, w=leftW, h=midH}
  else
    ui.panels.io_outputs = {x=ui.panels.game.x + centerW + 8, y=midTop, w=rightW, h=midH}
  end
end

function ui.draw_toolbar()
  local p = ui.panels.toolbar
  draw_panel(p)
  ui._toolbarRects = {}
  local x = p.x + 8
  local y = p.y + math.floor((p.h - 22)/2)

  -- Play/Pause
  x = x + draw_toolbar_icon_button(x, y, {
    name = state.running and 'pause' or 'play',
    active = state.running,
    action = 'toggle_run'
  }) + 6

  -- Step
  x = x + draw_toolbar_icon_button(x, y, {
    name = 'step',
    active = false,
    action = 'step'
  }) + 6

  -- Reload
  x = x + draw_toolbar_icon_button(x, y, {
    name = 'refresh',
    active = false,
    action = 'reload'
  }) + 12

  -- Debug toggle
  x = x + draw_toolbar_icon_button(x, y, {
    name = 'bug',
    active = state.debugCanvasEnabled,
    action = 'toggle_debug'
  }) + 16

  -- Scale controls
  love.graphics.setColor(ui.color.text)
  love.graphics.print(string.format('Scale: %dx', state.gameCanvasScale), x, p.y+6)
  x = x + 90
  x = x + draw_toolbar_icon_button(x, y, {
    name = 'remove',
    active = false,
    action = 'scale_minus'
  }) + 6
  x = x + draw_toolbar_icon_button(x, y, {
    name = 'add',
    active = false,
    action = 'scale_plus'
  }) + 16

  -- Static info (tiles, tick)
  love.graphics.setColor(ui.color.text)
  love.graphics.print(string.format('Tiles: %dx%d', state.tilesX, state.tilesY), x, p.y+6)
  x = x + 120
  love.graphics.print(string.format('Tick: %d', state.tickRate), x, p.y+6)
end

-- Inputs panel: with optional tabbed merge for Outputs
function ui.draw_inputs()
  local p = ui.panels.io_inputs
  draw_panel(p)
  if ui.mergedOutputs then
    draw_nav_bar(p, '', 'left')
  else
    draw_nav_bar(p, "Inputs", nil)
  end
  panel_content_scissor(p)

  if ui.mergedOutputs and ui.leftTab == 'outputs' then
    draw_outputs_content(p)
  else
    draw_inputs_content(p)
  end

  love.graphics.setScissor()
end

-- Outputs panel: hidden when merged (content shown inside left panel via tab)
function ui.draw_outputs()
  if ui.mergedOutputs then return end
  local p = ui.panels.io_outputs
  draw_panel(p)
  draw_nav_bar(p, "Outputs", nil)
  panel_content_scissor(p)
  draw_outputs_content(p)
  love.graphics.setScissor()
end

function ui.draw_game_canvas()
  local p = ui.panels.game
  draw_panel(p)
  draw_nav_bar(p, "Game", 'game')
  -- inner rect where canvas is drawn
  local cx = p.x+8
  local cy = p.y+NAV_H+8
  return {x=cx, y=cy}
end

function ui.draw_debug_canvas_center()
  local p = ui.panels.debug_center
  draw_panel(p)
  draw_nav_bar(p, "Debug", 'debug')
  local cx = p.x+8
  local cy = p.y+NAV_H+8
  return {x=cx, y=cy}
end

function ui.draw_log(logger)
  local p = ui.panels.log
  draw_panel(p)
  draw_nav_bar(p, "Log", nil)
  local lines = logger.getLines(200)
  love.graphics.setScissor(p.x, p.y+NAV_H, p.w, p.h-NAV_H)
  local y = p.y + NAV_H + 4
  local fontH = love.graphics.getFont() and love.graphics.getFont():getHeight() or 14
  for i = math.max(1, #lines-8*6), #lines do
    love.graphics.setColor(ui.color.text)
    love.graphics.print(lines[i], p.x+8, y)
    y = y + fontH
    if y > p.y + p.h - fontH then break end
  end
  love.graphics.setScissor()
end

function ui.mousepressed(mx,my,button)
  if button ~= 1 then return end
  -- Toolbar buttons
  if ui._toolbarRects then
    for _,r in ipairs(ui._toolbarRects) do
      if r and (mx >= r.x and my >= r.y and mx <= r.x+r.w and my <= r.y+r.h) then
        if r.action == 'toggle_run' then
          state.running = not state.running; return
        elseif r.action == 'step' then
          state.singleStep = true; return
        elseif r.action == 'reload' then
          sandbox.reload(); return
        elseif r.action == 'toggle_debug' then
          state.debugCanvasEnabled = not state.debugCanvasEnabled; canvases.recreateAll(); return
        elseif r.action == 'scale_minus' then
          state.gameCanvasScale = math.max(1, state.gameCanvasScale - 1); return
        elseif r.action == 'scale_plus' then
          state.gameCanvasScale = math.min(8, state.gameCanvasScale + 1); return
        end
      end
    end
  end
  -- Nav bars (detach buttons / tabs)
  if ui._navRects then
    for _,r in pairs(ui._navRects) do
      if r and (mx >= r.x and my >= r.y and mx <= r.x+r.w and my <= r.y+r.h) then
        if r.action == 'toggle_detach' and r.which then
          local detach_mod = require('lib.detach')
          detach_mod.toggle(r.which)
          return
        elseif r.action == 'left_tab' and r.tab then
          ui.leftTab = r.tab
          return
        end
      end
    end
  end
  -- Bool toggles (inputs only)
  for i,rect in ipairs(ui._boolRects) do
    if rect and (mx >= rect.x and my >= rect.y and mx <= rect.x+rect.w and my <= rect.y+rect.h) then
      state.inputB[i] = not state.inputB[i]
      return
    end
  end
  -- Number sliders (inputs only)
  for i,rect in ipairs(ui._numRects) do
    if rect and (mx >= rect.x and my >= rect.y and mx <= rect.x+rect.w and my <= rect.y+rect.h) then
      ui._activeSlider = {idx=i, rect=rect}
      local v = (mx - rect.x)/rect.w
      state.inputN[i] = math.max(0, math.min(1, v))
      return
    end
  end
end

function ui.mousereleased(mx,my,button)
  if button == 1 then ui._activeSlider = nil end
end

function ui.mousemoved(mx,my, dx,dy)
  if ui._activeSlider then
    local i = ui._activeSlider.idx
    local rect = ui._activeSlider.rect
    local v = (mx - rect.x)/rect.w
    state.inputN[i] = math.max(0, math.min(1, v))
  end
end

function ui.wheelmoved(dx,dy)
  if dy == 0 then return end
  local mx,my = love.mouse.getPosition()
  for i,rect in ipairs(ui._numRects) do
    if rect and (mx >= rect.x and my >= rect.y and mx <= rect.x+rect.w and my <= rect.y+rect.h) then
      local step = 0.02 * dy
      state.inputN[i] = math.max(0, math.min(1, (state.inputN[i] or 0) + step))
      return
    end
  end
end

return ui
