describe("RedundancyRemover", function()
  local TestUtils = require("test_utils")
  local remover_class

  setup(function()
    TestUtils.setup_lifeboat()
    require("stormworks.common.nameouschangey.Common.LifeBoatAPI.Tools.Build.RedundancyRemover")
    remover_class = LifeBoatAPI.Tools.RedundancyRemover
  end)

  describe("removeRedundantCode", function()
    it("should remove unused section", function()
      local remover = remover_class:new()
      local input = [[
---@section UnusedFunc
function UnusedFunc()
  return "test"
end
---@endsection

function onTick()
  output.setNumber(1, 42)
end
]]

      local output = remover:removeRedundantCode(input)

      -- The UnusedFunc section should be removed since the function isn't called
      TestUtils.assert_not_contains(output, "UnusedFunc")
      TestUtils.assert_contains(output, "onTick")
    end)

    it("should keep used section", function()
      local remover = remover_class:new()
      local input = [[
---@section UsedFunc
function UsedFunc()
  return "test"
end
---@endsection

function onTick()
  local result = UsedFunc()
  output.setNumber(1, #result)
end
]]

      local output = remover:removeRedundantCode(input)

      TestUtils.assert_contains(output, "UsedFunc")
      TestUtils.assert_contains(output, "onTick")
    end)

    it("should handle multiple sections", function()
      local remover = remover_class:new()
      local input = [[
---@section NotUsed
function NotUsed() end
---@endsection

---@section IsUsed
function IsUsed() end
---@endsection

function onTick()
  IsUsed()
end
]]

      local output = remover:removeRedundantCode(input)

      TestUtils.assert_not_contains(output, "NotUsed")
      TestUtils.assert_contains(output, "IsUsed")
    end)

    it("should handle section with count parameter", function()
      local remover = remover_class:new()
      local input = [[
---@section Func 2
function Func() return 1 end
---@endsection

function onTick()
  Func()
end
]]

      local output = remover:removeRedundantCode(input)

      -- Should remove because Func is used only 1 time, but needs 2
      TestUtils.assert_not_contains(output, "---@section")
    end)
  end)

  describe("object-like structures", function()
    it("should remove unused method from object", function()
      local remover = remover_class:new()
      local input = [[
MyObject = {
  ---@section unusedMethod
  unusedMethod = function(self)
    return "test"
  end,
  ---@endsection

  usedMethod = function(self)
    return "other"
  end,
}

function onTick()
  MyObject.usedMethod()
end
]]

      local output = remover:removeRedundantCode(input)

      TestUtils.assert_not_contains(output, "unusedMethod")
      TestUtils.assert_contains(output, "usedMethod")
      TestUtils.assert_contains(output, "MyObject")
      -- Verify resulting code is valid Lua
      local valid, err = TestUtils.is_valid_lua(output)
      assert(valid, "Output should be valid Lua: " .. (err or ""))
    end)

    it("should keep method called with dot notation", function()
      local remover = remover_class:new()
      local input = [[
MyObject = {
  ---@section usedMethod
  usedMethod = function(self)
    return "test"
  end,
  ---@endsection
}

function onTick()
  MyObject.usedMethod()
end
]]

      local output = remover:removeRedundantCode(input)

      TestUtils.assert_contains(output, "usedMethod")
      TestUtils.assert_contains(output, "MyObject")
    end)

    it("should keep method called with colon notation", function()
      local remover = remover_class:new()
      local input = [[
MyObject = {
  ---@section usedMethod
  usedMethod = function(self)
    return "test"
  end,
  ---@endsection
}

function onTick()
  MyObject:usedMethod()
end
]]

      local output = remover:removeRedundantCode(input)

      TestUtils.assert_contains(output, "usedMethod")
      TestUtils.assert_contains(output, "MyObject")
    end)

    it("should handle multiple sections in object with mixed usage", function()
      local remover = remover_class:new()
      local input = [[
MyObject = {
  ---@section methodA
  methodA = function(self)
    return "a"
  end,
  ---@endsection

  ---@section methodB
  methodB = function(self)
    return "b"
  end,
  ---@endsection

  ---@section methodC
  methodC = function(self)
    return "c"
  end,
  ---@endsection
}

function onTick()
  MyObject.methodA()
  MyObject:methodC()
end
]]

      local output = remover:removeRedundantCode(input)

      TestUtils.assert_contains(output, "methodA")
      TestUtils.assert_not_contains(output, "methodB")
      TestUtils.assert_contains(output, "methodC")
      -- Verify resulting code is valid Lua
      local valid, err = TestUtils.is_valid_lua(output)
      assert(valid, "Output should be valid Lua: " .. (err or ""))
    end)

    it("should handle object method at end without trailing comma", function()
      local remover = remover_class:new()
      local input = [[
MyObject = {
  usedMethod = function(self)
    return "other"
  end,
  ---@section unusedMethod
  unusedMethod = function(self)
    return "test"
  end
  ---@endsection
}

function onTick()
  MyObject.usedMethod()
end
]]

      local output = remover:removeRedundantCode(input)

      TestUtils.assert_not_contains(output, "unusedMethod")
      TestUtils.assert_contains(output, "usedMethod")
      -- Verify resulting code is valid Lua (trailing comma is allowed)
      local valid, err = TestUtils.is_valid_lua(output)
      assert(valid, "Output should be valid Lua: " .. (err or ""))
    end)

    it("should handle nested objects with sections", function()
      local remover = remover_class:new()
      local input = [[
Parent = {
  Child = {
    ---@section nestedUnused
    nestedUnused = function()
      return "unused"
    end,
    ---@endsection

    ---@section nestedUsed
    nestedUsed = function()
      return "used"
    end,
    ---@endsection
  },
}

function onTick()
  Parent.Child.nestedUsed()
end
]]

      local output = remover:removeRedundantCode(input)

      TestUtils.assert_not_contains(output, "nestedUnused")
      TestUtils.assert_contains(output, "nestedUsed")
      local valid, err = TestUtils.is_valid_lua(output)
      assert(valid, "Output should be valid Lua: " .. (err or ""))
    end)
  end)
end)
