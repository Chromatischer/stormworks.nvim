-- lib/detach.lua
-- Implements pseudo-"detached panels" by spawning additional LÖVE processes
-- that display panel canvases from PNG frames written to the shared save dir.
-- Note: LÖVE does not support multiple OS windows in a single process as of 11.x,
-- so we use helper processes to host extra windows.

local canvases = require('lib.canvases')
local state = require('lib.state')

local detach = {
  panels = {
    game = { enabled = false, fps = 30, lastWriteTime = 0, seq = 0 },
    debug = { enabled = false, fps = 15, lastWriteTime = 0, seq = 0 },
  },
}

local function save_path(which, file)
  local base = string.format("detached/%s", which)
  if file then return base .. "/" .. file end
  return base
end

local function ensure_dirs()
  for k,_ in pairs(detach.panels) do
    love.filesystem.createDirectory(save_path(k))
  end
end

function detach.init()
  ensure_dirs()
  -- Clear old frames on start
  for which,_ in pairs(detach.panels) do
    love.filesystem.write(save_path(which, "seq.txt"), "0")
    love.filesystem.write(save_path(which, "quit.txt"), "0")
    love.filesystem.write(save_path(which, "closed.txt"), "0")
  end
end

local function write_frame(which)
  local canvas = (which == 'game') and canvases.game or canvases.debug
  if not canvas then return false end
  local imgd = canvas:newImageData()
  local filedata = imgd:encode('png')
  love.filesystem.write(save_path(which, 'frame.png'), filedata)
  -- bump sequence
  detach.panels[which].seq = detach.panels[which].seq + 1
  love.filesystem.write(save_path(which, 'seq.txt'), tostring(detach.panels[which].seq))
  return true
end

function detach.update(dt)
  local t = love.timer.getTime()
  for which,info in pairs(detach.panels) do
    -- Detect if viewer window was closed via OS (viewer writes closed.txt)
    local cinfo = love.filesystem.getInfo(save_path(which, 'closed.txt'))
    if cinfo then
      local c = love.filesystem.read(save_path(which, 'closed.txt')) or '0'
      if tostring(c):match('^%s*1') then
        if info.enabled then
          -- mirror UI X behavior: turn off detachment and resume drawing in main
          info.enabled = false
        end
        -- Reset flags/files
        love.filesystem.write(save_path(which, 'quit.txt'), '0')
        love.filesystem.write(save_path(which, 'closed.txt'), '0')
      end
    end

    if info.enabled then
      local period = 1 / (info.fps or 30)
      if (t - (info.lastWriteTime or 0)) >= period then
        if write_frame(which) then
          info.lastWriteTime = t
        end
      end
    end
  end
end

local function spawn_cmd_for_os(which)
  -- Prefer the exact source path (directory or .love), fall back to base dir
  local sourcePath = love.filesystem.getSource()
  local gamePath = sourcePath and #sourcePath > 0 and sourcePath or love.filesystem.getSourceBaseDirectory()
  local osname = love.system.getOS()
  -- We assume the user has the `love` binary available in PATH on Linux/Windows.
  -- On macOS, use `open -n -a Love` which will find the app if installed.
  local args = string.format("\"%s\" --detached %s", gamePath, which)
  if osname == 'OS X' or osname == 'OS X (iOS?)' or osname == 'iOS' or osname == 'macOS' then
    return string.format("open -n -a Love --args %s", args)
  elseif osname == 'Windows' then
    return string.format("start \"\" love %s", args)
  else -- Linux and others
    return string.format("love %s &", args)
  end
end

function detach.toggle(which)
  local p = detach.panels[which]
  if not p then return end
  p.enabled = not p.enabled
  if p.enabled then
    ensure_dirs()
    -- Write an immediate frame so the window has something to show
    write_frame(which)
    love.filesystem.write(save_path(which, 'quit.txt'), '0')
    love.filesystem.write(save_path(which, 'closed.txt'), '0')
    -- Try to spawn the helper process
    local cmd = spawn_cmd_for_os(which)
    -- os.execute is available in LÖVE; we run it async by appending suitable suffix in cmd
    os.execute(cmd)
  else
    -- Signal viewer to quit
    love.filesystem.write(save_path(which, 'quit.txt'), '1')
  end
end

function detach.is_enabled(which)
  local p = detach.panels[which]
  return p and p.enabled or false
end

function detach.panels_state()
  return detach.panels
end

return detach
