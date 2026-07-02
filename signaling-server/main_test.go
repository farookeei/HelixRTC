package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestWebSocketRouting(t *testing.T) {
	// 1. Create a mock HTTP server that uses our handleConnections function
	server := httptest.NewServer(http.HandlerFunc(handleConnections))
	defer server.Close()

	// Convert the http:// URL to a ws:// URL
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	// 2. Connect Client A (Alice)
	wsA, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Could not connect Client A: %v", err)
	}
	defer wsA.Close()

	// 3. Connect Client B (Bob)
	wsB, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Could not connect Client B: %v", err)
	}
	defer wsB.Close()

	// 4. Both clients join "room1"
	joinMsgA := Message{Type: "join", Sender: "Alice", Room: "room1"}
	wsA.WriteJSON(joinMsgA)

	joinMsgB := Message{Type: "join", Sender: "Bob", Room: "room1"}
	wsB.WriteJSON(joinMsgB)

	// Wait briefly to ensure both are registered in the global hub before sending messages
	time.Sleep(100 * time.Millisecond)

	// 5. Alice sends an offer to the room
	offerMsg := Message{Type: "offer", Sender: "Alice", Room: "room1", Data: "SDP_OFFER"}
	err = wsA.WriteJSON(offerMsg)
	if err != nil {
		t.Fatalf("Failed to write offer: %v", err)
	}

	// 6. Bob should receive the offer
	var receivedMsg Message
	// We set a deadline so the test doesn't hang forever if it fails
	wsB.SetReadDeadline(time.Now().Add(2 * time.Second))
	err = wsB.ReadJSON(&receivedMsg)
	if err != nil {
		t.Fatalf("Bob failed to read message: %v", err)
	}

	// 7. Verify the message is correct
	if receivedMsg.Type != "offer" {
		t.Errorf("Expected message type 'offer', got '%s'", receivedMsg.Type)
	}
	if receivedMsg.Sender != "Alice" {
		t.Errorf("Expected sender 'Alice', got '%s'", receivedMsg.Sender)
	}
	if receivedMsg.Data != "SDP_OFFER" {
		t.Errorf("Expected data 'SDP_OFFER', got '%s'", receivedMsg.Data)
	}
}
