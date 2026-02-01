-- Example file demonstrating section annotations
-- This file shows the syntax highlighting for section annotations

---@section UsedHelper
local function UsedHelper()
  return "used"
end
---@endsection

---@section EXACT NotUsedFunction 1 UnusedSection
local function NotUsedFunction()
  return "helper"
end
---@endsection UnusedSection

---@section PATTERN Debug.*
function DebugPrint(msg)
  print("[DEBUG] " .. msg)
end

function DebugLog(msg)
  log(msg)
end
---@endsection

function onTick()
  local result = UsedHelper()
  output.setNumber(1, #result)
end
