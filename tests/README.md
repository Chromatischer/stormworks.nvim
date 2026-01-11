# stormworks.nvim Test Suite

Comprehensive test suite for stormworks.nvim using the [busted](https://olivinelabs.com/busted/) testing framework.

## Installation

Install busted via luarocks:

```bash
luarocks install busted
```

## Running Tests

### Quick Start

```bash
# Run all tests
cd tests
make test

# Or use the shell script
./run_tests.sh all
```

### Test Categories

```bash
# Unit tests only
make test-unit

# Integration tests only
make test-integration

# Build system tests (LifeBoatAPI compiler)
make test-build

# LÖVE UI tests
make test-love

# Neovim plugin tests
make test-nvim
```

### Specific Tests

```bash
# Run specific test file
make test-file FILE=spec/unit/build/minimizer_spec.lua

# Run tests matching pattern
make test-pattern PATTERN=minimizer

# Verbose output
make test-verbose
```

### Coverage

```bash
# Run with coverage analysis
make coverage

# View coverage report
cat luacov.report.out
```

## Test Structure

```
tests/
├── spec/
│   ├── unit/                    # Unit tests
│   │   ├── build/               # Build system tests (10 files)
│   │   ├── utils/               # Utility tests (4 files)
│   │   ├── love/                # LÖVE UI tests (6 files)
│   │   └── modules/             # Neovim plugin tests (3 files)
│   └── integration/             # Integration tests (3 files)
├── fixtures/                    # Test data
│   └── scripts/                 # Sample Lua scripts
├── helpers/                     # Test utilities
│   ├── mock_love.lua            # LÖVE2D framework mock
│   ├── mock_vim.lua             # Neovim API mock
│   └── test_utils.lua           # Common test utilities
├── .busted                      # busted configuration
├── Makefile                     # Test commands
└── run_tests.sh                 # Shell script runner
```

## Test Coverage

### Build System (10 tests)
- **hexadecimal_converter_spec.lua** - Hex to decimal conversion
- **variable_renamer_spec.lua** - Variable name generation
- **string_comments_parser_spec.lua** - String/comment extraction
- **variable_shortener_spec.lua** - Variable shortening
- **global_variable_reducer_spec.lua** - Global variable aliasing
- **number_literal_reducer_spec.lua** - Number literal extraction
- **redundancy_remover_spec.lua** - @section removal
- **combiner_spec.lua** - require() resolution
- **minimizer_spec.lua** - Full minimization pipeline
- **builder_spec.lua** - Build orchestration

### Utilities (4 tests)
- **string_utils_spec.lua** - String manipulation
- **table_utils_spec.lua** - Table operations
- **filepath_spec.lua** - Path handling
- **string_builder_spec.lua** - Text reconstruction

### LÖVE UI (6 tests)
- **state_spec.lua** - Application state
- **logger_spec.lua** - Logging system
- **hotreload_spec.lua** - File change detection
- **storm_api_spec.lua** - Stormworks API
- **headless_spec.lua** - CLI export
- **sandbox_spec.lua** - Script execution

### Neovim Plugin (3 tests)
- **config_spec.lua** - Configuration management
- **project_spec.lua** - Project detection
- **library_spec.lua** - LSP library registration

### Integration (3 tests)
- **build_pipeline_spec.lua** - End-to-end build
- **headless_export_spec.lua** - CLI export workflow
- **neovim_plugin_spec.lua** - Plugin lifecycle

## Environment Variables

```bash
# Override project root (optional)
export STORMWORKS_PROJECT_ROOT=/path/to/project
```

## Mocking

### LÖVE2D Mock
Tests that require LÖVE2D use `mock_love.lua` which provides:
- Graphics API (canvas, drawing, colors)
- Timer, event, filesystem APIs
- Window, keyboard, mouse APIs
- Helper methods for assertions

### Neovim Mock
Tests that require Neovim use `mock_vim.lua` which provides:
- `vim.fn` API (file operations, JSON, etc.)
- `vim.api` API (buffers, commands, autocmds)
- `vim.lsp` API (LSP client management)
- State helpers for test setup

## Writing New Tests

### Basic Test Structure

```lua
describe("MyModule", function()
  local TestUtils = require("test_utils")
  local my_module

  setup(function()
    TestUtils.setup_lifeboat()  -- For build system tests
    my_module = require("path.to.my_module")
  end)

  before_each(function()
    -- Setup before each test
  end)

  after_each(function()
    -- Cleanup after each test
  end)

  describe("my_function", function()
    it("should do something", function()
      local result = my_module.my_function("input")
      assert.equals("expected", result)
    end)
  end)
end)
```

### Test Utilities

```lua
local TestUtils = require("test_utils")

-- Temporary directories
local temp = TestUtils.create_temp_dir()
TestUtils.write_file(temp .. "/test.lua", "content")
local content = TestUtils.read_file(temp .. "/test.lua")
TestUtils.remove_temp_dir(temp)

-- Lua validation
local is_valid, err = TestUtils.is_valid_lua(code)

-- Assertions
TestUtils.assert_contains(str, "pattern")
TestUtils.assert_not_contains(str, "pattern")
TestUtils.assert_smaller(original, minimized)

-- LifeBoatAPI setup
TestUtils.setup_lifeboat()
```

## Continuous Testing

Watch mode (requires `entr`):

```bash
./run_tests.sh watch
```

## Troubleshooting

### Tests fail to load modules

Ensure `LUA_PATH` includes the project directory:

```bash
export LUA_PATH="$(pwd)/../lua/?.lua;$(pwd)/../lua/?/init.lua;$LUA_PATH"
```

### LÖVE tests fail

Check that `mock_love.lua` is being loaded before the LÖVE modules:

```lua
_G.love = require("mock_love")
```

### Neovim tests fail

Check that `mock_vim.lua` is being loaded before the plugin modules:

```lua
_G.vim = require("mock_vim")
```

## Contributing

When adding new features:
1. Write tests first (TDD)
2. Ensure all existing tests still pass
3. Add integration tests for cross-module features
4. Update this README if adding new test categories
