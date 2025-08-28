-- lua/micro-project/modules/library.lua
-- Library management and LSP integration functions

local config = require("sw-micro-project.lua.modules.config")

local M = {}

--- Register libs with the lua-lsp set persist to true!
--- NOTE: Set persist to true for this to work
---
--- @param libraries table<Filepath> The top level folder paths or files to include.
--- @param opts {persist: false} A table of options
function M.register_libraries_with_lsp(libraries, opts)
  opts = opts or {}
  local persist = opts.persist or false

  if not libraries or #libraries == 0 then
    print("⚠ No libraries provided")
    return
  end

  -- find lua_ls client
  local clients = vim.lsp.get_clients({ name = "lua_ls" })
  if #clients == 0 then
    print("⚠ Lua LSP (lua_ls) not found.")
    return
  end
  local lua_client = clients[1]

  -- compute project root
  local root_dir = lua_client.config.root_dir or vim.fn.getcwd()
  local luarcf = root_dir .. "/.luarc.json"

  -- read existing .luarc.json if present
  local current_settings = {}
  local fd = io.open(luarcf, "r")
  if fd then
    local content = fd:read("*all")
    fd:close()
    local ok, decoded = pcall(vim.fn.json_decode, content)
    if ok and type(decoded) == "table" then
      current_settings = decoded
    end
  end

  -- ensure the workspace.library table exists
  current_settings["workspace.library"] = current_settings["workspace.library"] or {}

  -- merge new libraries
  for _, lib in ipairs(libraries) do
    local abs = vim.fn.fnamemodify(lib, ":p")
    local already_exists = false
    for _, existing in ipairs(current_settings["workspace.library"]) do
      if existing == abs then
        already_exists = true
        break
      end
    end
    if not already_exists then
      table.insert(current_settings["workspace.library"], abs)
    end
  end

  -- update running server
  local settings_for_server = {
    Lua = {
      workspace = {
        library = vim.tbl_map(function(p)
          return true
        end, current_settings["workspace.library"]),
        checkThirdParty = current_settings["workspace.checkThirdParty"] or false,
      },
    },
  }

  lua_client.rpc.request("workspace/didChangeConfiguration", {
    settings = settings_for_server,
  }, function(err, _)
    if err then
      print("✗ Failed to update LSP settings: " .. vim.inspect(err))
    else
      print("✓ Lua LSP workspace.library updated")
    end
  end)

  -- persist to .luarc.json if requested
  if persist then
    local ok, ferr = pcall(function()
      local fd = io.open(luarcf, "w")
      if not fd then
        error("could not open " .. luarcf .. " for writing")
      end
      fd:write(vim.fn.json_encode(current_settings))
      fd:close()
    end)
    if ok then
      print("✓ Updated .luarc.json with new library paths")
    else
      print("✗ Failed to write .luarc.json: " .. tostring(ferr))
    end
  end
end

return M
