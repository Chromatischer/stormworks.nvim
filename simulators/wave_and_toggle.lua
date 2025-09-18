
-- Example simulator: sine wave + toggle
-- Save as simulators/wave_and_toggle.lua under your script folder or a --lib root
-- Usage in onAttatch:
--   return { input_simulator = require('simulators.wave_and_toggle'), input_simulator_config = { amplitude=1, freq_hz=0.5, target_num=1, target_bool=1 } }
local M = {
  t = 0,
  A = 1,
  f = 0.5,
  chN = 1,
  chB = 1,
  phase = 0,
}

function M.onInit(ctx, cfg)
  if cfg then
    M.A = tonumber(cfg.amplitude) or M.A
    M.f = tonumber(cfg.freq_hz) or M.f
    M.chN = tonumber(cfg.target_num) or M.chN
    M.chB = tonumber(cfg.target_bool) or M.chB
  end
end

function M.onTick(ctx)
  local dt = ctx.time.getDelta()
  M.t = M.t + dt
  local s = 0.5 + 0.5 * math.sin(2*math.pi*M.f*M.t + M.phase)
  local v = math.max(0, math.min(1, M.A * s))
  ctx.input.setNumber(M.chN, v)
  ctx.input.setBool(M.chB, (math.floor(M.t * 1) % 2) == 0)
end

function M.onDebugDraw()
  dbg.setColor(0,255,0)
  local w = dbg.getWidth()
  local h = dbg.getHeight()
  local mid = h/2
  local lastY
  for x=0,w-1 do
    local t = (M.t + x/60)
    local s = 0.5 + 0.5 * math.sin(2*math.pi*M.f*t)
    local y = mid + (s-0.5) * (h*0.8)
    if lastY then dbg.drawLine(x-1, lastY, x, y) end
    lastY = y
  end
end

return M
