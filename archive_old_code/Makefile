.PHONY: build run-core run-gui

# Build everything
build: build-core build-cli build-gui

# Build the Golang core
build-core:
	cd core_go && go build -o ../bin/core_go ./cmd/server/main.go

# Build the Rust CLI
build-cli:
	cd core_rust && cargo build --release && cp target/release/core_rust ../bin/modbus_cli

# Run the Golang Modbus server
run-core:
	cd core_go && go run ./cmd/server/main.go -mode=server

# Build the Flutter Native GUI
build-gui:
	cd gui_flutter && flutter build macos

# Run the Flutter Native GUI
run-gui:
	cd gui_flutter && flutter run -d macos

# Run both core and gui at the same time (requires 2 terminal tabs ideally)
run-all:
	@echo "Open 2 terminals. In terminal 1: make run-core. In terminal 2: make run-gui"
