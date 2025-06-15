import 'dart:io';

import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';

class Preview extends StatefulWidget {
  final String? outputVideoPath;

  const Preview(this.outputVideoPath, {Key? key}) : super(key: key);

  @override
  State<Preview> createState() => _PreviewState();
}

class _PreviewState extends State<Preview> {
  late BetterPlayerController _controller;

  @override
  void initState() {
    super.initState();

    final betterPlayerDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.file,
      widget.outputVideoPath!,
    );

    // Initialize BetterPlayerController with the data source
    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(), 
      betterPlayerDataSource: betterPlayerDataSource,
    );
    setState(() {}); // Refresh the UI once the video is initialized
    _controller.play(); // Start playback
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Preview"),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: _controller.videoPlayerController?.value.aspectRatio ?? 9/16,
          child: _controller.isVideoInitialized() ?? false
              ? BetterPlayer(controller: _controller)
              : const Center(
                  child: CircularProgressIndicator(
                    backgroundColor: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
