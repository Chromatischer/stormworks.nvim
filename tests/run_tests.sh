#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Ensure busted is installed
if ! command -v busted &> /dev/null; then
    echo "Error: busted not found. Install it with:"
    echo "  luarocks install busted"
    exit 1
fi

# Add project to Lua path
export LUA_PATH="$PROJECT_ROOT/lua/?.lua;$PROJECT_ROOT/lua/?/init.lua;$SCRIPT_DIR/helpers/?.lua;$LUA_PATH"

cd "$SCRIPT_DIR"

case "${1:-all}" in
    "all")
        busted spec
        ;;
    "unit")
        busted spec/unit
        ;;
    "integration")
        busted spec/integration
        ;;
    "build")
        busted spec/unit/build
        ;;
    "love")
        busted spec/unit/love
        ;;
    "nvim"|"neovim")
        busted spec/unit/modules
        ;;
    "watch")
        # Watch mode - requires entr or similar
        if command -v entr &> /dev/null; then
            find spec -name "*_spec.lua" | entr -c busted spec
        else
            echo "Watch mode requires 'entr'. Install it or run tests manually."
            exit 1
        fi
        ;;
    "help")
        echo "Usage: $0 [all|unit|integration|build|love|nvim|watch|help|<file>]"
        echo ""
        echo "Commands:"
        echo "  all          - Run all tests (default)"
        echo "  unit         - Run unit tests only"
        echo "  integration  - Run integration tests only"
        echo "  build        - Run build system tests"
        echo "  love         - Run LÖVE UI tests"
        echo "  nvim         - Run Neovim plugin tests"
        echo "  watch        - Watch mode (requires entr)"
        echo "  help         - Show this help"
        echo "  <file>       - Run specific test file"
        ;;
    *)
        # Run specific file or pattern
        busted "$1"
        ;;
esac
