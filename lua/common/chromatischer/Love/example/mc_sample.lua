-- Example Stormworks-like microcontroller script
-- Save as Love/example/mc_sample.lua and run:
--   love Love/ --script Love/example/mc_sample.lua --tiles 3x2 --tick 60 --scale 4 --debug-canvas true

local t = 0

function onTick()
  t = t + 1
  -- Echo input 1 to output 1
  local b = input.getBool(1)
  output.setBool(1, b)
  -- Set output number 1 to a triangle wave
  local v = (t % 120) / 120
  if v > 0.5 then v = 1 - v end
  output.setNumber(1, v*2)
end

function onDraw()
  local w = screen.getWidth()
  local h = screen.getHeight()
  screen.clear(0,0,0)
  screen.setColor(255,255,255)
  screen.drawRect(1,1,w-2,h-2)
  screen.setColor(80,160,255)
  screen.drawText(6,6, "Hello Stormworks in LOVE2D")
  local r = (t % 120)
  screen.setColor(255,80,120)
  screen.drawCircleF(20+r, 40, 8)
  screen.setColor(120,255,120)
  screen.drawRectF(10, 60, 20, 10)
  screen.setColor(255,255,0)
  screen.drawLine(0, h-1, w, 0)

  if dbg then
    dbg.setColor(255,255,255)
    dbg.drawText(8,8, 'Debug canvas available')
  end
end
