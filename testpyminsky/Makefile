PYMINSKY_PKG := $(shell nix build ..\#pyminsky --no-link --print-out-paths 2>/dev/null)
PYMINSKY_SO := $(shell find $(PYMINSKY_PKG) -type d -name site-packages 2>/dev/null)

# Must use the same Python that pyminsky.so was built against (nixpkgs python3).
# The system Python will segfault due to ABI mismatch.
NIX_PYTHON := $(shell nix build nixpkgs\#python3 --no-link --print-out-paths 2>/dev/null)/bin/python3
PYTHON := $(NIX_PYTHON)
export PYTHONPATH := $(PYMINSKY_SO)

TESTS := test_basic test_goodwin test_godley test_endogenous_money test_all_examples

.PHONY: all $(TESTS) clean help

all: $(TESTS)
	@echo ""
	@echo "All tests passed."

$(TESTS): test_%: test_%.py
	@echo "=== $@ ==="
	@$(PYTHON) $<
	@echo ""

# Run a single test: make run TEST=test_godley
.PHONY: run
run:
	@$(PYTHON) $(TEST).py

help:
	@echo "Usage:"
	@echo "  make              Run all tests"
	@echo "  make test_basic   Run basic import/version tests"
	@echo "  make test_goodwin Run Goodwin growth model tests"
	@echo "  make test_godley  Run Godley table / accounting tests"
	@echo "  make test_endogenous_money  Run EndogenousMoney model tests"
	@echo "  make test_all_examples      Load & simulate every .mky example"
	@echo "  make run TEST=<name>        Run a specific test file"
	@echo ""
	@echo "Requires: nix build ..#pyminsky (the flake in the parent directory)"
