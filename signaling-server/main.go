package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

// upgrader holds configuration for upgrading HTTP connections to WebSockets
var upgrader = websocket.Upgrader{
	// CheckOrigin prevents CSRF. We allow any origin for testing.
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// handleConnections is our HTTP handler function that upgrades to WebSockets
func handleConnections(w http.ResponseWriter, r *http.Request) {
	// Upgrade initial GET request to a WebSocket
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Error upgrading connection: %v", err)
		return
	}
	// Defer closing the connection until the function exits
	defer ws.Close()

	log.Println("New client connected!")

	// Infinite loop to continuously read messages from the client
	for {
		// Read message from client
		messageType, msg, err := ws.ReadMessage()
		if err != nil {
			log.Printf("Error reading message (Client disconnected?): %v", err)
			break
		}

		// Print the received message to our server console
		fmt.Printf("Received: %s\n", msg)

		// Echo the same message back to the client
		err = ws.WriteMessage(messageType, msg)
		if err != nil {
			log.Printf("Error writing message: %v", err)
			break
		}
	}
}

func main() {
	// Define the route and the handler function
	http.HandleFunc("/ws", handleConnections)

	// Start the server
	fmt.Println("Signaling server started on :8080")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatal("ListenAndServe error: ", err)
	}
}
