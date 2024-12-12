import 'package:flutter/material.dart';
import 'package:better_player/better_player.dart';

import 'trimmer.dart';

class VideoViewer extends StatefulWidget {
  /// The Trimmer instance controlling the data.
  final Trimmer trimmer;

  /// For specifying the color of the video
  /// viewer area border. By default it is set to `Colors.transparent`.
  final Color borderColor;

  /// For specifying the border width around
  /// the video viewer area. By default it is set to `0.0`.
  final double borderWidth;

  /// For specifying a padding around the video viewer
  /// area. By default it is set to `EdgeInsets.all(0.0)`.
  final EdgeInsets padding;

  // ignore: use_key_in_widget_constructors
  /// For showing the video playback area.
  ///
  /// This only contains optional parameters. They are:
  ///
  /// * [borderColor] for specifying the color of the video
  /// viewer area border. By default it is set to `Colors.transparent`.
  ///
  ///
  /// * [borderWidth] for specifying the border width around
  /// the video viewer area. By default it is set to `0.0`.
  ///
  ///
  /// * [padding] for specifying a padding around the video viewer
  /// area. By default it is set to `EdgeInsets.all(0.0)`.
  ///
  const VideoViewer({
    Key? key,
    required this.trimmer,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
    this.padding = const EdgeInsets.all(0.0),
  }) : super(key: key);

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  /// Quick access to BetterPlayerController, only not null after [TrimmerEvent.initialized]
  /// has been emitted.
  BetterPlayerController? get videoPlayerController =>
      widget.trimmer.videoPlayerController;

  @override
  void initState() {
    widget.trimmer.eventStream.listen((event) {
      // logger.i('BetterTrimmer: Received an event ${event.toString()}');
      if (event == TrimmerEvent.initialized) {
        //The video has been initialized, now we can load stuff
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final controller = videoPlayerController;
    if (controller == null) {
      return Container();
    }
    return Padding(
      padding: widget.padding,
      child: Center(
        child: controller.isVideoInitialized() ?? false
          ? Container(
              foregroundDecoration: BoxDecoration(
                border: Border.all(
                  width: widget.borderWidth,
                  color: widget.borderColor,
                ),
              ),
              child: BetterPlayer(controller: controller),
            )
          : const Center(
              child: CircularProgressIndicator(
                backgroundColor: Colors.white,
              ),
            ),
      ),
    );
  }

  @override
  void dispose() {
    widget.trimmer.dispose();
    super.dispose();
  }
}
