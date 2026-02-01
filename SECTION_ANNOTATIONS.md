# Section Annotation Features

This document describes the tab completion and syntax highlighting features for section annotations.

## Features Implemented

### 1. Tab Completion (LuaSnip Snippets)

The plugin provides three snippet variants for section annotations:

#### Full Section (`@section` or `section`)
```lua
---@section EXACT|PATTERN Identifier count SectionName
-- code to conditionally remove
---@endsection SectionName
```

Features:
- Choice node for EXACT/PATTERN
- Tabstop navigation for all parameters
- Mirrored SectionName between start and end tags

#### Simple Section (`@sec`)
```lua
---@section Identifier
-- code to conditionally remove
---@endsection
```

Features:
- Quick insertion with just an identifier
- Tabstop for code body

#### Standalone End Section (`@endsection` or `endsection`)
```lua
---@endsection SectionName
```

### 2. Syntax Highlighting

Section annotations are highlighted differently from regular comments using TreeSitter queries:

- `---@section` lines use the `StormworksSection` highlight group
- `---@endsection` lines use the `StormworksEndSection` highlight group
- Both are linked to `SpecialComment` for theme compatibility

#### Fallback Support

For environments without TreeSitter, a fallback using `matchadd()` is provided in `ftplugin/lua.lua`.

## Usage

### Tab Completion

1. Open a Lua file in your Stormworks project
2. Type one of the snippet triggers:
   - `@section` or `section` - Full section with all parameters
   - `@sec` - Simple section with identifier only
   - `@endsection` or `endsection` - Standalone end tag
3. Press Tab to expand the snippet
4. Use Tab/Shift+Tab to navigate between fields
5. For the full section snippet, use Ctrl+N/Ctrl+P to choose between EXACT/PATTERN

### Syntax Highlighting

Syntax highlighting is applied automatically when you open Lua files. The highlights will:

- Persist across colorscheme changes
- Work with all standard Neovim colorschemes
- Use TreeSitter when available, fallback to matchadd otherwise

## Files

### Created Files

1. **`lua/stormworks/snippets/stormworks.json`**
   - JSON snippet definitions
   - Loaded automatically by existing snippet loader

2. **`after/queries/lua/highlights.scm`**
   - TreeSitter query file
   - Extends Lua highlighting with section annotation patterns

3. **`plugin/highlights.lua`**
   - Defines highlight groups
   - Sets up ColorScheme autocmd for persistence

4. **`ftplugin/lua.lua`**
   - Fallback highlighting when TreeSitter unavailable
   - Uses vim.fn.matchadd()

### Integration

The features integrate seamlessly with existing plugin infrastructure:

- Snippets are loaded by `lua/stormworks/snippets/snippets.lua`
- No changes needed to `lua/stormworks/init.lua`
- Build system continues working as before

## Testing

### Manual Testing

1. **Completion**:
   - Open a Lua file
   - Type `@sec` and press Tab
   - Verify snippet expands
   - Test Tab navigation
   - Test all three snippet variants

2. **Highlighting**:
   - Create a file with section annotations
   - Verify visual differentiation from regular comments
   - Test with multiple colorschemes (`:colorscheme <name>`)
   - Verify highlights persist after colorscheme changes

3. **Build Integration**:
   - Use test file: `tests/fixtures/scripts/with_sections.lua`
   - Run build process with redundancy removal
   - Verify sections are correctly processed

### Automated Testing

The existing redundancy remover tests continue to pass:

```bash
cd tests
busted spec/unit/build/redundancy_remover_spec.lua
```

Result: ✅ 4 successes / 0 failures / 0 errors / 0 pending

## Example

```lua
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

function onTick()
  local result = UsedHelper()
  output.setNumber(1, #result)
end
```

After build with redundancy removal, the `NotUsedFunction` section will be removed while `UsedHelper` is preserved.
