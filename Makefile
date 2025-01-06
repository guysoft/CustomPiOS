# Makefile for running shell script tests

# Shell to use
SHELL := /bin/bash

# Find all test files
TEST_DIR := tests
TEST_FILES := $(wildcard $(TEST_DIR)/test_*.sh)

# Colors for output
BLUE := \033[1;34m
GREEN := \033[1;32m
RED := \033[1;31m
NC := \033[0m # No Color

.PHONY: all test clean help

# Default target
all: test

# Help message
help:
	@echo "Available targets:"
	@echo "  make test  - Run all tests"
	@echo "  make clean - Clean up temporary files"
	@echo "  make help  - Show this help message"

# Run all tests
test:
	@echo -e "$(BLUE)Running tests...$(NC)"
	@echo "═══════════════════════════════════════"
	@success=true; \
	for test in $(TEST_FILES); do \
		echo -e "$(BLUE)Running $$test...$(NC)"; \
		if chmod +x $$test && ./$$test; then \
			echo -e "$(GREEN)✓ $$test passed$(NC)"; \
		else \
			echo -e "$(RED)✗ $$test failed$(NC)"; \
			success=false; \
		fi; \
		echo "───────────────────────────────────────"; \
	done; \
	echo ""; \
	if $$success; then \
		echo -e "$(GREEN)All tests passed successfully!$(NC)"; \
		exit 0; \
	else \
		echo -e "$(RED)Some tests failed!$(NC)"; \
		exit 1; \
	fi

# Clean up any temporary files (if needed)
clean:
	@echo -e "$(BLUE)Cleaning up...$(NC)"
	@find $(TEST_DIR) -type f -name "*.tmp" -delete
	@find $(TEST_DIR) -type f -name "*.log" -delete
	@echo -e "$(GREEN)Cleanup complete$(NC)"
