-- stormworks: dynamic LuaSnip registration from VSCode-style JSON
-- This module loads snippets from ./stormworks.json and registers them
-- for the 'lua' filetype using LuaSnip's parser.

local M = {}

local function notify(msg, level)
  level = level or (vim and vim.log and vim.log.levels and vim.log.levels.INFO) or 2
  if vim and vim.notify then
    vim.notify("stormworks.snippets: " .. msg, level)
  else
    print("stormworks.snippets: " .. msg)
  end
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local c = f:read("*a")
  f:close()
  return c
end

local function json_decode(s)
  if not s then return nil end
  -- Prefer native vim.json (Neovim 0.10+), fallback to vim.fn.json_decode
  if vim and vim.json and vim.json.decode then
    return vim.json.decode(s)
  elseif vim and vim.fn and vim.fn.json_decode then
    return vim.fn.json_decode(s)
  else
    -- last-resort: try dkjson if present
    local ok, dkjson = pcall(require, "dkjson")
    if ok and dkjson then return dkjson.decode(s) end
  end
  return nil
end

local function get_json_path()
  -- This file lives at: .../snippets/snippets.lua
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  local dir = src:match("(.*/)") or ""
  return dir .. "stormworks.json"
end

--- Load snippets from JSON and register them for 'lua' filetype.
function M.load()
  local ok_ls, ls = pcall(require, "luasnip")
  if not ok_ls then
    notify("LuaSnip not found; skipping snippet load", (vim and vim.log.levels and vim.log.levels.WARN) or 3)
    return
  end

  -- Prefer parser from ls if exposed, else require util.parser.
  local parse = (ls.parser and ls.parser.parse_snippet)
    or (require("luasnip.util.parser").parse_snippet)

  local json_path = get_json_path()
  local content = read_file(json_path)
  if not content then
    notify("Could not read snippets JSON at " .. json_path, (vim and vim.log.levels and vim.log.levels.WARN) or 3)
    return
  end

  local ok, data = pcall(json_decode, content)
  if not ok or type(data) ~= "table" then
    notify("Failed to decode snippets JSON (" .. json_path .. ")", (vim and vim.log.levels and vim.log.levels.ERROR) or 1)
    return
  end

  local snippets = {}
  for name, def in pairs(data) do
    if type(def) == "table" then
      -- prefix can be string or array
      local prefixes = def.prefix
      if type(prefixes) == "string" then prefixes = { prefixes } end
      if type(prefixes) ~= "table" then prefixes = {} end

      -- body can be string or array-of-lines
      local body = def.body
      local body_str
      if type(body) == "table" then
        body_str = table.concat(body, "\n")
      elseif type(body) == "string" then
        body_str = body
      end

      local desc = def.description or name
      if body_str and #body_str > 0 then
        for _, trig in ipairs(prefixes) do
          local ok_snip, snip = pcall(parse, trig, body_str, { description = desc })
          if ok_snip and snip then
            table.insert(snippets, snip)
          else
            notify(string.format("Failed to parse snippet '%s' (trigger: %s)", name, tostring(trig)), (vim and vim.log.levels and vim.log.levels.WARN) or 3)
          end
        end
      else
        notify(string.format("Snippet '%s' has no body", name), (vim and vim.log.levels and vim.log.levels.WARN) or 3)
      end
    end
  end

  if #snippets == 0 then
    notify("No snippets parsed from JSON; nothing to add", (vim and vim.log.levels and vim.log.levels.WARN) or 3)
    return
  end

  -- Use a key so we can replace on reload without duplicates.
  ls.add_snippets("lua", snippets, { key = "stormworks" })
end

-- Optional: expose a reload function and auto-load on require.
function M.reload()
  M.load()
end

-- Auto-load once when this module is required.
M.load()

return M
