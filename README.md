# HelixRTC

HelixRTC is a cross-platform peer-to-peer (P2P) real-time video calling and data streaming application. 

This repository is structured as a **monorepo**, containing both the backend signaling server and the frontend client application. This approach ensures tight coupling between the client and server communication protocols and makes it easier to test and deploy the entire system together.

## Project Structure

*   **`/signaling-server`**: A high-performance WebSockets server written in Go (Golang). It acts as the "matchmaker" for our P2P connections, allowing clients to discover each other and exchange WebRTC connection data (SDP offers/answers and ICE candidates).
*   **`/app`**: A Flutter application (targeting Web, Android, and iOS). This is the client-side app that interacts with the user's camera/microphone and establishes direct peer-to-peer WebRTC connections with other users.

## How WebRTC Works (High Level)

1.  **Signaling:** Clients connect to our Go `/signaling-server` via WebSockets. They use this server to find each other and negotiate a connection. No media (video/audio) goes through this server.
2.  **P2P Connection:** Once negotiated, the clients establish a direct peer-to-peer connection using WebRTC. All video, audio, and data are streamed directly between the devices, minimizing latency and server costs.

## Getting Started

*(Instructions on how to run both the Go server and Flutter app will be added here as the project progresses).*
