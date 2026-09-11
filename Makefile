# LyricsX — run from the repository root.
# Requires full Xcode (see README.md). Command Line Tools alone cannot build this project.

PROJECT      := LyricsX.xcodeproj
SCHEME       := LyricsX
DERIVED_DATA := Product/DerivedData
BUNDLE_ID    := dev.xandao.LyricsX

DEBUG_APP   := $(DERIVED_DATA)/Build/Products/Debug/LyricsX.app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/LyricsX.app
INSTALL_APP := /Applications/LyricsX.app

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA)

.DEFAULT_GOAL := help

.PHONY: help build run test lint install uninstall clean

help:
	@echo "LyricsX"
	@echo
	@echo "  make build       Debug-build into $(DERIVED_DATA)"
	@echo "  make run         Build and launch the Debug app"
	@echo "  make test        Run LyricsKit package tests"
	@echo "  make lint        Run SwiftLint (brew install swiftlint)"
	@echo "  make install     Release-build and copy to $(INSTALL_APP)"
	@echo "  make uninstall   Quit LyricsX and remove it from /Applications"
	@echo "  make clean       Delete derived data"

build:
	$(XCODEBUILD) -configuration Debug build

run: build
	@killall LyricsX 2>/dev/null || true
	open "$(DEBUG_APP)"

test:
	swift test --package-path LyricsKit

lint:
	@command -v swiftlint >/dev/null || { \
		echo "error: SwiftLint is not installed. Install it with: brew install swiftlint"; \
		exit 1; \
	}
	swiftlint

install:
	$(XCODEBUILD) -configuration Release build
	@killall LyricsX 2>/dev/null || true
	ditto "$(RELEASE_APP)" "$(INSTALL_APP)"
	open "$(INSTALL_APP)"

uninstall:
	@killall LyricsX 2>/dev/null || true
	rm -rf "$(INSTALL_APP)"
	@defaults delete $(BUNDLE_ID) 2>/dev/null || true
	@echo "Removed $(INSTALL_APP). Lyrics in ~/Music/LyricsX were left in place."

clean:
	rm -rf "$(DERIVED_DATA)"
