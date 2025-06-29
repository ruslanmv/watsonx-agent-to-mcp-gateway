# Makefile
.PHONY: build run tidy docker-build docker-run

# This target ensures go.mod exists before other commands run.
# If it doesn't exist, it runs 'go mod init'.
go.mod:
	@echo "go.mod not found. Initializing module..."
	@go mod init time-agent

tidy: go.mod
	@echo "Tidying Go modules..."
	@go mod tidy

build: tidy
	@echo "Building binary..."
	@go build -o fast-time-server .

run: build
	@echo "Starting server on port 8081..."
	@./fast-time-server

docker-build:
	@docker build -t fast-time-server:latest .

docker-run:
	@docker run --rm -p 8081:8081 -e PORT=8081 fast-time-server:latest