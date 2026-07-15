#  HelixRTC

**HelixRTC** is a modern, high-performance, cross-platform real-time communication (RTC) application. Built from the ground up, it provides seamless peer-to-peer (P2P) video calling and low-latency data streaming using WebRTC. 

Unlike traditional centralized video platforms that route all your heavy video traffic through a server, HelixRTC leverages true Peer-to-Peer architecture. The servers are only used to introduce the peers to one another; after that, all video, audio, and chat data flows directly between the two devices.

This repository is structured as a **monorepo**, containing both the backend signaling infrastructure and the rich frontend client application. This guarantees a tightly coupled, fully synchronous environment where both ends of the stack evolve together.

---

##  System Architecture

HelixRTC is divided into two distinct components that work in harmony:

### 1. The Signaling Server (`/signaling-server`)
Written in highly concurrent **Go (Golang)** using the `gorilla/websocket` library. 
WebRTC requires peers to exchange network and media information (SDP Offers, Answers, and ICE Candidates) before they can connect directly. The signaling server acts as the "matchmaker". 
*   **Rooms System:** Manages isolated rooms utilizing concurrent-safe Go maps and mutexes.
*   **Zero-Media Routing:** The server never touches your video, audio, or chat data. It only routes the initial metadata required to establish the P2P connection.

### 2. The Client Application (`/app`)
A beautiful, cross-platform client built with **Flutter**.
*   **Platforms:** Compiles natively for Web, Android, and iOS from a single codebase.
*   **WebRTC Engine:** Uses `flutter_webrtc` to bind directly to native WebRTC APIs on mobile, and standard browser WebRTC APIs on the web.
*   **State Management:** Utilizes **Riverpod** for a reactive, rigorously decoupled architecture. Business logic (WebRTC handshakes, data channels) is strictly separated from the UI layer.

---

##  Core Features

*   **Secure Room Generation:** Instantly generate randomized, secure 5-digit room codes to share with peers.
*   **True P2P Media:** High-definition video and crystal-clear audio streamed directly between devices for minimal latency and maximum privacy.
*   **Serverless Chat (RTCDataChannel):** Secure text chat built directly into the WebRTC protocol. Messages are sent through the P2P data channel—bypassing databases and servers entirely.
*   **Smart Notifications:** Unread message notification badges intelligently track chat activity when the chat drawer is closed.
*   **Dynamic Media Controls:** 
    *   Mute/Unmute Microphone
    *   Enable/Disable Camera
    *   Flip Camera (Front/Rear on mobile devices)
*   **Premium UI/UX:** A stunning dark-mode interface featuring glassmorphic elements, dynamic bottom sheets, and picture-in-picture (PiP) local video rendering.
*   **Graceful Lifecycle Management:** The app automatically cleans up hardware resources (cameras/mics), handles unexpected peer disconnections gracefully, and prevents more than 2 users from joining a P2P mesh room.

---

##  Getting Started

Follow these instructions to get the complete stack running on your local machine.

### Prerequisites
*   [Go](https://golang.org/doc/install) (v1.20+)
*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.19+)
*   A physical mobile device or emulator, plus a web browser for testing.

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/HelixRTC.git
cd HelixRTC
```

### 2. IMPORTANT: Configure Your Local Network IP
By default, the Flutter app looks for the signaling server on `localhost`. While this works perfectly if you are opening two Chrome tabs on the same computer, **it will fail if you test between a computer and a physical mobile phone**. Your phone does not know what `localhost` is.

To fix this, you must point the app to your computer's local Wi-Fi IP address:

1. **Find your computer's local IP address:**
   *   **Mac:** `ipconfig getifaddr en0` (usually starts with `192.168.x.x` or `10.x.x.x`)
   *   **Windows:** Run `ipconfig` in CMD and look for "IPv4 Address".
   *   **Linux:** Run `hostname -I`.
2. Open the provider file: `/app/lib/presentation/providers/webrtc_provider.dart`.
3. Locate the `wsUrl` variable around line 43.
4. Replace the IP address with your actual local IP.
   ```dart
   // CHANGE THIS to your machine's IP address!
   // Example: final wsUrl = 'ws://192.168.1.15:8080/ws';
   final wsUrl = 'ws://YOUR_LOCAL_IP:8080/ws';
   ```
*(Ensure both your computer and your testing phone are connected to the exact same Wi-Fi network).*

### 3. Start the Signaling Server
Open a terminal, navigate into the server directory, and boot it up:
```bash
cd signaling-server
go run main.go
```
*You should see a message indicating the server is running on port 8080.*

### 4. Boot the Flutter Application
Open a new terminal, navigate into the client directory, install dependencies, and launch:
```bash
cd app
flutter pub get

# To run on a Web Browser (great for testing the first peer)
flutter run -d chrome

# To run on an attached Android or iOS device (great for the second peer)
flutter run
```

### 5. Establish Your First Call
1. Open the app on **Device A**. Grant camera/microphone permissions.
2. Tap **Create Room**. The app will generate a 5-digit room code.
3. Open the app on **Device B**. Grant permissions.
4. Tap **Join Room** and enter the code generated by Device A.
5. The Go server will route the SDP and ICE candidates. Within milliseconds, the WebRTC P2P connection will snap together.
6. **You are now in a decentralized call!** Test the camera toggles and open the chat drawer to send P2P data messages.

---

##  Future Roadmap (V2.0)

While HelixRTC V1 is a flawless demonstration of a 1-to-1 WebRTC Mesh network, future iterations plan to explore:
*   **SFU (Selective Forwarding Unit) Architecture:** Integrating a media server (like Pion or Mediasoup) to support large group calls (10+ participants) by reducing uplink bandwidth strain on individual clients.
*   **TURN Server Integration:** Implementing Coturn to guarantee connections across restrictive enterprise firewalls and symmetric NATs.
*   **Screen Sharing:** Expanding the WebRTC media tracks to support desktop and mobile screen broadcasting.

---

*Built with passion, Flutter, and Go.*
