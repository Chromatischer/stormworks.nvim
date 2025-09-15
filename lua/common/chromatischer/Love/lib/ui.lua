-- Minimal immediate-mode UI and layout with simple interactivity
local state = require('lib.state')

local ui = {}

ui.color = {
  bg = {22/255, 22/255, 24/255, 1},
  panel = {30/255, 30/255, 34/255, 1},
  text = {220/255, 220/255, 220/255, 1},
  accent = {80/255, 160/255, 255/255, 1},
  warn = {1, 0.5, 0.2, 1},
  ok = {0.3, 0.9, 0.4, 1},
}

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

local function draw_panel(p)
  love.graphics.setColor(ui.color.panel)
  love.graphics.rectangle('fill', p.x, p.y, p.w, p.h, 4, 4)
end

local function text(x,y, s)
  love.graphics.setColor(ui.color.text)
  love.graphics.print(s, x, y)
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
  centerW = math.min(centerW, availableCenterW)

  ui.panels.io_inputs = {x=8, y=midTop, w=leftW, h=midH}
  ui.panels.game = {x=ui.panels.io_inputs.x + leftW + 8, y=midTop, w=centerW, h=math.min(midH, gameHpx + 16)}
  local debugY = ui.panels.game.y + ui.panels.game.h + (state.debugCanvasEnabled and 8 or 0)
  local debugH = state.debugCanvasEnabled and (dbgHpx + 16) or 0
  ui.panels.debug_center = {x=ui.panels.game.x, y=debugY, w=centerW, h=debugH}
  ui.panels.io_outputs = {x=ui.panels.game.x + centerW + 8, y=midTop, w=rightW, h=midH}
end

function ui.draw_toolbar()
  local p = ui.panels.toolbar
  draw_panel(p)
  love.graphics.setColor(ui.color.text)
  local x = p.x+8
  local y = p.y+6
  local status = state.running and "Pause [Space]" or "Play [Space]"
  love.graphics.print(status, x, y); x = x + 120
  love.graphics.print("Step [N]", x, y); x = x + 90
  love.graphics.print(string.format("Tick: %d", state.tickRate), x, y); x = x + 90
  love.graphics.print(string.format("Scale: %dx (+/-)", state.gameCanvasScale), x, y); x = x + 160
  love.graphics.print(string.format("Tiles: %dx%d", state.tilesX, state.tilesY), x, y); x = x + 120
  love.graphics.print("Reload [R]", x, y); x = x + 100
  love.graphics.print("Debug [D]: "..(state.debugCanvasEnabled and 'On' or 'Off'), x, y)
end

local function draw_bool_toggle(x,y,val)
  local r = 8
  love.graphics.setColor(0.15,0.15,0.15,1)
  love.graphics.rectangle('fill', x-10, y-10, 20, 20, 3,3)
  love.graphics.setColor(val and ui.color.ok or {0.25,0.25,0.25,1})
  love.graphics.circle('fill', x, y, r)
end

local function point_in_rect(px,py, rx,ry,rw,rh)
  return px >= rx and py >= ry and px <= rx+rw and py <= ry+rh
end

-- Inputs panel: Bool inputs and Number inputs
function ui.draw_inputs()
  local p = ui.panels.io_inputs
  draw_panel(p)
  love.graphics.setScissor(p.x, p.y, p.w, p.h)

  local fontH = love.graphics.getFont() and love.graphics.getFont():getHeight() or 14
  local labelPad = 8

  -- Bool inputs (click to toggle)
  text(p.x+8, p.y+6, "Bool Inputs")
  local boolInBaseY = p.y + 6 + fontH + labelPad
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
    -- Label above slider
    love.graphics.setColor(ui.color.text)
    love.graphics.print(string.format("N%02d", i), rx, ry - (fontH + 2))
    love.graphics.setColor(0.2,0.2,0.2,1)
    love.graphics.rectangle('fill', rx, ry, sW, sH, 2,2)
    love.graphics.setColor(ui.color.accent)
    love.graphics.rectangle('fill', rx, ry, sW * v, sH, 2,2)
    love.graphics.setColor(ui.color.text)
    love.graphics.rectangle('line', rx, ry, sW, sH, 2,2)
    -- Value text right of slider
    love.graphics.print(string.format("%.2f", v), rx + sW + 8, ry - 1)
    ui._numRects[i] = {x=rx,y=ry,w=sW,h=sH}
  end

  love.graphics.setScissor()
end

-- Outputs panel: Bool outputs and Number outputs
function ui.draw_outputs()
  local p = ui.panels.io_outputs
  draw_panel(p)
  love.graphics.setScissor(p.x, p.y, p.w, p.h)

  local fontH = love.graphics.getFont() and love.graphics.getFont():getHeight() or 14
  local labelPad = 8

  -- Bool outputs
  text(p.x+8, p.y+6, "Bool Outputs")
  local boolOutBaseY = p.y + 6 + fontH + labelPad
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

  love.graphics.setScissor()
end

function ui.draw_game_canvas()
  local p = ui.panels.game
  draw_panel(p)
  -- inner rect where canvas is drawn
  local cx = p.x+8
  local cy = p.y+8
  return {x=cx, y=cy}
end

function ui.draw_debug_canvas_center()
  local p = ui.panels.debug_center
  draw_panel(p)
  local cx = p.x+8
  local cy = p.y+8
  return {x=cx, y=cy}
end

function ui.draw_log(logger)
  local p = ui.panels.log
  draw_panel(p)
  local lines = logger.getLines(200)
  love.graphics.setScissor(p.x, p.y, p.w, p.h)
  local y = p.y + 4
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
  -- Bool toggles (inputs only)
  for i,rect in ipairs(ui._boolRects) do
    if rect and point_in_rect(mx,my, rect.x,rect.y,rect.w,rect.h) then
      state.inputB[i] = not state.inputB[i]
      return
    end
  end
  -- Number sliders (inputs only)
  for i,rect in ipairs(ui._numRects) do
    if rect and point_in_rect(mx,my, rect.x,rect.y,rect.w,rect.h) then
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
    if rect and point_in_rect(mx,my, rect.x,rect.y,rect.w,rect.h) then
      local step = 0.02 * dy
      state.inputN[i] = math.max(0, math.min(1, (state.inputN[i] or 0) + step))
      return
    end
  end
end

return ui
