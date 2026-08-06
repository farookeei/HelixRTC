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

	// 4. Client A (Alice) joins
	joinMsgA := Message{Type: "join", Sender: "Alice", Room: "room1"}
	wsA.WriteJSON(joinMsgA)
	time.Sleep(50 * time.Millisecond)

	// Alice gets peer_list (empty)
	var msgA Message
	wsA.ReadJSON(&msgA) // peer_list

	// 5. Client B (Bob) joins
	joinMsgB := Message{Type: "join", Sender: "Bob", Room: "room1"}
	wsB.WriteJSON(joinMsgB)
	time.Sleep(50 * time.Millisecond)

	// Bob receives peer_list (should contain Alice)
	var msgB Message
	wsB.SetReadDeadline(time.Now().Add(1 * time.Second))
	wsB.ReadJSON(&msgB) // peer_list
	if msgB.Type != "peer_list" || len(msgB.Peers) != 1 || msgB.Peers[0] != "Alice" {
		t.Errorf("Expected Bob to get peer_list with Alice, got: %v", msgB)
	}

	// Alice receives peer_joined from Bob
	wsA.SetReadDeadline(time.Now().Add(1 * time.Second))
	wsA.ReadJSON(&msgA) // peer_joined
	if msgA.Type != "peer_joined" || msgA.Sender != "Bob" {
		t.Errorf("Expected Alice to get peer_joined from Bob, got: %v", msgA)
	}

	// 6. Connect Client C (Charlie) and D (Dave)
	wsC, _, _ := websocket.DefaultDialer.Dial(wsURL, nil)
	defer wsC.Close()
	wsD, _, _ := websocket.DefaultDialer.Dial(wsURL, nil)
	defer wsD.Close()

	wsC.WriteJSON(Message{Type: "join", Sender: "Charlie", Room: "room1"})
	time.Sleep(50 * time.Millisecond)
	wsD.WriteJSON(Message{Type: "join", Sender: "Dave", Room: "room1"})
	time.Sleep(50 * time.Millisecond)

	// 7. Connect Client E (Eve) - should be rejected (Room full)
	wsE, _, _ := websocket.DefaultDialer.Dial(wsURL, nil)
	defer wsE.Close()
	wsE.WriteJSON(Message{Type: "join", Sender: "Eve", Room: "room1"})
	
	var msgE Message
	wsE.SetReadDeadline(time.Now().Add(1 * time.Second))
	wsE.ReadJSON(&msgE)
	if msgE.Type != "room_full" {
		t.Errorf("Expected Eve to be rejected with room_full, got %s", msgE.Type)
	}

	// 8. Test targeted routing: Alice sends an offer targeting ONLY Charlie
	offerMsg := Message{Type: "offer", Sender: "Alice", To: "Charlie", Room: "room1", Data: "SDP_OFFER"}
	err = wsA.WriteJSON(offerMsg)
	if err != nil {
		t.Fatalf("Failed to write offer: %v", err)
	}

	time.Sleep(50 * time.Millisecond)

	// Drain peer_list / peer_joined for Charlie to get to the offer
	var msgC Message
	wsC.SetReadDeadline(time.Now().Add(1 * time.Second))
	wsC.ReadJSON(&msgC) // peer_list
	wsC.ReadJSON(&msgC) // peer_joined from Dave

	// Charlie should receive the offer
	wsC.SetReadDeadline(time.Now().Add(1 * time.Second))
	err = wsC.ReadJSON(&msgC)
	if err != nil {
		t.Fatalf("Charlie failed to read message: %v", err)
	}
	if msgC.Type != "offer" || msgC.Sender != "Alice" || msgC.Data != "SDP_OFFER" {
		t.Errorf("Expected Charlie to receive Alice's offer, got: %v", msgC)
	}
}
