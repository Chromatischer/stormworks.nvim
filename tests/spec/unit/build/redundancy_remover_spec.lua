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
end)
