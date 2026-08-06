import 'dart:math';

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
  // The RTCVideoRenderer is the actual GPU canvas that displays raw camera pixels.
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  @override
  void initState() {
    super.initState();
    _initializeLocalRenderer();
  }

  Future<void> _initializeLocalRenderer() async {
    await _localRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    super.dispose();
  }

  Future<void> _syncRemoteRenderers(
    Map<String, MediaStream> remoteStreams,
  ) async {
    // 1. Add new streams
    for (final entry in remoteStreams.entries) {
      final peerId = entry.key;
      final stream = entry.value;

      if (!_remoteRenderers.containsKey(peerId)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = stream;
        if (mounted) {
          setState(() {
            _remoteRenderers[peerId] = renderer;
          });
        }
      } else if (_remoteRenderers[peerId]?.srcObject != stream) {
        _remoteRenderers[peerId]?.srcObject = stream;
      }
    }

    // 2. Remove disconnected streams
    final removedIds = _remoteRenderers.keys
        .where((id) => !remoteStreams.containsKey(id))
        .toList();

    for (final peerId in removedIds) {
      _remoteRenderers[peerId]?.dispose();
      if (mounted) {
        setState(() {
          _remoteRenderers.remove(peerId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);

    // Sync remote renderers with remoteStreams map from Riverpod state
    _syncRemoteRenderers(callState.remoteStreams);

    // Listen for room full errors to show a UI alert
    ref.listen<CallState>(callProvider, (previous, next) {
      if (next.isRoomFull && (previous == null || !previous.isRoomFull)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room is full. Only 4 participants allowed.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    // Assign local stream to local renderer when ready
    if (callState.localStream != null && _localRenderer.srcObject == null) {
      setState(() {
        _localRenderer.srcObject = callState.localStream;
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          callState.isJoined
              ? 'Room: ${callState.roomId}'
              : 'HelixRTC Video Call',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // DYNAMIC VIDEO LAYOUT (1-on-1 PIP or 2x2 Grid)
            Positioned.fill(child: _buildVideoLayout(callState)),
          ],
        ),
      ),
      floatingActionButton: callState.localStream == null
          ? FloatingActionButton.extended(
              onPressed: () {
                ref.read(callProvider.notifier).initializeCamera();
              },
              label: const Text('Turn Camera On'),
              icon: const Icon(Icons.videocam),
              backgroundColor: Colors.blueAccent,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toolbar
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'mic_toggle',
                      onPressed: () =>
                          ref.read(callProvider.notifier).toggleAudio(),
                      backgroundColor: callState.isAudioMuted
                          ? Colors.red
                          : Colors.white24,
                      elevation: 0,
                      child: Icon(
                        callState.isAudioMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'video_toggle',
                      onPressed: () =>
                          ref.read(callProvider.notifier).toggleVideo(),
                      backgroundColor: callState.isVideoMuted
                          ? Colors.red
                          : Colors.white24,
                      elevation: 0,
                      child: Icon(
                        callState.isVideoMuted
                            ? Icons.videocam_off
                            : Icons.videocam,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'camera_switch',
                      onPressed: () =>
                          ref.read(callProvider.notifier).switchCamera(),
                      backgroundColor: Colors.white24,
                      elevation: 0,
                      child: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                      ),
                    ),
                    if (callState.remoteStreams.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Badge(
                        isLabelVisible: callState.unreadMessageCount > 0,
                        label: Text('${callState.unreadMessageCount}'),
                        child: FloatingActionButton(
                          heroTag: 'chat_toggle',
                          onPressed: () => _showChatSheet(context),
                          backgroundColor: Colors.purpleAccent,
                          elevation: 0,
                          child: const Icon(Icons.chat, color: Colors.white),
                        ),
                      ),
                    ],
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
                        heroTag: 'create_room',
                        onPressed: () => _showCreateRoomDialog(context),
                        label: const Text('Create Room'),
                        icon: const Icon(Icons.add_box),
                        backgroundColor: Colors.green,
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton.extended(
                        heroTag: 'join_room',
                        onPressed: () => _showJoinRoomDialog(context),
                        label: const Text('Join Room'),
                        icon: const Icon(Icons.login),
                        backgroundColor: Colors.blueAccent,
                      ),
                    ],
                  ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildVideoLayout(CallState callState) {
    final remoteCount = _remoteRenderers.length;

    // 0 Remote Peers: Show local stream or Camera Off card
    if (remoteCount == 0) {
      if (callState.localStream != null) {
        return _buildVideoTile(
          _localRenderer,
          label: 'You',
          isLocal: true,
          isVideoMuted: callState.isVideoMuted,
        );
      }
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_rounded, size: 80, color: Colors.white30),
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
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // 1 Remote Peer: Full Screen Remote + PIP Local Overlay
    if (remoteCount == 1) {
      final peerId = _remoteRenderers.keys.first;
      final remoteRenderer = _remoteRenderers.values.first;

      return Stack(
        children: [
          Positioned.fill(
            child: _buildVideoTile(remoteRenderer, label: peerId),
          ),
          if (callState.localStream != null)
            Positioned(
              right: 20,
              bottom: 100,
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
                  child: callState.isVideoMuted
                      ? Container(
                          color: Color(0xFF1E1E1E),
                          child: Center(
                            child: Icon(
                              Icons.videocam_off,
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : RTCVideoView(
                          _localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                ),
              ),
            ),
        ],
      );
    }

    // 2+ Remote Peers: 2x2 Grid View for up to 4 participants
    final tiles = <Widget>[];

    if (callState.localStream != null) {
      tiles.add(
        _buildVideoTile(
          _localRenderer,
          label: 'You',
          isLocal: true,
          isVideoMuted: callState.isVideoMuted,
        ),
      );
    }

    for (final entry in _remoteRenderers.entries) {
      tiles.add(_buildVideoTile(entry.value, label: entry.key));
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
        children: tiles,
      ),
    );
  }

  Widget _buildVideoTile(
    RTCVideoRenderer renderer, {
    required String label,
    bool isLocal = false,
    bool isVideoMuted = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: isVideoMuted
                  ? Container(
                      color: Color(0xFF1E1E1E),
                      child: Center(
                        child: Icon(
                          Icons.videocam_off,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    )
                  : RTCVideoView(
                      renderer,
                      mirror: isLocal,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context) {
    final nameController = TextEditingController();

    // Generate a random 5-digit room code
    final randomRoomId = (10000 + Random().nextInt(90000)).toString();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Create a Room',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share this code with your friend:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                randomRoomId,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4.0,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  ref.read(callProvider.notifier).joinRoom(randomRoomId, name);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: const Text(
                'Create & Join',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showJoinRoomDialog(BuildContext context) {
    final roomIdController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Join a Room',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomIdController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Room ID (e.g. 101)',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final room = roomIdController.text.trim();
                final name = nameController.text.trim();
                if (room.isNotEmpty && name.isNotEmpty) {
                  ref.read(callProvider.notifier).joinRoom(room, name);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: const Text('Join', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showChatSheet(BuildContext context) {
    ref.read(callProvider.notifier).setChatOpen(true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _ChatSheet();
      },
    ).then((_) {
      ref.read(callProvider.notifier).setChatOpen(false);
    });
  }
}

class _ChatSheet extends ConsumerStatefulWidget {
  const _ChatSheet();

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref.read(callProvider.notifier).sendChatMessage(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);
    final messages = callState.messages;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return Align(
                    alignment: msg.isLocal
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: msg.isLocal ? Colors.blueAccent : Colors.white24,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        msg.text,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              color: const Color(0xFF121212),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
