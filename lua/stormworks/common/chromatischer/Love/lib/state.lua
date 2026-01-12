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

  -- User debug canvas settings (for onDebugDraw callbacks)
  userDebugCanvasEnabled = false,
  debugCanvasW = 512,
  debugCanvasH = 512,
  debugCanvasScale = 1,

  -- UI layer debugging (for development)
  debugOverlayEnabled = false,

  -- Pointer/touch state for canvases (updated by UI events)
  touch = {
    game = { x = 0, y = 0, left = false, right = false, inside = false },
    debug = { x = 0, y = 0, left = false, right = false, inside = false },
  },

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
  
  -- Error repetition tracking
  errorCount = 0,           -- consecutive count of current error
  errorSignature = nil,     -- normalized error signature for comparison
  maxErrorRepeats = 5,      -- threshold before auto-pause

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
    userDebug = false,
    debugOverlay = false,
  },

  -- Export feature state
  export = {
    showModal = false,
    format = "png",      -- "png" or "jpg"
    capture = "game",    -- "game", "debug", or "both"
    lastPath = nil,      -- for toast display
    lastTime = 0,
    doExport = false,    -- flag to trigger export
  },

  -- I/O Tab system
  ioTabs = {
    enabled = false,
    tabs = {},  -- { { name="all", label="All", channels=nil }, ... }
    activeInputTab = "all",
    activeOutputTab = "all",
  },

  -- Log UI state
  logUI = {
    scrollOffset = 0,      -- lines from bottom (0 = at bottom)
    autoScroll = true,     -- toggle for lock-to-bottom
    searchText = "",       -- filter pattern
    searchActive = false,  -- text input focus
    collapsedSources = {}, -- { system = false, ... }
  },

  -- Simulator tracking
  simulatorDriven = {
    inputB = {},  -- [1..32] = true if simulator controls
    inputN = {},  -- [1..32] = true if simulator controls
  },

  -- Inspector panel state
  inspector = {
    expanded = {},      -- { ["path.to.key"] = true/false }
    scrollOffset = 0,   -- vertical scroll position (lines from top)
    hideFunctions = true,   -- hide function-type globals by default
    pinnedGlobals = {},     -- {"globalName1", ...} - pinned to top
    groupByOrigin = true,   -- group globals by require() source
  },
}

for i=1,32 do
  state.inputB[i] = false
  state.outputB[i] = false
  state.inputN[i] = 0
  state.outputN[i] = 0
  state.simulatorDriven.inputB[i] = false
  state.simulatorDriven.inputN[i] = false
end

function state.getGameSize()
  return state.tilesX * state.tileSize, state.tilesY * state.tileSize
end

return state
