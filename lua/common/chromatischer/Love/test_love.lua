-- Simple LÖVE2D test script
-- Save as test_love.lua and either:
-- 1) Rename to main.lua and run `love .` in its folder, or
-- 2) Create a main.lua that simply requires this file: `require("test_love")`

local state = {
  paused = false,
  message = "Hello, LÖVE! Move the circle with Arrow keys or WASD.",
}

local circle = {
  x = 400,
  y = 300,
  r = 30,
  speed = 220,
  color = { 1.0, 0.7, 0.2 },
}

local font

local function clamp(v, lo, hi)
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

function love.load()
  love.window.setTitle("LÖVE2D Test")
  love.window.setMode(800, 600, { resizable = true, minwidth = 400, minheight = 300 })
  love.graphics.setBackgroundColor(0.10, 0.11, 0.13)
  love.graphics.setDefaultFilter("nearest", "nearest", 1)
  font = love.graphics.newFont(14)
end

function love.update(dt)
  if state.paused then
    return
  end

  local dx, dy = 0, 0
  if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
    dx = dx - 1
  end
  if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
    dx = dx + 1
  end
  if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
    dy = dy - 1
  end
  if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
    dy = dy + 1
  end

  if dx ~= 0 or dy ~= 0 then
    local len = math.sqrt(dx * dx + dy * dy)
    dx, dy = dx / len, dy / len
    circle.x = circle.x + dx * circle.speed * dt
    circle.y = circle.y + dy * circle.speed * dt
  end

  -- Keep the circle inside the window bounds
  local ww, wh = love.graphics.getDimensions()
  circle.x = clamp(circle.x, circle.r, ww - circle.r)
  circle.y = clamp(circle.y, circle.r, wh - circle.r)
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "p" then
    state.paused = not state.paused
  elseif key == "space" then
    -- Randomize circle color
    circle.color = { love.math.random(), love.math.random(), love.math.random() }
  end
end

local function drawGrid(cell)
  local ww, wh = love.graphics.getDimensions()
  love.graphics.setColor(0.18, 0.20, 0.24)
  for x = 0, ww, cell do
    love.graphics.line(x, 0, x, wh)
  end
  for y = 0, wh, cell do
    love.graphics.line(0, y, ww, y)
  end
end

function love.draw()
  drawGrid(40)

  -- Circle
  love.graphics.setColor(circle.color)
  love.graphics.circle("fill", circle.x, circle.y, circle.r)
  love.graphics.setColor(0, 0, 0, 0.25)
  love.graphics.circle("line", circle.x, circle.y, circle.r)

  -- UI text
  love.graphics.setFont(font)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(state.message, 16, 16)
  love.graphics.print("Press P to pause | Space to change color | Esc to quit", 16, 36)
  love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 16, 56)
  love.graphics.print(string.format("Circle: (%.1f, %.1f)", circle.x, circle.y), 16, 76)
  if state.paused then
    local ww, wh = love.graphics.getDimensions()
    local text = "PAUSED"
    local tw = font:getWidth(text)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(text, (ww - tw) / 2, wh * 0.45)
  end
end

function love.resize(w, h)
  -- Called when the window is resized; nothing special to do here,
  -- but it's useful to keep around for debugging/layout.
end
