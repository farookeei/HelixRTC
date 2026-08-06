package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
)

// Message represents the JSON structure for all communication between clients and the server.
type Message struct {
	Type   string   `json:"type"`             // "join", "offer", "answer", "candidate", "leave"
	Sender string   `json:"sender,omitempty"` // Unique ID of the client sending the message
	To     string   `json:"to,omitempty"`     // Unique ID of the client this message is meant for (for targeted routing)
	Room   string   `json:"room,omitempty"`   // Room ID
	Data   string   `json:"data,omitempty"`   // Raw payload (SDP Offer/Answer or ICE Candidate string)
	Peers  []string `json:"peers,omitempty"`  // List of active peers in the room
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

// writePump handles sending messages from the Client's Send channel down the WebSocket
func (c *Client) writePump() {
	defer func() {
		c.Conn.Close()
	}()

	for {
		// Wait for a message to appear in the Send channel
		message, ok := <-c.Send
		if !ok {
			// Channel was closed
			c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
			return
		}

		// Write the message to the actual WebSocket
		err := c.Conn.WriteMessage(websocket.TextMessage, message)
		if err != nil {
			log.Printf("Error writing to websocket: %v", err)
			return
		}
	}
}

// readPump listens for incoming messages from the WebSocket and routes them
func (c *Client) readPump() {
	defer func() {
		// Cleanup when client disconnects
		if c.Room != nil {
			c.Room.mu.Lock()
			delete(c.Room.Clients, c)
			c.Room.mu.Unlock()
			log.Printf("Client %s left room %s", c.ID, c.Room.ID)
		}

		// CRITICAL FIX: Close the Send channel!
		// If we don't do this, the writePump goroutine will wait forever and cause a memory leak.
		close(c.Send)

		c.Conn.Close()
	}()

	for {
		var msg Message
		// ReadJSON automatically reads the text and converts it into our Message struct!
		err := c.Conn.ReadJSON(&msg)
		if err != nil {
			log.Printf("Client disconnected or error reading: %v", err)
			break
		}

		// If the message has a sender, assign it to the client
		if msg.Sender != "" {
			c.ID = msg.Sender
		}

		switch msg.Type {
		case "join":
			// Lock global hub to find or create the room safely
			globalHub.mu.Lock()
			room, exists := globalHub.Rooms[msg.Room]
			if !exists {
				room = &Room{
					ID:      msg.Room,
					Clients: make(map[*Client]bool),
				}
				globalHub.Rooms[msg.Room] = room
			}
			globalHub.mu.Unlock()

			room.mu.Lock()
			if len(room.Clients) >= 4 {
				room.mu.Unlock()
				log.Printf("Room %s is full, rejecting client %s", msg.Room, c.ID)
				fullMsg := Message{
					Type: "room_full",
					Room: msg.Room,
				}
				msgBytes, _ := json.Marshal(fullMsg)
				c.Send <- msgBytes
				continue // Skip joining logic
			}

			// Assign client to room and add to room's client map safely
			c.Room = room
			room.Clients[c] = true
			room.mu.Unlock()

			log.Printf("Client %s joined room %s", c.ID, msg.Room)

			// 1. Gather all EXISTING peers and send to the new client
			room.mu.RLock()
			var existingPeers []string
			for client := range room.Clients {
				if client != c && client.ID != "" {
					existingPeers = append(existingPeers, client.ID)
				}
			}
			room.mu.RUnlock()

			peerListMsg := Message{
				Type:  "peer_list",
				Room:  msg.Room,
				Peers: existingPeers,
			}
			peerListBytes, _ := json.Marshal(peerListMsg)
			c.Send <- peerListBytes

			// 2. Notify others in the room that this peer joined!
			joinedMsg := Message{
				Type:   "peer_joined",
				Sender: c.ID,
				Room:   msg.Room,
			}
			joinedBytes, _ := json.Marshal(joinedMsg)

			room.mu.RLock()
			for client := range room.Clients {
				if client != c {
					client.Send <- joinedBytes // Tell them to start their peer connection
				}
			}
			room.mu.RUnlock()

		case "offer", "answer", "candidate":
			// Ensure Sender is attached so the recipient knows who sent it
			msg.Sender = c.ID
			if c.Room != nil && msg.To != "" {
				msgBytes, _ := json.Marshal(msg)

				c.Room.mu.RLock()
				for client := range c.Room.Clients {
					if client.ID == msg.To {
						client.Send <- msgBytes // Send to the specific target
						break                   // Found the target, no need to keep looping
					}
				}
				c.Room.mu.RUnlock()
			}
		}
	}
}

// handleConnections upgrades the HTTP connection to a WebSocket and creates the Client
func handleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Error upgrading connection: %v", err)
		return
	}

	// Create our new Client object
	client := &Client{
		Conn: ws,
		Send: make(chan []byte, 256), // Buffered channel outbox
	}

	log.Println("New WebSocket connection established")

	// Start the writer in a new Goroutine
	go client.writePump()

	// Run the reader in the current Goroutine (this blocks until they disconnect)
	client.readPump()
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
