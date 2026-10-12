# Shortcuts for everyday tasks. Run `make` to list them.
ESPHOME := .venv/bin/esphome
VERSION ?=

.DEFAULT_GOAL := help
.PHONY: help setup sim sim-dexcom sim-reset build flash logs check release clean

help: ## List the commands
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-12s %s\n", $$1, $$2}'

setup: ## Create .venv with ESPHome and secrets.yaml (if missing)
	/opt/homebrew/bin/python3.13 -m venv .venv
	.venv/bin/pip install -q esphome==2026.9.1
	@test -f secrets.yaml || { cp secrets.example.yaml secrets.yaml; echo "Created secrets.yaml: fill in the values"; }

sim: ## Simulator with demo data
	$(ESPHOME) run simulator.yaml

sim-dexcom: ## Simulator with real Dexcom (credentials from secrets.yaml)
	$(ESPHOME) run simulator-dexcom.yaml

sim-reset: ## Forget what the simulators stored (e.g. old Dexcom credentials)
	rm -f ~/.esphome/prefs/glucia-sim.prefs ~/.esphome/prefs/glucia-sim-dexcom.prefs

build: ## Build the board firmware
	$(ESPHOME) compile guition.yaml

flash: ## Build and install on the board (USB or WiFi, it asks)
	$(ESPHOME) run guition.yaml

logs: ## Show the board logs (USB)
	$(ESPHOME) logs guition.yaml

check: ## Build everything (before tagging a release)
	$(ESPHOME) compile simulator.yaml
	$(ESPHOME) compile simulator-dexcom.yaml
	$(ESPHOME) compile guition.yaml

release: ## Publish a firmware version: make release VERSION=v0.2
	@test -n "$(VERSION)" || { echo "Usage: make release VERSION=v0.2"; exit 1; }
	@case "$(VERSION)" in v*) ;; *) echo "VERSION must start with v"; exit 1;; esac
	@test "$$(git branch --show-current)" = main || { echo "Releases are tagged from main"; exit 1; }
	@test -z "$$(git status --porcelain)" || { echo "Commit your changes first"; exit 1; }
	@git fetch -q origin main && test "$$(git rev-parse HEAD)" = "$$(git rev-parse origin/main)" || { echo "main is not in sync with GitHub"; exit 1; }
	git tag $(VERSION)
	git push origin $(VERSION)
	@echo "Building on GitHub: https://github.com/albarin/glucia/actions"

clean: ## Delete build files (they are rebuilt on the next build)
	rm -rf .esphome
