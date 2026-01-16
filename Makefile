.PHONY: bump build test clean

VERSION ?= $(error VERSION is required. Usage: make bump VERSION=0.2.0)

# Bump version in all source files
bump:
	@echo "Bumping version to $(VERSION)"
	@sed -i '' 's/^version = ".*"/version = "$(VERSION)"/' Cargo.toml
	@sed -i '' 's/^VERSION="v.*"/VERSION="v$(VERSION)"/' scripts/install.sh
	@echo "Updated:"
	@grep '^version = ' Cargo.toml
	@grep '^VERSION=' scripts/install.sh

# Build release binary
build:
	cargo build --release

# Run e2e tests (requires tmux)
test: build
	@./tests/e2e_test.sh

# Clean build artifacts
clean:
	cargo clean
	rm -rf bin/
