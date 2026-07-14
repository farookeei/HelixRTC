import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../providers/webrtc_provider.dart';
import '../providers/call_state.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  // The RTCVideoRenderer is the actual GPU canvas that displays our raw camera pixels.
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  /// We must initialize the WebRTC renderers in the background when the page mounts
  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    //  clean up native video renderers to prevent RAM memory leaks!
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the call state for updates (like when localStream changes from null to a real stream)
    final callState = ref.watch(callProvider);

    // Listen for room full errors to show a UI alert
    ref.listen<CallState>(callProvider, (previous, next) {
      if (next.isRoomFull && (previous == null || !previous.isRoomFull)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room is full. Only 2 participants allowed.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    // If local stream becomes available, assign it to our local renderer
    if (callState.localStream != null && _localRenderer.srcObject == null) {
      setState(() {
        _localRenderer.srcObject = callState.localStream;
      });
    }

    // If remote stream becomes available, assign it to our remote renderer
    if (callState.remoteStream != null && _remoteRenderer.srcObject == null) {
      setState(() {
        _remoteRenderer.srcObject = callState.remoteStream;
      });
    }

    // Clear remote stream when it's null (e.g. peer left)
    if (callState.remoteStream == null && _remoteRenderer.srcObject != null) {
      setState(() {
        _remoteRenderer.srcObject = null;
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Premium dark mode background
      appBar: AppBar(
        title: Text(
          callState.isJoined 
              ? 'Room: ${callState.roomId}' 
              : 'HelixRTC Video Call',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. MAIN BACKGROUND VIEW (Remote stream if connected, else a nice dark card)
            Positioned.fill(
              child: callState.remoteStream != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: RTCVideoView(
                        _remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    )
                  : Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: callState.localStream != null
                              ? RTCVideoView(
                                  _localRenderer,
                                  mirror: true,
                                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.videocam_off_rounded,
                                      size: 80,
                                      color: Colors.white30,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Camera is Off',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Turn on camera to join or start a call',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
            ),
            
            // 2. PIP VIEW (Float local stream in bottom-right corner when remote is active)
            if (callState.remoteStream != null && callState.localStream != null)
              Positioned(
                right: 20,
                bottom: 100, // Float above buttons
                width: 110,
                height: 160,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: callState.localStream == null
          ? FloatingActionButton.extended(
              onPressed: () {
                // Tell the Riverpod Notifier to ask for permission and start the camera!
                ref.read(callProvider.notifier).initializeCamera();
              },
              label: const Text('Turn Camera On'),
              icon: const Icon(Icons.videocam),
              backgroundColor: Colors.blueAccent,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Media Controls Toolbar
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'mic_toggle',
                      onPressed: () => ref.read(callProvider.notifier).toggleAudio(),
                      backgroundColor: callState.isAudioMuted ? Colors.red : Colors.white24,
                      elevation: 0,
                      child: Icon(callState.isAudioMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'video_toggle',
                      onPressed: () => ref.read(callProvider.notifier).toggleVideo(),
                      backgroundColor: callState.isVideoMuted ? Colors.red : Colors.white24,
                      elevation: 0,
                      child: Icon(callState.isVideoMuted ? Icons.videocam_off : Icons.videocam, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'camera_switch',
                      onPressed: () => ref.read(callProvider.notifier).switchCamera(),
                      backgroundColor: Colors.white24,
                      elevation: 0,
                      child: const Icon(Icons.flip_camera_ios, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 2. Connection Controls
                if (callState.isConnecting)
                  const FloatingActionButton.extended(
                    onPressed: null,
                    label: Text('Connecting...'),
                    icon: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    backgroundColor: Colors.grey,
                  )
                else if (callState.isJoined)
                  FloatingActionButton.extended(
                    heroTag: 'leave_room',
                    onPressed: () {
                      ref.read(callProvider.notifier).leaveRoom();
                    },
                    label: Text('Leave Room ${callState.roomId}'),
                    icon: const Icon(Icons.call_end),
                    backgroundColor: Colors.red,
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'join_alice',
                        onPressed: () {
                          ref.read(callProvider.notifier).joinRoom('101', 'Alice');
                        },
                        label: const Text('Join as Alice'),
                        icon: const Icon(Icons.person),
                        backgroundColor: Colors.green,
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton.extended(
                        heroTag: 'join_bob',
                        onPressed: () {
                          ref.read(callProvider.notifier).joinRoom('101', 'Bob');
                        },
                        label: const Text('Join as Bob'),
                        icon: const Icon(Icons.person_outline),
                        backgroundColor: Colors.blueAccent,
                      ),
                    ],
                  ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
