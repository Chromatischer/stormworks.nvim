-- ui_tester.lua (minimal)
-- Minimal test to exercise only core drawing functions on the Game canvas
-- Usage:
--   love Love/ --script Love/example/ui_tester.lua --tiles 4x3 --tick 60 --scale 3 --debug-canvas true --props showGrid=true
--
-- Core coverage on Game canvas (screen.*):
-- - clear, setColor, setLineWidth
-- - drawRect, drawRectF, drawCircle, drawCircleF, drawLine, drawText
-- - getWidth, getHeight
--
-- Extras:
-- - Minimal IO usage: echoes B1 to O1, inverted B2 to O2; O1 number is a sine wave
-- - Toggle B31 to cause an out-of-range access warning
-- - Toggle B32 to cause an intentional error (to verify error handling)

local t = 0
local prevB = {false, false}

local function edge(idx, val)
  -- Keep logging sparse: only edges for B1/B2
  print(string.format("[edge] B%d -> %s", idx, tostring(val)))
end

function onTick()
  t = t + 1

  -- Minimal bool IO
  local b1 = input.getBool(1)
  local b2 = input.getBool(2)
  if b1 ~= prevB[1] then edge(1, b1); prevB[1] = b1 end
  if b2 ~= prevB[2] then edge(2, b2); prevB[2] = b2 end
  output.setBool(1, b1)
  output.setBool(2, not b2)

  -- Minimal number IO
  local phase = (t/60) * 2*math.pi
  output.setNumber(1, 0.5 + 0.5*math.sin(phase))
  output.setNumber(2, input.getNumber(1) or 0)

  -- Out-of-range warning trigger
  if input.getBool(31) then
    local _ = input.getBool(33) -- should warn
  end

  -- Intentional error trigger
  if input.getBool(32) then
    local crash = nil; crash.oops()
  end
end

function onDraw()
  local w = screen.getWidth()
  local h = screen.getHeight()
  local showGrid = property.getBool('showGrid')

  screen.clear(12,12,14)

  -- Border
  screen.setColor(255,255,255)
  screen.drawRect(0,0,w-1,h-1)

  -- Optional 32px grid
  if showGrid then
    screen.setColor(40,40,48)
    screen.setLineWidth(1)
    for x=0, w-1, 32 do screen.drawLine(x, 0, x, h-1) end
    for y=0, h-1, 32 do screen.drawLine(0, y, w-1, y) end
  end

  -- Title
  screen.setColor(220,220,220)
  screen.drawText(4,4, "Core draw test")

  -- Shapes (compact, non-overlapping)
  screen.setLineWidth(1)
  -- Rect outline
  screen.setColor(255,255,255)
  screen.drawRect(8, 20, 40, 24)
  -- Filled rect
  screen.setColor(120,200,120)
  screen.drawRectF(56, 20, 40, 24)
  -- Circle outline
  screen.setColor(255,160,80)
  screen.drawCircle(28, 60, 12)
  -- Filled circle
  screen.setColor(90,160,255)
  screen.drawCircleF(76, 60, 12)
  -- Line
  screen.setColor(255,255,0)
  screen.drawLine(8, h-16, 96, h-32)

  -- Moving dot
  local x = 12 + (t % math.max(1, (w-24)))
  screen.setColor(255,220,0)
  screen.drawCircleF(x, h-12, 3)

  -- Minimal status text
  screen.setColor(200,200,200)
  screen.drawText(4, 16, string.format("%dx%d px", w, h))
  screen.drawText(4, 28, string.format("O1=%.2f  O2=%.2f", outputNumberPreview(1), outputNumberPreview(2)))
end

-- Helper to mirror minimal outputs for display
function outputNumberPreview(i)
  if i == 1 then
    local phase = (t/60) * 2*math.pi
    return 0.5 + 0.5*math.sin(phase)
  elseif i == 2 then
    return input.getNumber(1) or 0
  else
    return 0
  end
end

-- Optional simple debug canvas content
function onDebugDraw()
  if not dbg then return end
  local W,H = dbg.getWidth(), dbg.getHeight()
  dbg.clear(10,10,12)
  dbg.setColor(240,240,240)
  dbg.drawRect(0,0,W-1,H-1)
  dbg.setColor(80,200,255)
  local ox, oy = 0, H/2
  for x=0,W-1 do
    local y = H/2 + (H*0.3) * math.sin((t/60)*2*math.pi + x*0.02)
    dbg.drawLine(ox, oy, x, y)
    ox, oy = x, y
  end
  dbg.setColor(200,200,200)
  dbg.drawText(8, H-20, "Debug Canvas OK")
end
