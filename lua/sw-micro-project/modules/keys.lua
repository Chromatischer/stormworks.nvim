-- lua/sw-micro-project/modules/keys.lua
-- Optional which-key integration and default keymaps

local M = {}

local config = require("sw-micro-project.modules.config")
local project = require("sw-micro-project.modules.project")
local love_runner = require("sw-micro-project.modules.love_runner")

-- Register default keymaps under <leader>S (configurable)
function M.register_keymaps()
  local cfg = config.config or {}
  if cfg.enable_keymaps == false then
    return
  end

  local prefix = cfg.which_key_prefix or "<leader>S"
  local km = cfg.keymaps or {}

  -- Helper to set normal mode mapping with description
  local function nmap(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { silent = true, noremap = true, desc = desc })
  end

  -- Concrete actions map to commands to reuse existing logic
  if km.mark ~= false and km.mark then
    nmap(prefix .. km.mark, function()
      vim.cmd("MicroProject mark")
    end, "MicroProject: Mark project")
  end

  if km.setup ~= false and km.setup then
    nmap(prefix .. km.setup, function()
      vim.cmd("MicroProject setup")
    end, "MicroProject: Setup libraries")
  end

  if km.build ~= false and km.build then
    nmap(prefix .. km.build, function()
      vim.cmd("MicroProject build")
    end, "MicroProject: Build project")
  end

  if km.here ~= false and km.here then
    nmap(prefix .. km.here, function()
      vim.cmd("MicroProject here")
    end, "MicroProject: Build current file")
  end

  if km.ui ~= false and km.ui then
    nmap(prefix .. km.ui, function()
      -- Ensure project libs from .microproject are applied, then run UI using module API
      local ok_detect, marker = pcall(project.detect_micro_project)
      if ok_detect and marker then
        pcall(project.setup_project_libraries)
      end
      -- Run via API so it picks up config.project_libs and current_project.config.libraries
      love_runner.run_current_script({})
    end, "MicroProject: Run with LÖVE")
  end

  if km.add ~= false and km.add then
    nmap(prefix .. km.add, function()
      vim.ui.input({ prompt = "MicroProject: Add library path: " }, function(input)
        if input and #input > 0 then
          local arg = vim.fn.fnameescape(input)
          vim.cmd("MicroProject add " .. arg)
        end
      end)
    end, "MicroProject: Add library")
  end

  -- Optional which-key registration for nicer popups
  local ok, wk = pcall(require, "which-key")
  if ok then
    local spec = { { prefix, group = "MicroProject" } }
    if km.add ~= false and km.add then
      table.insert(spec, { prefix .. km.add, desc = "Add library" })
    end
    if km.build ~= false and km.build then
      table.insert(spec, { prefix .. km.build, desc = "Build project" })
    end
    if km.here ~= false and km.here then
      table.insert(spec, { prefix .. km.here, desc = "Build current file" })
    end
    if km.mark ~= false and km.mark then
      table.insert(spec, { prefix .. km.mark, desc = "Mark project" })
    end
    if km.setup ~= false and km.setup then
      table.insert(spec, { prefix .. km.setup, desc = "Setup libraries" })
    end
    if km.ui ~= false and km.ui then
      table.insert(spec, { prefix .. km.ui, desc = "Run with LÖVE" })
    end

    -- Prefer which-key v3 API (add); fallback to v2 (register)
    if type(wk.add) == "function" then
      wk.add(spec)
    else
      local group = { name = "MicroProject" }
      if km.add ~= false and km.add then
        group[km.add] = "Add library"
      end
      if km.build ~= false and km.build then
        group[km.build] = "Build project"
      end
      if km.here ~= false and km.here then
        group[km.here] = "Build current file"
      end
      if km.mark ~= false and km.mark then
        group[km.mark] = "Mark project"
      end
      if km.setup ~= false and km.setup then
        group[km.setup] = "Setup libraries"
      end
      if km.ui ~= false and km.ui then
        group[km.ui] = "Run with LÖVE"
      end
      wk.register({ [prefix] = group })
    end
  end
end

return M
