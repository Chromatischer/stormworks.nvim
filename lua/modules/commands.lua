-- lua/micro-project/modules/commands.lua
-- Command creation and user interface functions

local config = require("sw-micro-project.lua.modules.config")
local project = require("sw-micro-project.lua.modules.project")
local build = require("sw-micro-project.lua.modules.build")
local love_runner = require("sw-micro-project.lua.modules.love_runner")

local M = {}

-- Create unified command with subcommands
function M.create_commands()
  vim.api.nvim_create_user_command("MicroProject", function(opts)
    local subcommand = opts.fargs[1]

    if subcommand == "mark" then
      project.mark_as_micro_project()
    elseif subcommand == "setup" then
      project.setup_project_libraries()
    elseif subcommand == "build" then
      build.build_micro_project()
    elseif subcommand == "here" then
      build.build_micro_project(string.gsub(vim.api.nvim_buf_get_name(0), vim.loop.cwd(), ""))
    elseif subcommand == "add" then
      if opts.fargs[2] then
        project.add_library(opts.fargs[2])
      else
        print("Usage: :MicroProject add <library_path>")
      end
    elseif subcommand == "ui" then
      -- Run current buffer with the LÖVE2D UI
      -- Accept optional flags like: --tiles 3x2 --tick 60 --scale 3 --debug-canvas true --props k=v,k2=v2
      local args = opts.fargs
      local i = 2
      local runopts = {}
      while i <= #args do
        local a = args[i]
        local v = args[i+1]
        if a == "--tiles" and v then runopts.tiles = v; i = i + 2
        elseif a == "--tick" and v then runopts.tick = tonumber(v) or v; i = i + 2
        elseif a == "--scale" and v then runopts.scale = tonumber(v) or v; i = i + 2
        elseif a == "--debug-canvas" and v then
          local s = tostring(v)
          runopts.debug_canvas = (s == "true" or s == "1" or s == "on")
          i = i + 2
        elseif a == "--props" and v then runopts.props = v; i = i + 2
        else i = i + 1 end
      end
      love_runner.run_current_script(runopts)
    else
      print("Available subcommands:")
      print("  :MicroProject mark     - Mark current directory as microcontroller project")
      print("  :MicroProject setup    - Setup project libraries")
      print("  :MicroProject build    - Build the project")
      print("  :MicroProject here     - Build the current file only")
      print("  :MicroProject add <path> - Add library to project")
      print("  :MicroProject ui [--tiles 3x2] [--tick 60] [--scale 3] [--debug-canvas true] [--props k=v,k2=v2] - Run current script in LÖVE2D UI")
    end
  end, {
    nargs = "*",
    complete = function(_, line, _)
      local parts = vim.split(line, "%s+")

      -- Complete subcommands
      if #parts <= 2 then
        local subcommands = { "mark", "setup", "build", "add", "here", "ui" }
        local partial = parts[2] or ""
        return vim.tbl_filter(function(cmd)
          return cmd:find("^" .. partial)
        end, subcommands)
      end

      -- Complete directory paths for "add" subcommand
      if parts[2] == "add" and #parts == 3 then
        return vim.fn.getcompletion(parts[3] or "", "dir")
      end

      -- Basic flag completion for ui
      if parts[2] == "ui" then
        local flags = { "--tiles", "--tick", "--scale", "--debug-canvas", "--props" }
        local partial = parts[#parts] or ""
        return vim.tbl_filter(function(f)
          return f:find("^" .. vim.pesc(partial))
        end, flags)
      end

      return {}
    end,
  })
end

-- Setup auto-detection of projects
function M.setup_autodetection()
  local aug = vim.api.nvim_create_augroup("MyLspFirstAttach", {})

  -- Auto-detect projects when entering directories
  if config.config.auto_detect then
    vim.api.nvim_create_autocmd({ "LspAttach" }, {
      group = aug,
      once = true,
      callback = function()
        print("Executing autocmd")
        local marker_path = project.detect_micro_project()
        if marker_path then
          print("Marker found!")
          project.setup_project_libraries()
        end
      end,
    })
  end
end

return M
