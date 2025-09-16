-- Main entry point for the Stormworks Microcontroller Debugger (LÖVE)
local state = require('lib.state')
local ui = require('lib.ui')
local canvases = require('lib.canvases')
local logger = require('lib.logger')
local sandbox = require('lib.sandbox')
local hot = require('lib.hotreload')
local detach = require('lib.detach')

local function parse_args(args)
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == '--script' and args[i+1] then
      state.scriptPath = args[i+1]; i = i + 2
    elseif a == '--detached' and args[i+1] then
      state.detached = { enabled = true, which = tostring(args[i+1]) }
      i = i + 2
    elseif a == '--tiles' and args[i+1] then
      local s = args[i+1]
      local x,y = s:match('^(%d+)%D+(%d+)$')
      state.tilesX = tonumber(x) or state.tilesX
      state.tilesY = tonumber(y) or state.tilesY
      state.properties.screenTilesX = state.tilesX
      state.properties.screenTilesY = state.tilesY
      if state.cliOverrides then state.cliOverrides.tiles = true end
      i = i + 2
    elseif a == '--tick' and args[i+1] then
      state.tickRate = tonumber(args[i+1]) or state.tickRate; if state.cliOverrides then state.cliOverrides.tick = true end; i = i + 2
    elseif a == '--scale' and args[i+1] then
      state.gameCanvasScale = tonumber(args[i+1]) or state.gameCanvasScale; if state.cliOverrides then state.cliOverrides.scale = true end; i = i + 2
    elseif a == '--debug-canvas' and args[i+1] then
      local v = tostring(args[i+1])
      state.debugCanvasEnabled = (v == 'true' or v == '1' or v == 'on')
      if state.cliOverrides then state.cliOverrides.debugCanvas = true end
      i = i + 2
    elseif a == '--props' and args[i+1] then
      local s = args[i+1]
      for key,val in s:gmatch('([^,=]+)=([^,]+)') do
        local num = tonumber(val)
        if val == 'true' or val == 'false' then
          state.properties[key] = (val == 'true')
        elseif num then
          state.properties[key] = num
        else
          state.properties[key] = val
        end
      end
      i = i + 2
    else
      i = i + 1
    end
  end
end

function love.load(args)
  love.graphics.setDefaultFilter('nearest','nearest',1)
  -- Ensure pixel-perfect lines/shapes
  if love.graphics.setLineStyle then love.graphics.setLineStyle('rough') end
  if love.graphics.setPointStyle then love.graphics.setPointStyle('rough') end
  logger.install_print_capture()
  parse_args(args or {})

  if state.detached.enabled then
    -- Detached viewer mode: display frames written by the main process
    love.window.setTitle("Stormworks Debugger — " .. tostring(state.detached.which):gsub("^%l", string.upper) .. " (Detached)")
    -- smaller minimums are fine for a single panel
    local _,_,flags = love.window.getMode()
    flags.resizable = true; flags.minwidth = 256; flags.minheight = 256
    love.window.setMode(love.graphics.getWidth(), love.graphics.getHeight(), flags)
    state._viewer = { img = nil, seq = -1, iw = 0, ih = 0 }
    -- Intercept OS window close to perform the same as clicking X in UI
    function love.quit()
      local base = 'detached/'..tostring(state.detached.which)
      love.filesystem.write(base .. '/closed.txt', '1')
      -- Returning nothing or false allows quit to proceed
    end
    print('VIEWER READY: '..state.detached.which)
    return
  end

  -- Fonts
  state.fonts.ui = love.graphics.newFont(13)
  state.fonts.mono = love.graphics.newFont(13)
  love.graphics.setFont(state.fonts.ui)

  -- Load user script before creating canvases so onAttatch() can configure sizes
  sandbox.load_script()
  canvases.recreateAll()
  hot.init(state)
  detach.init()

  print('READY')
end

local function try_tick()
  state.lastTickDt = 1/(state.tickRate>0 and state.tickRate or 60)
  local ok = sandbox.tick()
  if ok then state.tickCount = state.tickCount + 1 end
end

function love.update(dt)
  if state.detached.enabled then
    -- Poll for updated frame in detached viewer
    local base = 'detached/'..tostring(state.detached.which)
    -- Quit signal
    local qinfo = love.filesystem.getInfo(base .. '/quit.txt')
    if qinfo then
      local q = love.filesystem.read(base .. '/quit.txt') or '0'
      if tostring(q):match('^%s*1') then love.event.quit() return end
    end
    if love.filesystem.getInfo(base .. '/seq.txt') then
      local s = love.filesystem.read(base .. '/seq.txt') or "-1"
      local seq = tonumber(s) or -1
      if seq ~= state._viewer.seq then
        state._viewer.seq = seq
        local data = love.filesystem.read(base .. '/frame.png')
        if data then
          local fileData = love.filesystem.newFileData(data, 'frame.png')
          local imgData = love.image.newImageData(fileData)
          state._viewer.iw, state._viewer.ih = imgData:getWidth(), imgData:getHeight()
          state._viewer.img = love.graphics.newImage(imgData)
          state._viewer.img:setFilter('nearest','nearest')
        end
      end
    end
    return
  end
  -- Hot reload check
  if state.hotReload and hot.update(state, dt) then
    local ok = sandbox.reload()
    if ok then
      canvases.recreateAll()
    end
  end

  local step_dt = 1 / (state.tickRate>0 and state.tickRate or 60)
  if state.running then
    state.accumulator = state.accumulator + dt
    local guard = 0
    while state.accumulator >= step_dt and guard < 10 do
      try_tick()
      state.accumulator = state.accumulator - step_dt
      guard = guard + 1
    end
  elseif state.singleStep then
    try_tick()
    state.singleStep = false
  end
end

function love.draw()
  if state.detached.enabled then
    love.graphics.clear(0.08,0.08,0.09,1)
    local img = state._viewer and state._viewer.img
    if img then
      local iw, ih = state._viewer.iw, state._viewer.ih
      local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
      -- integer scale clamp 1..8
      local sx = math.floor(math.min(8, math.max(1, math.floor(ww / iw))))
      local sy = math.floor(math.min(8, math.max(1, math.floor(wh / ih))))
      local scale = math.max(1, math.min(sx, sy))
      local dx = math.floor((ww - iw*scale)/2)
      local dy = math.floor((wh - ih*scale)/2)
      love.graphics.setColor(1,1,1,1)
      love.graphics.draw(img, dx, dy, 0, scale, scale)
    else
      love.graphics.setColor(1,1,1,0.6)
      love.graphics.print('Waiting for '..tostring(state.detached.which)..' frame…', 16, 16)
    end
    return
  end
  love.graphics.clear(0.1,0.1,0.11,1)
  local w,h = love.graphics.getWidth(), love.graphics.getHeight()
  ui.layout(w,h)
  ui.draw_toolbar()
  -- If panels are detached, don't draw them in the main window
  if not detach.is_enabled('inputs') then ui.draw_inputs() end

  -- Game canvas draw
  local gamePanel = ui.draw_game_canvas()
  canvases.ensure()
  if not ui.minimized.game then
    -- Render to game canvas by calling user onDraw
    local canvas_prev = love.graphics.getCanvas()
    love.graphics.setCanvas()
    love.graphics.setColor(1,1,1,1)
    -- Draw game canvas content
    canvases.withTarget('game', function(api)
      api.clear(0,0,0,255)
      -- Provide screen.* API during onDraw
      if sandbox.env and type(sandbox.env.onDraw) == 'function' then
        local ok, err = xpcall(sandbox.env.onDraw, debug.traceback)
        if not ok then
          logger.append('[error] onDraw: '..tostring(err))
          state.lastError = err
          if state.pauseOnError then state.running = false end
        end
      end
    end)
    love.graphics.setCanvas(canvas_prev)
    love.graphics.push()
    love.graphics.translate(gamePanel.x, gamePanel.y)
    canvases.drawToScreen({x=0,y=0}, 'game')
    love.graphics.pop()
  end

  -- Debug canvas
  if state.debugCanvasEnabled and not detach.is_enabled('debug') then
    local dbgPanel = ui.draw_debug_canvas_center()
    if not ui.minimized.debug then
      local canvas_prev = love.graphics.getCanvas()
      love.graphics.setCanvas()
      canvases.withTarget('debug', function(api)
        api.clear(0,0,0,255)
        if sandbox.env and type(sandbox.env.onDebugDraw) == 'function' then
          local ok, err = xpcall(sandbox.env.onDebugDraw, debug.traceback)
          if not ok then
            logger.append('[error] onDebugDraw: '..tostring(err))
          end
        end
      end)
      love.graphics.setCanvas(canvas_prev)
      if dbgPanel and dbgPanel.x then
        love.graphics.push(); love.graphics.translate(dbgPanel.x, dbgPanel.y)
        canvases.drawToScreen({x=0,y=0}, 'debug')
        love.graphics.pop()
      end
    end
  end

  if not ui.mergedOutputs and not detach.is_enabled('outputs') then ui.draw_outputs() end
  ui.draw_log(logger)

  if state.lastError then
    love.graphics.setColor(0.8,0.2,0.2,1)
    love.graphics.print('ERROR: '..tostring(state.lastError), 16, 48)
  end

  -- Update detached frame writers after rendering
  detach.update()
end

function love.keypressed(key)
  if state.detached.enabled then
    if key == 'escape' then love.event.quit() end
    return
  end
  if key == 'space' then state.running = not state.running
  elseif key == 'n' then state.singleStep = true
  elseif key == 'r' then local ok = sandbox.reload(); if ok then canvases.recreateAll() end
  elseif key == '=' or key == '+' then state.gameCanvasScale = math.min(8, state.gameCanvasScale+1)
  elseif key == '-' then state.gameCanvasScale = math.max(1, state.gameCanvasScale-1)
  elseif key == 'd' then state.debugCanvasEnabled = not state.debugCanvasEnabled; canvases.recreateAll()
  elseif key == 'f5' then detach.toggle('game')
  elseif key == 'f6' then if not state.debugCanvasEnabled then state.debugCanvasEnabled = true; canvases.recreateAll() end; detach.toggle('debug')
  end
end

function love.mousepressed(x,y,button)
  if ui.mousepressed then ui.mousepressed(x,y,button) end
end
function love.mousereleased(x,y,button)
  if ui.mousereleased then ui.mousereleased(x,y,button) end
end
function love.mousemoved(x,y,dx,dy)
  if ui.mousemoved then ui.mousemoved(x,y,dx,dy) end
end
function love.wheelmoved(dx,dy)
  if ui.wheelmoved then ui.wheelmoved(dx,dy) end
end

-- Clamp excessive window sizes and enforce minimums to keep layouts sensible
local MAIN_MIN_W, MAIN_MIN_H = 800, 600
local MAIN_MAX_W, MAIN_MAX_H = 2560, 1600 -- "reasonable" upper bounds
local function clamp_window_dimensions(w,h, minw,minh, maxw,maxh)
  w = math.max(minw, math.min(maxw, w))
  h = math.max(minh, math.min(maxh, h))
  return w,h
end

function love.resize(w, h)
  if state._resizing_guard then return end
  if state.detached and state.detached.enabled then
    -- Detached viewer: limit to 1..8x of canvas size plus margin
    local iw, ih = 128, 128
    if state._viewer and state._viewer.iw and state._viewer.iw > 0 then
      iw, ih = state._viewer.iw, state._viewer.ih
    elseif state.detached.which == 'game' then
      iw, ih = state.tilesX*state.tileSize, state.tilesY*state.tileSize
    elseif state.detached.which == 'debug' then
      iw, ih = state.debugCanvasW, state.debugCanvasH
    end
    local minw, minh = math.max(256, iw+64), math.max(256, ih+64)
    local maxw, maxh = iw*8 + 64, ih*8 + 64
    local cw, ch = clamp_window_dimensions(w,h, minw,minh, maxw,maxh)
    if cw ~= w or ch ~= h then
      state._resizing_guard = true
      local _,_,flags = love.window.getMode()
      love.window.setMode(cw, ch, flags)
      state._resizing_guard = false
    end
    return
  end

  -- Main window clamp
  local cw, ch = clamp_window_dimensions(w,h, MAIN_MIN_W, MAIN_MIN_H, MAIN_MAX_W, MAIN_MAX_H)
  if cw ~= w or ch ~= h then
    state._resizing_guard = true
    local _,_,flags = love.window.getMode()
    love.window.setMode(cw, ch, flags)
    state._resizing_guard = false
  end
end
