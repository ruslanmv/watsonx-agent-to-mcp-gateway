# 🕒 Fast Time Server Agent

> A minimal Go-based MCP agent that exposes a `get_system_time` tool to provide the current UTC time.

## Features

  * Implements the **`get_system_time`** MCP tool
  * Responds with the current time in `RFC3339` format
  * Single HTTP (JSON-RPC) transport at `/http`
  * Configurable port via the `PORT` environment variable
  * Single, lightweight static binary

## Quick Start & Usage

1.  **Create the Project Files:**
    First, create a directory for your agent. Inside it, create `main.go` and `Makefile` with the code provided in the sections below.

2.  **Run the Server:**
    From your terminal, simply run `make run`. This command will automatically initialize the Go module, tidy dependencies, build the binary, and start the server.

    ```bash
    make run
    ```

    You will see the following output, and the server will be running:

    ```
    go.mod not found. Initializing module...
    go mod init time-agent
    Tidying Go modules...
    go mod tidy
    Building binary...
    Starting server on port 8081...
    2025/06/29 17:55:09 Starting Go time server on :8081
    ```

3.  **Query the Agent:**
    **Open a new, separate terminal window.** With the server running in your first terminal, use `curl` in the second terminal to send a request to the agent.

    ```bash
    curl -X POST \
      -H "Content-Type: application/json" \
      -d '{"tool": "get_system_time", "args": null}' \
      http://localhost:8081/http
    ```

4.  **See the Result:**
    The server will return the current time in JSON format:

    ```json
    {"result":"2025-06-29T17:56:00Z"}
    ```

## Configuration

The agent's listening port can be configured via an environment variable.

| Variable | Description                                  | Default |
| :------- | :------------------------------------------- | :------ |
| `PORT`   | The port number for the server to listen on. | `8081`  |

**Example:**

```bash
PORT=9000 make run
```

## Source Code

### `main.go`

```go
// main.go
package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"time"
)

type ToolRequest struct {
	Tool string          `json:"tool"`
	Args json.RawMessage `json:"args"`
}

type ToolResponse struct {
	Result string `json:"result"`
}

func toolHandler(w http.ResponseWriter, r *http.Request) {
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Cannot read body", http.StatusBadRequest)
		return
	}

	var req ToolRequest
	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, "Cannot unmarshal JSON", http.StatusBadRequest)
		return
	}

	var result string
	switch req.Tool {
	case "get_system_time":
		result = time.Now().UTC().Format(time.RFC3339)
	default:
		http.Error(w, fmt.Sprintf("Tool not found: %s", req.Tool), http.StatusNotFound)
		return
	}

	resp := ToolResponse{Result: result}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func main() {
	listenAddr := ":8081"
	if port := os.Getenv("PORT"); port != "" {
		listenAddr = ":" + port
	}

	http.HandleFunc("/http", toolHandler)
	log.Printf("Starting Go time server on %s", listenAddr)
	if err := http.ListenAndServe(listenAddr, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
```

### `Makefile`

```makefile
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
```

### `Dockerfile`

```dockerfile
# Dockerfile

# ---- Build Stage ----
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 go build -o /fast-time-server .

# ---- Final Stage ----
FROM gcr.io/distroless/static-debian12
COPY --from=builder /fast-time-server /fast-time-server
EXPOSE 8081
ENTRYPOINT ["/fast-time-server"]
```