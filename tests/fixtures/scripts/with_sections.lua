---@section MyHelper
local function MyHelper()
  return "helper"
end
---@endsection

---@section UsedHelper
local function UsedHelper()
  return "used"
end
---@endsection

function onTick()
  -- MyHelper is not used, section should be removed
  -- UsedHelper is used, section should be kept
  local result = UsedHelper()
  output.setNumber(1, #result)
end
