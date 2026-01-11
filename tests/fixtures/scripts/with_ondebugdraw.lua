function onTick()
  output.setNumber(1, 42)
end

function onDraw()
  screen.setColor(255, 255, 255)
  screen.drawText(5, 5, "Main")
end

function onDebugDraw()
  -- This should be stripped in minimizer
  screen.setColor(255, 0, 0)
  screen.drawText(10, 10, "Debug")
end
