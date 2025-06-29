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
