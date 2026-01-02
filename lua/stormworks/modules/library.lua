-- lua/micro-project/modules/library.lua
-- Library management and LSP integration functions

local config = require("stormworks.modules.config")

local M = {}

-- Compat: Neovim 0.10+ provides vim.islist; older versions use vim.tbl_islist
local fallback_is_list = function(t)
  if type(t) ~= "table" then return false end
  local maxk = 0
  local count = 0
  for k, _ in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
    if k > maxk then maxk = k end
    count = count + 1
  end
  return maxk == count
end
local is_list = vim.islist or vim.tbl_islist or fallback_is_list

--- Register libs with the lua-lsp and optionally persist to .luarc.json
--- Only modifies the "library" setting, all other settings are left untouched.
---
--- @param libraries table<string> The top level folder paths or files to include.
--- @param opts {persist: boolean} A table of options
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
  do
    local fd = io.open(luarcf, "r")
    if fd then
      local content = fd:read("*all")
      fd:close()
      local ok, decoded = pcall(vim.fn.json_decode, content)
      if ok and type(decoded) == "table" then
        current_settings = decoded
      end
    end
  end

  -- Helper: get current libraries and shape (where to write back)
  local function extract_libraries_and_shape(settings)
    -- shape can be: "Lua.map", "Lua.list", "top.list", or nil (not set)
    if type(settings.Lua) == "table"
        and type(settings.Lua.workspace) == "table"
        and type(settings.Lua.workspace.library) == "table" then
      local lib = settings.Lua.workspace.library
      if is_list(lib) then
        return vim.deepcopy(lib), "Lua.list"
      else
        -- assume map: { [path]=true }
        local list = {}
        for path, enabled in pairs(lib) do
          if enabled then table.insert(list, path) end
        end
        table.sort(list)
        return list, "Lua.map"
      end
    end

    if type(settings["workspace.library"]) == "table" then
      local lib = settings["workspace.library"]
      -- Treat as list; if map was used here (unlikely), convert like above
      if is_list(lib) then
        return vim.deepcopy(lib), "top.list"
      else
        local list = {}
        for path, enabled in pairs(lib) do
          if enabled then table.insert(list, path) end
        end
        table.sort(list)
        return list, "top.list" -- normalize to list at top
      end
    end

    return {}, nil
  end

  local existing_list, shape = extract_libraries_and_shape(current_settings)

  -- Merge new libraries as absolute paths, de-duplicated
  local seen = {}
  local merged = {}
  local function push(p)
    local abs = vim.fn.fnamemodify(p, ":p")
    if not seen[abs] then
      seen[abs] = true
      table.insert(merged, abs)
    end
  end
  for _, p in ipairs(existing_list) do push(p) end
  for _, p in ipairs(libraries) do push(p) end

  -- Build map for server update: { [path] = true }
  local lib_map = {}
  for _, p in ipairs(merged) do lib_map[p] = true end

  -- Update running server with ONLY the library field to avoid clobbering other settings
  local settings_for_server = {
    Lua = {
      workspace = {
        library = lib_map,
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

  -- Persist only the library back to .luarc.json if requested, preserving other settings
  if persist then
    -- Write back in the same shape it was found in, or choose a sensible default
    if shape == "Lua.map" then
      current_settings.Lua = current_settings.Lua or {}
      current_settings.Lua.workspace = current_settings.Lua.workspace or {}
      current_settings.Lua.workspace.library = lib_map
    elseif shape == "Lua.list" then
      current_settings.Lua = current_settings.Lua or {}
      current_settings.Lua.workspace = current_settings.Lua.workspace or {}
      current_settings.Lua.workspace.library = merged
    elseif shape == "top.list" then
      current_settings["workspace.library"] = merged
    else
      -- No prior library setting found. Prefer nesting under Lua.workspace
      current_settings.Lua = current_settings.Lua or {}
      current_settings.Lua.workspace = current_settings.Lua.workspace or {}
      current_settings.Lua.workspace.library = merged
    end

    local ok, ferr = pcall(function()
      local fdw = io.open(luarcf, "w")
      if not fdw then
        error("could not open " .. luarcf .. " for writing")
      end
      fdw:write(vim.fn.json_encode(current_settings))
      fdw:close()
    end)

    if ok then
      print("✓ Updated .luarc.json library paths (other settings unchanged)")
    else
      print("✗ Failed to write .luarc.json: " .. tostring(ferr))
    end
  end
end

return M
