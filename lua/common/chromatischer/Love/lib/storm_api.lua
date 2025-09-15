-- Stormworks-like API facade for the user script
local state = require('lib.state')
local logger = require('lib.logger')
local canvases = require('lib.canvases')
local font4x6 = require('lib.font4x6')

local M = {}

local function clampChannel(ch)
  if type(ch) ~= 'number' then return nil end
  ch = math.floor(ch)
  if ch < 1 or ch > 32 then
    logger.append(string.format("[warn] channel out of range: %d", ch))
    return nil
  end
  return ch
end

M.input = {}
function M.input.getBool(ch)
  ch = clampChannel(ch); if not ch then return false end
  return state.inputB[ch] or false
end
function M.input.getNumber(ch)
  ch = clampChannel(ch); if not ch then return 0 end
  return state.inputN[ch] or 0
end

M.output = {}
function M.output.setBool(ch, v)
  ch = clampChannel(ch); if not ch then return end
  state.outputB[ch] = not not v
end
function M.output.setNumber(ch, v)
  ch = clampChannel(ch); if not ch then return end
  state.outputN[ch] = tonumber(v) or 0
end

M.property = {}
function M.property.getNumber(name)
  local v = state.properties[name]
  if type(v) == 'number' then return v end
  return tonumber(v) or 0
end
function M.property.getText(name)
  local v = state.properties[name]
  if type(v) == 'string' then return v end
  return v and tostring(v) or ""
end
function M.property.getBool(name)
  local v = state.properties[name]
  if type(v) == 'boolean' then return v end
  if v == nil then return false end
  if v == 0 or v == "0" or v == "false" then return false end
  return not not v
end

local function to255(r,g,b,a)
  a = a or 255
  return r/255, g/255, b/255, a/255
end

local screen_api = {}
function screen_api.setColor(r,g,b,a) love.graphics.setColor(to255(r,g,b,a)) end
function screen_api.drawRect(x,y,w,h)
  love.graphics.rectangle('line', math.floor(x), math.floor(y), math.floor(w), math.floor(h))
end
function screen_api.drawRectF(x,y,w,h)
  love.graphics.rectangle('fill', math.floor(x), math.floor(y), math.floor(w), math.floor(h))
end
function screen_api.drawCircle(x,y,r)
  love.graphics.circle('line', math.floor(x), math.floor(y), math.floor(r))
end
function screen_api.drawCircleF(x,y,r)
  love.graphics.circle('fill', math.floor(x), math.floor(y), math.floor(r))
end
function screen_api.drawLine(x1,y1,x2,y2)
  -- Snap coordinates to integers for pixel-sharp lines
  love.graphics.line(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2))
end
-- screen.drawText uses a 4x6 pixel font for crisp, Stormworks-like text
function screen_api.drawText(x,y,t)
  font4x6.print(tostring(t), math.floor(x), math.floor(y))
end
function screen_api.setLineWidth(w) love.graphics.setLineWidth(w) end
function screen_api.getWidth() local w,_ = canvases.game:getDimensions(); return w end
function screen_api.getHeight() local _,h = canvases.game:getDimensions(); return h end
function screen_api.clear(r,g,b,a) love.graphics.clear(to255(r or 0,g or 0,b or 0,a or 255)) end

-- Debug API that draws to debug canvas even when called during onDraw
local function with_debug_canvas(fn)
  return function(...)
    if not state.debugCanvasEnabled or not canvases or not canvases.debug then return end
    local prev = love.graphics.getCanvas()
    love.graphics.setCanvas(canvases.debug)
    fn(...)
    love.graphics.setCanvas(prev)
  end
end

local dbg_api = {
  setColor = with_debug_canvas(function(r,g,b,a) love.graphics.setColor(to255(r,g,b,a)) end),
  setLineWidth = with_debug_canvas(function(w) love.graphics.setLineWidth(w) end),
  drawRect = with_debug_canvas(function(x,y,w,h) love.graphics.rectangle('line', x, y, w, h) end),
  drawRectF = with_debug_canvas(function(x,y,w,h) love.graphics.rectangle('fill', x, y, w, h) end),
  drawCircle = with_debug_canvas(function(x,y,r) love.graphics.circle('line', x, y, r) end),
  drawCircleF = with_debug_canvas(function(x,y,r) love.graphics.circle('fill', x, y, r) end),
  drawLine = with_debug_canvas(function(x1,y1,x2,y2) love.graphics.line(x1,y1,x2,y2) end),
  drawText = with_debug_canvas(function(x,y,t) love.graphics.print(tostring(t), x, y) end),
  getWidth = function() return canvases.debug and canvases.debug:getWidth() or 0 end,
  getHeight = function() return canvases.debug and canvases.debug:getHeight() or 0 end,
  clear = with_debug_canvas(function(r,g,b,a) love.graphics.clear(to255(r or 0,g or 0,b or 0,a or 255)) end),
}

M.time = {}
function M.time.getDelta() return state.lastTickDt end

function M.bind_to_env(env)
  env.input = M.input
  env.output = M.output
  env.property = M.property
  env.screen = screen_api
  env.dbg = dbg_api
  env.time = M.time
end

-- Wrappers for rendering phases
function M.draw_user_onDraw(env)
  canvases.withTarget('game', function()
    if env.onDraw then env.onDraw() end
  end)
  if state.debugCanvasEnabled then
    canvases.withTarget('debug', function()
      if env.onDebugDraw then env.onDebugDraw() end -- optional
    end)
  end
end

return M
