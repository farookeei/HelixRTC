# HelixRTC

HelixRTC is a cross-platform peer-to-peer (P2P) real-time video calling and data streaming application. 

This repository is structured as a **monorepo**, containing both the backend signaling server and the frontend client application. This approach ensures tight coupling between the client and server communication protocols and makes it easier to test and deploy the entire system together.

## Project Structure

*   **`/signaling-server`**: A high-performance WebSockets server written in Go (Golang). It acts as the "matchmaker" for our P2P connections, allowing clients to discover each other and exchange WebRTC connection data (SDP offers/answers and ICE candidates).
*   **`/app`**: A Flutter application (targeting Web, Android, and iOS). This is the client-side app that interacts with the user's camera/microphone and establishes direct peer-to-peer WebRTC connections with other users.

## How WebRTC Works (High Level)

1.  **Signaling:** Clients connect to our Go `/signaling-server` via WebSockets. They use this server to find each other and negotiate a connection. No media (video/audio) goes through this server.
2.  **P2P Connection:** Once negotiated, the clients establish a direct peer-to-peer connection using WebRTC. All video, audio, and data are streamed directly between the devices, minimizing latency and server costs.

## Features Built So Far

*   **Custom Signaling Server (Go):** Uses WebSockets to establish rooms and route WebRTC negotiation messages.
*   **WebRTC Integration (Flutter):** Fully functional peer-to-peer video streaming.
*   **Cross-Platform UI:** Modern, dark-mode video call interface tailored for Web, iOS, and Android.
*   **State Management (Riverpod):** Clean architecture keeping WebRTC/Signaling logic separate from the UI.
*   **Automated Testing:** Unit tests verifying SDP Offer/Answer flows and ICE candidate exchanges.

## Getting Started

### 1. Run the Signaling Server
Navigate into the `signaling-server` directory and run the Go server:
```bash
cd signaling-server
go run main.go
```
The server will start on `localhost:8080`.

### 2. Run the Flutter App
Open a new terminal, navigate into the `app` directory, and run the app. You can run it on Chrome or a connected device.
```bash
cd app
fvm flutter run 
```

*(Note: If testing on an Android Emulator or physical device, ensure you update the WebSocket IP address in `webrtc_provider.dart` from localhost to your machine's local IP address).*
