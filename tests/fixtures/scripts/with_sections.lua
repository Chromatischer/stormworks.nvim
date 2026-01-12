---@section NotUsedFunction
local function NotUsedFunction()
  return "helper"
end
---@endsection

---@section UsedHelper
local function UsedHelper()
  return "used"
end
---@endsection

function onTick()
  local result = UsedHelper()
  output.setNumber(1, #result)
end
