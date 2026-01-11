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
---@section MyFunc
function MyFunc()
  return "test"
end
---@endsection

function onTick()
  -- MyFunc is not used
  output.setNumber(1, 42)
end
]]

      local output = remover:removeRedundantCode(input)

      TestUtils.assert_not_contains(output, "MyFunc")
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
---@section UnusedFunc
function UnusedFunc() end
---@endsection

---@section UsedFunc
function UsedFunc() end
---@endsection

function onTick()
  UsedFunc()
end
]]

      local output = remover:removeRedundantCode(input)

      TestUtils.assert_not_contains(output, "UnusedFunc")
      TestUtils.assert_contains(output, "UsedFunc")
    end)

    it("should handle section with count parameter", function()
      local remover = remover_class:new()
      local input = [[
---@section Helper 2
function Helper() return 1 end
---@endsection

function onTick()
  Helper()  -- Only used once, needs 2+ uses
end
]]

      local output = remover:removeRedundantCode(input)

      -- Should remove because Helper is used only 1 time, but needs 2
      TestUtils.assert_not_contains(output, "Helper")
    end)
  end)
end)
