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
    // VERY IMPORTANT: Always clean up native video renderers to prevent RAM memory leaks!
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Tell the Riverpod Notifier to ask for permission and start the camera!
          ref.read(callProvider.notifier).initializeCamera();
        },
        label: const Text('Turn Camera On'),
        icon: const Icon(Icons.videocam),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
