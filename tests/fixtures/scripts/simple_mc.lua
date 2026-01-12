local t = 0

function onTick()
  t = t + 1
  output.setNumber(1, t)
end

function onDraw()
  screen.setColor(255, 255, 255)
  screen.drawText(5, 5, "Tick: " .. t)
end
