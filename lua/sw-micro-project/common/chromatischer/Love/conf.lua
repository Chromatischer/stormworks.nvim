function love.conf(t)
  t.identity = "sw-mc-debugger"
  t.appendidentity = true
  t.window.title = "Stormworks Microcontroller Debugger"
  t.window.highdpi = true
  t.window.vsync = 1
  t.window.resizable = true
  t.window.minwidth = 800
  t.window.minheight = 600
  t.modules.joystick = false
  t.modules.physics = false
end
