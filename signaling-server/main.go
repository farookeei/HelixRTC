package main

import (
	"fmt"
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
)

// Message represents the JSON structure for all communication between clients and the server.
type Message struct {
	Type   string `json:"type"`             // "join", "offer", "answer", "candidate", "leave"
	Sender string `json:"sender,omitempty"`  // Unique ID of the client sending the message
	Target string `json:"target,omitempty"`  // Unique ID of the client this message is meant for (for 1-to-1 routing)
	Room   string `json:"room,omitempty"`    // Room ID
	Data   string `json:"data,omitempty"`    // Raw payload (SDP Offer/Answer or ICE Candidate string)
}

// Client represents a single connected WebSocket client.
type Client struct {
	ID   string
	Room *Room
	Conn *websocket.Conn
	Send chan []byte // Channel to queue outgoing messages for this client
}

// Room represents a single video call session containing multiple clients.
type Room struct {
	ID      string
	Clients map[*Client]bool
	mu      sync.RWMutex // Protects the Clients map from concurrent read/writes
}

// Hub maintains the set of active rooms.
type Hub struct {
	Rooms map[string]*Room
	mu    sync.RWMutex // Protects the Rooms map from concurrent read/writes
}

// globalHub holds all active rooms globally.
var globalHub = &Hub{
	Rooms: make(map[string]*Room),
}



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
