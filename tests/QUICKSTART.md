# Test Suite Quick Start

## Prerequisites

```bash
# Install busted if not already installed
luarocks install busted
```

## Running Tests

### Simple Commands

```bash
# From tests directory
cd /home/god/Stormworks/stormworks.nvim/tests

# Run all tests
make test

# Run unit tests only
make test-unit

# Run integration tests only
make test-integration
```

### Alternative: Shell Script

```bash
# From tests directory
./run_tests.sh all        # All tests
./run_tests.sh unit       # Unit tests
./run_tests.sh integration # Integration tests
./run_tests.sh build      # Build system tests
./run_tests.sh love       # LÖVE UI tests
./run_tests.sh nvim       # Neovim plugin tests
```

### Direct busted Commands

```bash
# From tests directory
busted spec                              # All tests
busted spec/unit                         # Unit tests only
busted spec/unit/build                   # Build tests only
busted spec/unit/build/minimizer_spec.lua # Single file
```

## Expected Output

When tests run successfully, you should see output like:

```
●●●●●●●●●●●●●●●●●●●●●●●●●●
26 successes / 0 failures / 0 errors / 0 pending : 1.234 seconds
```

## Test Categories

- **Build System** (10 files): Tests for LifeBoatAPI compiler
  - Minimizer, Combiner, Variable shortening, etc.

- **Utilities** (4 files): Tests for utility classes
  - StringUtils, TableUtils, Filepath, StringBuilder

- **LÖVE UI** (6 files): Tests for LÖVE2D simulator
  - State, Logger, Headless export, Sandbox, etc.

- **Neovim Plugin** (3 files): Tests for Neovim integration
  - Config, Project detection, Library management

- **Integration** (3 files): End-to-end tests
  - Build pipeline, Headless export, Plugin workflow

## Troubleshooting

### "module not found" errors

Set the environment variable:

```bash
export STORMWORKS_PROJECT_ROOT=/home/god/Stormworks/stormworks.nvim
```

Or use the Makefile/shell script which sets it automatically.

### Permission errors

Make sure run_tests.sh is executable:

```bash
chmod +x /home/god/Stormworks/stormworks.nvim/tests/run_tests.sh
```

### Some tests fail initially

This is expected! The test suite is comprehensive and some tests may need:
- Adjustments for your specific environment
- Mock improvements for edge cases
- Updates to match actual implementation behavior

Use failing tests to guide development and improve the codebase.

## Next Steps

1. Run `make test` to see current status
2. Fix any failing tests by improving either:
   - The test itself (if test assumptions are wrong)
   - The implementation (if bugs are found)
3. Add new tests when adding new features
4. Keep tests passing as you develop

See `README.md` for detailed documentation.
