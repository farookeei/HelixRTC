import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../providers/webrtc_provider.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  // The RTCVideoRenderer is the actual GPU canvas that displays our raw camera pixels.
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  /// We must initialize the WebRTC renderers in the background when the page mounts
  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
  }

  @override
  void dispose() {
    //  clean up native video renderers to prevent RAM memory leaks!
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the call state for updates (like when localStream changes from null to a real stream)
    final callState = ref.watch(callProvider);

    // If a stream becomes available, assign it to our renderer
    if (callState.localStream != null && _localRenderer.srcObject == null) {
      setState(() {
        _localRenderer.srcObject = callState.localStream;
      });
    }

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('HelixRTC Call Screen'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 320,
            height: 480,
            child: callState.localStream != null
                ? RTCVideoView(
                    _localRenderer,
                    mirror:
                        true, // Mirrors front camera feed so it looks natural
                    objectFit: RTCVideoViewObjectFit
                        .RTCVideoViewObjectFitCover, // Crop to cover box
                  )
                : Container(
                    color: Colors.grey[900],
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_off,
                          size: 64,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Camera is Off',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
          ),
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
          : callState.isConnecting
              ? const FloatingActionButton.extended(
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
              : callState.isJoined
                  ? FloatingActionButton.extended(
                      onPressed: () {
                        // Leave the room
                        ref.read(callProvider.notifier).leaveRoom();
                      },
                      label: Text('Leave Room ${callState.roomId}'),
                      icon: const Icon(Icons.call_end),
                      backgroundColor: Colors.red,
                    )
                  : FloatingActionButton.extended(
                      onPressed: () {
                        // Join the room via signaling
                        ref.read(callProvider.notifier).joinRoom('101', 'Alice');
                      },
                      label: const Text('Join Room 101'),
                      icon: const Icon(Icons.group_add),
                      backgroundColor: Colors.green,
                    ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
