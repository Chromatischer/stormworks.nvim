-- Shared application state
local state = {
  -- IO channels: 32 bools, 32 numbers each for inputs and outputs
  inputB = {}, inputN = {}, outputB = {}, outputN = {},

  -- Properties (user-configurable)
  properties = {
    screenTilesX = 3,
    screenTilesY = 2,
  },

  -- Screen and canvas settings
  tileSize = 32,
  tilesX = 3,
  tilesY = 2,
  gameCanvasScale = 3, -- default integer zoom

  -- Debug canvas settings
  debugCanvasEnabled = false,
  debugCanvasW = 512,
  debugCanvasH = 512,
  debugCanvasScale = 1,

  -- Ticking
  tickRate = 60,
  running = true,
  singleStep = false,
  accumulator = 0,
  lastTickDt = 1/60,
  tickCount = 0,

  -- Paths/options
  scriptPath = nil,
  hotReload = true,
  lastMTime = 0,
  -- Whitelisted external library roots for sandboxed require (populated via --lib flags)
  libPaths = {},

  -- Logging and errors
  log = {},
  lastError = nil,
  pauseOnError = true,

  -- Fonts
  fonts = {
    ui = nil,
    mono = nil,
  },

  -- Detached viewer flags
  detached = {
    enabled = false,
    which = nil, -- 'game' or 'debug'
  },

  -- Track which settings were overridden via CLI flags so onAttatch config can respect them
  cliOverrides = {
    tiles = false,
    tick = false,
    scale = false,
    debugCanvas = false,
  },
}

for i=1,32 do
  state.inputB[i] = false
  state.outputB[i] = false
  state.inputN[i] = 0
  state.outputN[i] = 0
end

function state.getGameSize()
  return state.tilesX * state.tileSize, state.tilesY * state.tileSize
end

return state
