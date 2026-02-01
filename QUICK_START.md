# Quick Start: Section Annotations

## Tab Completion

### Usage

Type a trigger and press Tab to expand:

| Trigger | Result |
|---------|--------|
| `@sec` | Simple section with identifier only |
| `@section` or `section` | Full section with all parameters |
| `@endsection` or `endsection` | Standalone end tag |

### Example Workflow

1. Type `@sec` and press Tab
2. Enter identifier name (e.g., `DebugHelper`)
3. Press Tab to move to code body
4. Write your code
5. Press Tab to complete

Result:
```lua
---@section DebugHelper
-- your code here
---@endsection
```

### Full Section Example

1. Type `@section` and press Tab
2. Use Ctrl+N/Ctrl+P to select EXACT or PATTERN
3. Tab through: Identifier → count → SectionName
4. Write your code
5. SectionName is automatically mirrored to end tag

Result:
```lua
---@section EXACT MyFunction 1 OptionalName
-- your code here
---@endsection OptionalName
```

## Syntax Highlighting

Section annotations are automatically highlighted differently from regular comments:

```lua
-- This is a regular comment (standard Comment highlight)

---@section Helper
-- This entire line uses SpecialComment highlight
local function Helper()
  return "value"
end
---@endsection
-- This line also uses SpecialComment highlight
```

### Color Customization

To customize colors, add to your Neovim config:

```lua
vim.api.nvim_set_hl(0, 'StormworksSection', { fg = '#ff9800', bold = true })
vim.api.nvim_set_hl(0, 'StormworksEndSection', { fg = '#ff9800', bold = true })
```

Or link to different highlight groups:

```lua
vim.api.nvim_set_hl(0, 'StormworksSection', { link = 'PreProc' })
vim.api.nvim_set_hl(0, 'StormworksEndSection', { link = 'PreProc' })
```

## Annotation Format Reference

```
---@section [EXACT|PATTERN] Identifier [count] [SectionName]
-- code to conditionally remove
---@endsection [SectionName]
```

### Parameters

- **EXACT/PATTERN** (optional): Match mode for identifier
- **Identifier** (required): Function/variable name or pattern
- **count** (optional): Number of occurrences
- **SectionName** (optional): Named section for matching start/end

### Examples

Simple identifier:
```lua
---@section MyFunction
local function MyFunction() end
---@endsection
```

Exact match:
```lua
---@section EXACT MyFunction
local function MyFunction() end
---@endsection
```

Pattern match:
```lua
---@section PATTERN Debug.*
function DebugPrint() end
function DebugLog() end
---@endsection
```

Named section:
```lua
---@section EXACT MyFunction 1 OptionalHelpers
local function MyFunction() end
---@endsection OptionalHelpers
```

## Build Integration

Sections are processed during build by the redundancy removal system. Unused sections (based on identifier matching) are automatically removed from the final build output.

See `tests/fixtures/scripts/with_sections.lua` for working examples.
