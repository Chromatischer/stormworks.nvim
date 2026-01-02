-- Canvas management and drawing helpers
local state = require('lib.state')

local canvases = {
  game = nil,
  debug = nil,
}

local function to255(r,g,b,a)
  a = a or 255
  return r/255, g/255, b/255, a/255
end

local function createGameCanvas()
  local gw, gh = state.getGameSize()
  canvases.game = love.graphics.newCanvas(gw, gh, {msaa = 0})
  canvases.game:setFilter('nearest', 'nearest')
end

local function createDebugCanvas()
  canvases.debug = love.graphics.newCanvas(state.debugCanvasW, state.debugCanvasH, {msaa = 0})
  canvases.debug:setFilter('nearest', 'nearest')
end

function canvases.recreateAll()
  createGameCanvas()
  if state.debugCanvasEnabled then
    createDebugCanvas()
  else
    canvases.debug = nil
  end
end

function canvases.ensure()
  if not canvases.game then createGameCanvas() end
  if state.debugCanvasEnabled and not canvases.debug then createDebugCanvas() end
end

-- Drawing API mapping
local target = 'game' -- default target key

local function setTarget(name)
  target = name
  if name == 'game' then
    love.graphics.setCanvas(canvases.game)
  elseif name == 'debug' and canvases.debug then
    love.graphics.setCanvas(canvases.debug)
  else
    love.graphics.setCanvas()
  end
end

local function clear(r,g,b,a)
  if r then love.graphics.clear(to255(r,g,b,a)) else love.graphics.clear(0,0,0,0) end
end

local api = {}

function api.setColor(r,g,b,a) love.graphics.setColor(to255(r,g,b,a)) end
function api.setLineWidth(w) love.graphics.setLineWidth(w) end
function api.drawRect(x,y,w,h) love.graphics.rectangle('line', x, y, w, h) end
function api.drawRectF(x,y,w,h) love.graphics.rectangle('fill', x, y, w, h) end
function api.drawCircle(x,y,r) love.graphics.circle('line', x, y, r) end
function api.drawCircleF(x,y,r) love.graphics.circle('fill', x, y, r) end
function api.drawLine(x1,y1,x2,y2) love.graphics.line(x1,y1,x2,y2) end
function api.drawText(x,y,text)
  love.graphics.print(tostring(text), x, y)
end
function api.getSize()
  if target == 'game' then return canvases.game:getWidth(), canvases.game:getHeight() end
  if target == 'debug' and canvases.debug then return canvases.debug:getWidth(), canvases.debug:getHeight() end
  return 0,0
end
function api.clear(r,g,b,a) clear(r,g,b,a) end

function canvases.withTarget(name, fn)
  local prev = love.graphics.getCanvas()
  setTarget(name)
  fn(api)
  love.graphics.setCanvas(prev)
end

function canvases.drawToScreen(panel, which)
  local canvas = (which == 'game') and canvases.game or canvases.debug
  if not canvas then return end
  local scale = (which == 'game') and state.gameCanvasScale or state.debugCanvasScale
  love.graphics.setColor(1,1,1,1)
  -- Use nearest filtering, aligned to integer coords for pixel-sharp display
  love.graphics.draw(canvas, math.floor(panel.x), math.floor(panel.y), 0, scale, scale)
end

return canvases
