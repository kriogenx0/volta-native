.DEFAULT_GOAL := gallery
PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SWIFT_ENV := CLANG_MODULE_CACHE_PATH="$(PROJECT_DIR)/.build/ModuleCache" SWIFTPM_MODULECACHE_OVERRIDE="$(PROJECT_DIR)/.build/ModuleCache"

.PHONY: setup gallery c-lib c-gallery test tokens clean help

setup:
	@test "$$(uname -s)" = Darwin || { echo "Volta-Native requires macOS."; exit 1; }
	@xcrun --find swift >/dev/null || { echo "Install Xcode or the Xcode Command Line Tools first."; exit 1; }
	@printf '%s\n' 'Setup complete. No third-party dependencies are required.'

gallery: setup ## Build and open the Swift component gallery
	@cd "$(PROJECT_DIR)" && $(SWIFT_ENV) swift run VoltaGallery

c-lib: setup ## Build libVoltaNativeC.dylib for C apps
	@cd "$(PROJECT_DIR)" && $(SWIFT_ENV) swift build --product VoltaNativeC
	@printf '%s\n' "Built $$(cd "$(PROJECT_DIR)" && swift build --show-bin-path)/libVoltaNativeC.dylib"

c-gallery: c-lib ## Build and open the C gallery
	@cd "$(PROJECT_DIR)" && BIN="$$(swift build --show-bin-path)" && mkdir -p build && \
	  clang -std=c11 -Wall -Wextra -Iinclude Examples/CGallery/main.c -L"$$BIN" -lVoltaNativeC -Wl,-rpath,"$$BIN" -o build/c-gallery && \
	  ./build/c-gallery

test: ## Run the test suite
	@cd "$(PROJECT_DIR)" && $(SWIFT_ENV) swift test --disable-sandbox --cache-path .build/cache

tokens: ## Regenerate Swift and C token files from tokens/tokens.json
	@cd "$(PROJECT_DIR)" && python3 scripts/gen-tokens.py

clean: ## Remove build outputs
	@cd "$(PROJECT_DIR)" && rm -rf build .build

help:
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'
