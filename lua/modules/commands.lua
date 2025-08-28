-- lua/micro-project/modules/commands.lua
-- Command creation and user interface functions

local config = require("sw-micro-project.lua.modules.config")
local project = require("sw-micro-project.lua.modules.project")
local build = require("sw-micro-project.lua.modules.build")

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
    else
      print("Available subcommands:")
      print("  :MicroProject mark     - Mark current directory as microcontroller project")
      print("  :MicroProject setup    - Setup project libraries")
      print("  :MicroProject build    - Build the project")
      print("  :MicroProject here     - Build the current file only")
      print("  :MicroProject add <path> - Add library to project")
    end
  end, {
    nargs = "*",
    complete = function(_, line, _)
      local parts = vim.split(line, "%s+")

      -- Complete subcommands
      if #parts <= 2 then
        local subcommands = { "mark", "setup", "build", "add", "here" }
        local partial = parts[2] or ""
        return vim.tbl_filter(function(cmd)
          return cmd:find("^" .. partial)
        end, subcommands)
      end

      -- Complete directory paths for "add" subcommand
      if parts[2] == "add" and #parts == 3 then
        return vim.fn.getcompletion(parts[3] or "", "dir")
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
    --TODO: Fix autocmd not firering at the correct time!
    --This autocmd should fire after the LSP has initialized for the first time for this project
    vim.api.nvim_create_autocmd({ "LspAttach" }, {
      group = aug,
      once = true,
      callback = function()
        vim.notify("Ms")
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
