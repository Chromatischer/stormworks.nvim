.PHONY: test test-unit test-integration test-build test-love test-nvim coverage clean help

# Set up paths
TESTS_DIR := $(shell pwd)
PROJECT_ROOT := $(shell dirname $(TESTS_DIR))

# Default test command
test:
	cd $(TESTS_DIR) && busted spec

# Unit tests only
test-unit:
	cd $(TESTS_DIR) && busted spec/unit

# Integration tests only
test-integration:
	cd $(TESTS_DIR) && busted spec/integration

# Build system tests
test-build:
	cd $(TESTS_DIR) && busted spec/unit/build spec/unit/utils

# LÖVE2D framework tests (requires mock)
test-love:
	cd $(TESTS_DIR) && busted spec/unit/love

# Neovim plugin tests (requires mock)
test-nvim:
	cd $(TESTS_DIR) && busted spec/unit/modules

# Run with coverage
coverage:
	cd $(TESTS_DIR) && busted --coverage spec
	luacov

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=spec/unit/build/minimizer_spec.lua"; \
		exit 1; \
	fi
	cd $(TESTS_DIR) && busted $(FILE)

# Run tests matching pattern
test-pattern:
	@if [ -z "$(PATTERN)" ]; then \
		echo "Usage: make test-pattern PATTERN=minimizer"; \
		exit 1; \
	fi
	cd $(TESTS_DIR) && busted --pattern=$(PATTERN) spec

# Verbose output
test-verbose:
	cd $(TESTS_DIR) && busted --verbose spec

# Clean test artifacts
clean:
	rm -rf /tmp/stormworks_test_*
	rm -f luacov.stats.out luacov.report.out

# Help
help:
	@echo "Available targets:"
	@echo "  test              - Run all tests"
	@echo "  test-unit         - Run unit tests only"
	@echo "  test-integration  - Run integration tests only"
	@echo "  test-build        - Run build system tests"
	@echo "  test-love         - Run LÖVE UI tests"
	@echo "  test-nvim         - Run Neovim plugin tests"
	@echo "  coverage          - Run tests with coverage"
	@echo "  test-file FILE=   - Run specific test file"
	@echo "  test-pattern PATTERN= - Run tests matching pattern"
	@echo "  test-verbose      - Run tests with verbose output"
	@echo "  clean             - Clean test artifacts"
