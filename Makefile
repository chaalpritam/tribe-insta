.PHONY: generate build clean archive bump-build testflight-upload setup

SIMULATOR_DEST ?= generic/platform=iOS Simulator
ARCHIVE_PATH ?= build/tribe-insta.xcarchive
EXPORT_PATH ?= build/export
SCHEME = tribe-insta
PROJECT = tribe-insta.xcodeproj

setup:
	@chmod +x scripts/setup.sh
	@./scripts/setup.sh
	@$(MAKE) generate

generate:
	@chmod +x scripts/setup.sh scripts/patch-tribecore-package.sh
	@./scripts/setup.sh
	xcodegen generate
	@./scripts/patch-tribecore-package.sh

build: generate
	xcodebuild -scheme $(SCHEME) \
		-project $(PROJECT) \
		-destination '$(SIMULATOR_DEST)' \
		CODE_SIGNING_ALLOWED=NO \
		build

clean:
	rm -rf build DerivedData $(ARCHIVE_PATH) $(EXPORT_PATH)

archive: generate
	xcodebuild -scheme $(SCHEME) \
		-project $(PROJECT) \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		-archivePath $(ARCHIVE_PATH) \
		DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)" \
		archive
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist ExportOptions.plist \
		DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)"

bump-build:
	@./scripts/bump-build.sh

testflight-upload:
	@./scripts/testflight-upload.sh
