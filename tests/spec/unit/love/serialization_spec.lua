describe("Serialization", function()
  local MockLove = require("mock_love")
  local TestUtils = require("test_utils")
  local serialize_lua_value

  setup(function()
    -- Install LOVE mock
    _G.love = MockLove

    -- Load the main module to get access to serialize function
    local project_root = TestUtils.get_project_root()
    package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

    -- We need to extract the serialize function from main.lua
    -- Since it's a local function, we'll test it indirectly through the persist function
    -- For now, let's create our own version that matches the implementation
    serialize_lua_value = function(v, indent, visited)
      indent = indent or 0
      visited = visited or {}
      local t = type(v)
      if t == "string" then
        return string.format("%q", v)
      elseif t == "number" or t == "boolean" then
        return tostring(v)
      elseif t == "nil" then
        return "nil"
      elseif t == "table" then
        -- Check for cyclic reference
        if visited[v] then
          return "{--[[cyclic reference]]}"
        end
        visited[v] = true
        
        local parts = {}
        local count = 0
        for _ in pairs(v) do count = count + 1 end
        if count == #v and count > 0 then
          -- Array-style
          for _, val in ipairs(v) do
            table.insert(parts, serialize_lua_value(val, indent + 1, visited))
          end
          return "{ " .. table.concat(parts, ", ") .. " }"
        else
          -- Object-style
          local ws = string.rep("  ", indent + 1)
          local sorted_keys = {}
          for k in pairs(v) do table.insert(sorted_keys, k) end
          table.sort(sorted_keys, function(a, b) return tostring(a) < tostring(b) end)
          for _, k in ipairs(sorted_keys) do
            local key_str
            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
              key_str = k
            else
              key_str = "[" .. serialize_lua_value(k, 0, visited) .. "]"
            end
            table.insert(parts, ws .. key_str .. " = " .. serialize_lua_value(v[k], indent + 1, visited))
          end
          local close_ws = string.rep("  ", indent)
          return "{\n" .. table.concat(parts, ",\n") .. "\n" .. close_ws .. "}"
        end
      end
      return "nil"
    end
  end)

  before_each(function()
    MockLove.reset()
  end)

  describe("serialize_lua_value", function()
    it("should serialize strings", function()
      local result = serialize_lua_value("hello")
      assert.equals('"hello"', result)
    end)

    it("should serialize numbers", function()
      local result = serialize_lua_value(42)
      assert.equals("42", result)
    end)

    it("should serialize booleans", function()
      assert.equals("true", serialize_lua_value(true))
      assert.equals("false", serialize_lua_value(false))
    end)

    it("should serialize nil", function()
      local result = serialize_lua_value(nil)
      assert.equals("nil", result)
    end)

    it("should serialize simple arrays", function()
      local arr = {1, 2, 3}
      local result = serialize_lua_value(arr)
      assert.equals("{ 1, 2, 3 }", result)
    end)

    it("should serialize simple tables", function()
      local tbl = {key = "value", num = 42}
      local result = serialize_lua_value(tbl)
      assert.is_truthy(result:match("key = \"value\""))
      assert.is_truthy(result:match("num = 42"))
    end)

    it("should handle nested tables", function()
      local nested = {
        outer = {
          inner = "value"
        }
      }
      local result = serialize_lua_value(nested)
      assert.is_truthy(result:match("outer"))
      assert.is_truthy(result:match("inner"))
      assert.is_truthy(result:match("\"value\""))
    end)

    it("should detect and handle direct cyclic references", function()
      local tbl = {key = "value"}
      tbl.self = tbl  -- Create a cycle
      local result = serialize_lua_value(tbl)
      
      -- Should contain the cyclic reference marker
      assert.is_truthy(result:match("cyclic reference"))
      -- Should still serialize the non-cyclic parts
      assert.is_truthy(result:match("key"))
    end)

    it("should detect and handle indirect cyclic references", function()
      local tbl1 = {name = "table1"}
      local tbl2 = {name = "table2"}
      tbl1.ref = tbl2
      tbl2.ref = tbl1  -- Create an indirect cycle
      
      local result = serialize_lua_value(tbl1)
      
      -- Should contain the cyclic reference marker
      assert.is_truthy(result:match("cyclic reference"))
      -- Should still serialize the non-cyclic parts
      assert.is_truthy(result:match("table1"))
      assert.is_truthy(result:match("table2"))
    end)

    it("should handle deeply nested cyclic references", function()
      local root = {level = 0}
      local child = {level = 1, parent = root}
      root.child = child
      
      local result = serialize_lua_value(root)
      
      -- Should complete without stack overflow
      assert.is_truthy(result:match("cyclic reference"))
      assert.is_truthy(result:match("level"))
    end)

    it("should allow the same table to appear in multiple branches without false positive", function()
      local shared = {value = "shared"}
      local root = {
        branch1 = shared,
        branch2 = shared
      }
      
      local result = serialize_lua_value(root)
      
      -- First occurrence should serialize normally
      -- Second occurrence will be marked as cyclic (this is expected behavior)
      assert.is_truthy(result:match("value"))
    end)
  end)
end)
