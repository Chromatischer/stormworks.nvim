local state = require('lib.state')
local ui = require('lib.ui')
local canvases = require('lib.canvases')
local logger = require('lib.logger')
local sandbox = require('lib.sandbox')
local storm = require('lib.storm_api')
local hot = require('lib.hotreload')

local function parse_args(args)
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == '--script' and args[i+1] then
      state.scriptPath = args[i+1]; i = i + 2
    elseif a == '--tiles' and args[i+1] then
      local s = args[i+1]
      local x,y = s:match('^(%d+)%D+(%d+)$')
      state.tilesX = tonumber(x) or state.tilesX
      state.tilesY = tonumber(y) or state.tilesY
      state.properties.screenTilesX = state.tilesX
      state.properties.screenTilesY = state.tilesY
      i = i + 2
    elseif a == '--tick' and args[i+1] then
      state.tickRate = tonumber(args[i+1]) or state.tickRate; i = i + 2
    elseif a == '--scale' and args[i+1] then
      state.gameCanvasScale = tonumber(args[i+1]) or state.gameCanvasScale; i = i + 2
    elseif a == '--debug-canvas' and args[i+1] then
      local v = tostring(args[i+1])
      state.debugCanvasEnabled = (v == 'true' or v == '1' or v == 'on')
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

  -- Fonts
  state.fonts.ui = love.graphics.newFont(13)
  state.fonts.mono = love.graphics.newFont(13)
  love.graphics.setFont(state.fonts.ui)

  canvases.recreateAll()
  sandbox.load_script()
  hot.init(state)

  print('READY')
end

local function try_tick()
  state.lastTickDt = 1/(state.tickRate>0 and state.tickRate or 60)
  local ok = sandbox.tick()
  if ok then state.tickCount = state.tickCount + 1 end
end

function love.update(dt)
  -- Hot reload check
  if state.hotReload and hot.update(state, dt) then
    sandbox.reload()
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
  love.graphics.clear(0.1,0.1,0.11,1)
  local w,h = love.graphics.getWidth(), love.graphics.getHeight()
  ui.layout(w,h)
  ui.draw_toolbar()
  ui.draw_inputs()

  -- Game canvas draw
  local gamePanel = ui.draw_game_canvas()
  canvases.ensure()
  -- Render to game canvas by calling user onDraw
  canvas_prev = love.graphics.getCanvas()
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

  -- Debug canvas
  if state.debugCanvasEnabled then
    local dbgPanel = ui.draw_debug_canvas_center()
    canvas_prev = love.graphics.getCanvas()
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

  ui.draw_outputs()
  ui.draw_log(logger)

  if state.lastError then
    love.graphics.setColor(0.8,0.2,0.2,1)
    love.graphics.print('ERROR: '..tostring(state.lastError), 16, 48)
  end
end

function love.keypressed(key)
  if key == 'space' then state.running = not state.running
  elseif key == 'n' then state.singleStep = true
  elseif key == 'r' then sandbox.reload()
  elseif key == '=' or key == '+' then state.gameCanvasScale = math.min(8, state.gameCanvasScale+1)
  elseif key == '-' then state.gameCanvasScale = math.max(1, state.gameCanvasScale-1)
  elseif key == 'd' then state.debugCanvasEnabled = not state.debugCanvasEnabled; canvases.recreateAll()
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
