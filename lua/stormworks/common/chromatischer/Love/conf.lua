function love.conf(t)
  t.identity = "sw-mc-debugger"
  t.appendidentity = true
  
  -- Check for headless mode via command line args
  local headless = false
  for _, arg in ipairs(arg or {}) do
    if arg == "--headless" then
      headless = true
      break
    end
  end
  
  if headless then
    -- Headless mode: create minimal window (Love2D requires it for graphics context)
    t.window.title = "Stormworks Headless Export"
    t.window.width = 100
    t.window.height = 100
    t.window.resizable = false
    t.window.borderless = true
    t.window.vsync = 0
  else
    -- Normal UI mode
    t.window.title = "Stormworks Microcontroller Debugger"
    t.window.highdpi = true
    t.window.vsync = 1
    t.window.resizable = true
    t.window.minwidth = 800
    t.window.minheight = 600
  end
  
  t.modules.joystick = false
  t.modules.physics = false
end
