import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:better_player/better_player.dart';
import 'package:better_video_trimmer/src/trim_viewer/trim_editor_painter.dart';
import 'package:better_video_trimmer/src/trimmer.dart';
import 'package:better_video_trimmer/src/utils/duration_style.dart';

import '../../utils/editor_drag_type.dart';
import '../trim_area_properties.dart';
import '../trim_editor_properties.dart';
import 'fixed_thumbnail_viewer.dart';

class FixedTrimViewer extends StatefulWidget {
  /// The Trimmer instance controlling the data.
  final Trimmer trimmer;

  /// For defining the total trimmer area width
  final double viewerWidth;

  /// For defining the total trimmer area height
  final double viewerHeight;

  /// Whether the thumbnails should be mirrored.
  /// Defaults to false.
  final bool mirrorThumbnails;

  /// For defining the maximum length of the output video.
  final Duration maxVideoLength;

  /// For showing the start and the end point of the
  /// video on top of the trimmer area.
  ///
  /// By default it is set to `true`.
  final bool showDuration;

  /// For providing a `TextStyle` to the
  /// duration text.
  ///
  /// By default it is set to `TextStyle(color: Colors.white)`
  final TextStyle durationTextStyle;

  /// For specifying a style of the duration
  ///
  /// By default it is set to `DurationStyle.FORMAT_HH_MM_SS`.
  final DurationStyle durationStyle;

  /// Callback to the video start position
  ///
  /// Returns the selected video start position in `milliseconds`.
  final Function(double startValue)? onChangeStart;

  /// Callback to the video end position.
  ///
  /// Returns the selected video end position in `milliseconds`.
  final Function(double endValue)? onChangeEnd;

  /// Callback to the video playback
  /// state to know whether it is currently playing or paused.
  ///
  /// Returns a `boolean` value. If `true`, video is currently
  /// playing, otherwise paused.
  final Function(bool isPlaying)? onChangePlaybackState;

  /// Properties for customizing the trim editor.
  final TrimEditorProperties editorProperties;

  /// Properties for customizing the fixed trim area.
  final FixedTrimAreaProperties areaProperties;

  final VoidCallback onThumbnailLoadingComplete;
  
  /// Initial value for the start position in milliseconds.
  /// Default is null, which means no initial value.
  final double? initialStartValue;
  
  /// Initial value for the end position in milliseconds.
  /// Default is null, which means no initial value.
  final double? initialEndValue;

  /// Widget for displaying the video trimmer.
  ///
  /// This has frame wise preview of the video with a
  /// slider for selecting the part of the video to be
  /// trimmed.
  ///
  /// The required parameters are [viewerWidth] & [viewerHeight]
  ///
  /// * [viewerWidth] to define the total trimmer area width.
  ///
  ///
  /// * [viewerHeight] to define the total trimmer area height.
  ///
  ///
  /// The optional parameters are:
  ///
  /// * [mirrorThumbnails] to mirror or not the thumbnails of the trimmer.
  ///
  ///
  /// * [maxVideoLength] for specifying the maximum length of the
  /// output video.
  ///
  ///
  /// * [showDuration] for showing the start and the end point of the
  /// video on top of the trimmer area. By default it is set to `true`.
  ///
  ///
  /// * [durationTextStyle] is for providing a `TextStyle` to the
  /// duration text. By default it is set to
  /// `TextStyle(color: Colors.white)`
  ///
  ///
  /// * [onChangeStart] is a callback to the video start position.
  ///
  ///
  /// * [onChangeEnd] is a callback to the video end position.
  ///
  ///
  /// * [onChangePlaybackState] is a callback to the video playback
  /// state to know whether it is currently playing or paused.
  ///
  ///
  /// * [editorProperties] defines properties for customizing the trim editor.
  ///
  ///
  /// * [areaProperties] defines properties for customizing the fixed trim area.
  ///
  /// * [initialStartValue] defines the initial start value in milliseconds.
  ///
  ///
  /// * [initialEndValue] defines the initial end value in milliseconds.
  ///
  const FixedTrimViewer({
    super.key,
    required this.trimmer,
    required this.onThumbnailLoadingComplete,
    this.viewerWidth = 50.0 * 8,
    this.viewerHeight = 50,
    this.mirrorThumbnails = false,
    this.maxVideoLength = const Duration(milliseconds: 0),
    this.showDuration = true,
    this.durationTextStyle = const TextStyle(color: Colors.white),
    this.durationStyle = DurationStyle.FORMAT_HH_MM_SS,
    this.onChangeStart,
    this.onChangeEnd,
    this.onChangePlaybackState,
    this.editorProperties = const TrimEditorProperties(),
    this.areaProperties = const FixedTrimAreaProperties(),
    this.initialStartValue,
    this.initialEndValue,
  });

  @override
  State<FixedTrimViewer> createState() => _FixedTrimViewerState();
}

class _FixedTrimViewerState extends State<FixedTrimViewer>
    with TickerProviderStateMixin {
  final _trimmerAreaKey = GlobalKey();
  File? get _videoFile => widget.trimmer.currentVideoFile;

  double _videoStartPos = 0.0;
  double _videoEndPos = 0.0;

  Offset _startPos = const Offset(0, 0);
  Offset _endPos = const Offset(0, 0);

  double _startFraction = 0.0;
  double _endFraction = 1.0;

  int _videoDuration = 0;
  int _currentPosition = 0;

  double _thumbnailViewerW = 0.0;
  double _thumbnailViewerH = 0.0;

  int _numberOfThumbnails = 0;

  late double _startCircleSize;
  late double _endCircleSize;
  late double _borderRadius;

  double? fraction;
  double? maxLengthPixels;

  FixedThumbnailViewer? thumbnailWidget;

  Animation<double>? _scrubberAnimation;
  AnimationController? _animationController;
  late Tween<double> _linearTween;

  /// Quick access to BetterPlayerController, only not null after [TrimmerEvent.initialized]
  /// has been emitted.
  BetterPlayerController get videoPlayerController =>
      widget.trimmer.videoPlayerController!;

  /// Keep track of the drag type, e.g. whether the user drags the left, center or
  /// right part of the frame. Set this in [_onDragStart] when the dragging starts.
  EditorDragType _dragType = EditorDragType.left;

  /// Whether the dragging is allowed. Dragging is ignore if the user's gesture is outside
  /// of the frame, to make the UI more realistic.
  bool _allowDrag = true;

  @override
  void initState() {
    super.initState();
    _startCircleSize = widget.editorProperties.circleSize;
    _endCircleSize = widget.editorProperties.circleSize;
    _borderRadius = widget.editorProperties.borderRadius;
    _thumbnailViewerH = widget.viewerHeight;
    
    log('thumbnailViewerW: $_thumbnailViewerW');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final renderBox =
          _trimmerAreaKey.currentContext?.findRenderObject() as RenderBox?;
      final trimmerActualWidth = renderBox?.size.width;
      log('RENDER BOX: $trimmerActualWidth');
      if (trimmerActualWidth == null) return;
      _thumbnailViewerW = trimmerActualWidth;
      _initializeVideoController();
      videoPlayerController.seekTo(const Duration(milliseconds: 0));
      _numberOfThumbnails = trimmerActualWidth ~/ _thumbnailViewerH;
      log('numberOfThumbnails: $_numberOfThumbnails');
      log('thumbnailViewerW: $_thumbnailViewerW');
      setState(() {
        _thumbnailViewerW = _numberOfThumbnails * _thumbnailViewerH;

        final FixedThumbnailViewer thumbnailWidget = FixedThumbnailViewer(
          videoFile: _videoFile!,
          videoDuration: _videoDuration,
          fit: widget.areaProperties.thumbnailFit,
          thumbnailHeight: _thumbnailViewerH,
          numberOfThumbnails: _numberOfThumbnails,
          quality: widget.areaProperties.thumbnailQuality,
          onThumbnailLoadingComplete: widget.onThumbnailLoadingComplete,
          mirrorThumbnails: widget.mirrorThumbnails,
        );
        this.thumbnailWidget = thumbnailWidget;
        Duration totalDuration = videoPlayerController.videoPlayerController?.value.duration ?? Duration.zero;
        
        if (widget.maxVideoLength > const Duration(milliseconds: 0) &&
            widget.maxVideoLength < totalDuration) {
          if (widget.maxVideoLength < totalDuration) {
            fraction = widget.maxVideoLength.inMilliseconds /
                totalDuration.inMilliseconds;

            maxLengthPixels = _thumbnailViewerW * fraction!;
          }
        } else {
          maxLengthPixels = _thumbnailViewerW;
        }

        // Calculate positions based on initialStartValue/initialEndValue if they exist
        if (widget.initialStartValue != null) {
          // Ensure _videoDuration is not zero to avoid division by zero
          if (_videoDuration > 0) {
            // If initialStartValue is greater than the video duration, default to 0
            if (widget.initialStartValue! > _videoDuration) {
              _videoStartPos = 0.0;
              log('initialStartValue (${widget.initialStartValue}) greater than video duration ($_videoDuration), defaulting to 0');
            } else {
              // Clamp the start value to ensure it's within bounds
              _videoStartPos = widget.initialStartValue!.clamp(0.0, _videoDuration.toDouble());
              log('Using initialStartValue: $_videoStartPos ms (clamped), video duration: $_videoDuration');
            }
            
            // Convert to fraction by dividing milliseconds by milliseconds
            _startFraction = _videoStartPos / _videoDuration.toDouble();
            
            // In the TrimEditorPainter:
            // - startPos is the top-left corner of the trim rectangle
            // - endPos is the bottom-right corner of the trim rectangle
            // The painter draws the trim handles in the middle of the left and right sides
            _startPos = Offset(_startFraction * _thumbnailViewerW, 0);
          } else {
            // Default if video duration is not valid
            _startPos = const Offset(0, 0);
            _startFraction = 0.0;
            _videoStartPos = 0.0;
          }
        } else {
          // Default start position is 0
          _startPos = const Offset(0, 0);
          _startFraction = 0.0;
          _videoStartPos = 0.0;
        }
        
        if (widget.onChangeStart != null) {
          widget.onChangeStart!(_videoStartPos);
        }
        
        if (widget.initialEndValue != null) {
          // Ensure _videoDuration is not zero to avoid division by zero
          if (_videoDuration > 0) {
            double endValue;
            
            // If initialEndValue is greater than video duration, use the video duration
            if (widget.initialEndValue! > _videoDuration) {
              endValue = _videoDuration.toDouble();
              log('initialEndValue (${widget.initialEndValue}) greater than video duration ($_videoDuration), defaulting to video duration');
            } else {
              endValue = widget.initialEndValue!;
            }
            
            // Ensure end is after start by at least 1ms
            _videoEndPos = endValue.clamp(
              _videoStartPos + 1.0,
              _videoDuration.toDouble()
            );
            
            // Convert to fraction by dividing milliseconds by milliseconds
            _endFraction = _videoEndPos / _videoDuration.toDouble();
            
            // Calculate the position but respect maxLengthPixels constraint
            double targetEndPx = _endFraction * _thumbnailViewerW;
            double startPx = _startPos.dx;
            
            // Check if we're exceeding the maxLengthPixels constraint
            if (maxLengthPixels != null && (targetEndPx - startPx) > maxLengthPixels!) {
              // If we'd exceed the max length, limit it
              targetEndPx = startPx + maxLengthPixels!;
              // Recalculate the end fraction and position
              _endFraction = targetEndPx / _thumbnailViewerW;
              _videoEndPos = _videoDuration.toDouble() * _endFraction;
              log('Applied max length constraint: end adjusted to $_videoEndPos ms');
            }
            
            // The end position's y-coordinate should be the height of the trimmer
            _endPos = Offset(targetEndPx, _thumbnailViewerH);
            
            log('Using initialEndValue: $_videoEndPos ms (clamped), fraction: $_endFraction');
          } else {
            // Default if video duration is not valid
            _endPos = Offset(_thumbnailViewerW, _thumbnailViewerH);
            _endFraction = 1.0;
            _videoEndPos = _videoDuration.toDouble();
          }
        } else {
          // Default end position based on fraction or full duration
          _videoEndPos = fraction != null
              ? _videoDuration.toDouble() * fraction!
              : _videoDuration.toDouble();
              
          _endPos = Offset(
            maxLengthPixels != null ? maxLengthPixels! : _thumbnailViewerW,
            _thumbnailViewerH,
          );
          _endFraction = _endPos.dx / _thumbnailViewerW;
        }
        
        if (widget.onChangeEnd != null) {
          widget.onChangeEnd!(_videoEndPos);
        }

        // Defining the tween points
        _linearTween = Tween(begin: _startPos.dx, end: _endPos.dx);
        _animationController = AnimationController(
          vsync: this,
          duration:
              Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt()),
        );

        _scrubberAnimation = _linearTween.animate(_animationController!)
          ..addListener(() {
            setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _animationController!.stop();
            }
          });
      });
    });
  }

  Future<void> _initializeVideoController() async {
    if (_videoFile != null) {
      videoPlayerController.videoPlayerController?.addListener(() {
        final bool isPlaying = videoPlayerController.isPlaying() ?? false ;

        if (isPlaying) {
          widget.onChangePlaybackState!(true);
          setState(() {
            _currentPosition = videoPlayerController.videoPlayerController?.value.position.inMilliseconds ?? 0;

            if (_currentPosition > _videoEndPos.toInt()) {
              videoPlayerController.pause();
              widget.onChangePlaybackState!(false);
              _animationController!.stop();
            } else {
              if (_animationController!=null && !_animationController!.isAnimating) {
                widget.onChangePlaybackState!(true);
                _animationController!.forward();
              }
            }
          });
        } else {
          if (videoPlayerController.isVideoInitialized() ?? false) {
            if (_animationController != null) {
              if ((_scrubberAnimation?.value ?? 0).toInt() ==
                  (_endPos.dx).toInt()) {
                _animationController!.reset();
              }
              _animationController!.stop();
              widget.onChangePlaybackState!(false);
            }
          }
        }
      });

      videoPlayerController.setVolume(1.0);
      _videoDuration = videoPlayerController.videoPlayerController?.value.duration?.inMilliseconds ?? 0;
    }
  }

  /// Called when the user starts dragging the frame, on either side on the whole frame.
  /// Determine which [EditorDragType] is used.
  void _onDragStart(DragStartDetails details) {
    debugPrint("_onDragStart");
    debugPrint(details.localPosition.toString());
    debugPrint((_startPos.dx - details.localPosition.dx).abs().toString());
    debugPrint((_endPos.dx - details.localPosition.dx).abs().toString());

    final startDifference = _startPos.dx - details.localPosition.dx;
    final endDifference = _endPos.dx - details.localPosition.dx;

    // First we determine whether the dragging motion should be allowed. The allowed
    // zone is widget.sideTapSize (left) + frame (center) + widget.sideTapSize (right)
    if (startDifference <= widget.editorProperties.sideTapSize &&
        endDifference >= -widget.editorProperties.sideTapSize) {
      _allowDrag = true;
    } else {
      debugPrint("Dragging is outside of frame, ignoring gesture...");
      _allowDrag = false;
      return;
    }

    // Now we determine which part is dragged
    if (details.localPosition.dx <=
        _startPos.dx + widget.editorProperties.sideTapSize) {
      _dragType = EditorDragType.left;
    } else if (details.localPosition.dx <=
        _endPos.dx - widget.editorProperties.sideTapSize) {
      _dragType = EditorDragType.center;
    } else {
      _dragType = EditorDragType.right;
    }
  }

  /// Called during dragging, only executed if [_allowDrag] was set to true in
  /// [_onDragStart].
  /// Makes sure the limits are respected.
  void _onDragUpdate(DragUpdateDetails details) {
    if (!_allowDrag) return;

    if (_dragType == EditorDragType.left) {
      _startCircleSize = widget.editorProperties.circleSizeOnDrag;
      if ((_startPos.dx + details.delta.dx >= 0) &&
          (_startPos.dx + details.delta.dx <= _endPos.dx) &&
          !(_endPos.dx - _startPos.dx - details.delta.dx > maxLengthPixels!)) {
        _startPos += details.delta;
        _onStartDragged();
      }
    } else if (_dragType == EditorDragType.center) {
      _startCircleSize = widget.editorProperties.circleSizeOnDrag;
      _endCircleSize = widget.editorProperties.circleSizeOnDrag;
      if ((_startPos.dx + details.delta.dx >= 0) &&
          (_endPos.dx + details.delta.dx <= _thumbnailViewerW)) {
        _startPos += details.delta;
        _endPos += details.delta;
        _onStartDragged();
        _onEndDragged();
      }
    } else {
      _endCircleSize = widget.editorProperties.circleSizeOnDrag;
      if ((_endPos.dx + details.delta.dx <= _thumbnailViewerW) &&
          (_endPos.dx + details.delta.dx >= _startPos.dx) &&
          !(_endPos.dx - _startPos.dx + details.delta.dx > maxLengthPixels!)) {
        _endPos += details.delta;
        _onEndDragged();
      }
    }
    setState(() {});
  }

  void _onStartDragged() {
    _startFraction = (_startPos.dx / _thumbnailViewerW);
    _videoStartPos = _videoDuration * _startFraction;
    widget.onChangeStart!(_videoStartPos);
    _linearTween.begin = _startPos.dx;
    _animationController!.duration =
        Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt());
    _animationController!.reset();
  }

  void _onEndDragged() {
    _endFraction = _endPos.dx / _thumbnailViewerW;
    _videoEndPos = _videoDuration * _endFraction;
    widget.onChangeEnd!(_videoEndPos);
    _linearTween.end = _endPos.dx;
    _animationController!.duration =
        Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt());
    _animationController!.reset();
  }

  /// Drag gesture ended, update UI accordingly.
  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _startCircleSize = widget.editorProperties.circleSize;
      _endCircleSize = widget.editorProperties.circleSize;
      if (_dragType == EditorDragType.right) {
        videoPlayerController
            .seekTo(Duration(milliseconds: _videoEndPos.toInt()));
      } else {
        videoPlayerController
            .seekTo(Duration(milliseconds: _videoStartPos.toInt()));
      }
    });
  }

  @override
  void dispose() {
    videoPlayerController.pause();
    widget.onChangePlaybackState!(false);
    if (_videoFile != null) {
      videoPlayerController.setVolume(0.0);
      videoPlayerController.dispose();
      widget.onChangePlaybackState!(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          widget.showDuration
              ? SizedBox(
                  width: _thumbnailViewerW,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Text(
                          Duration(milliseconds: _videoStartPos.toInt())
                              .format(widget.durationStyle),
                          style: widget.durationTextStyle,
                        ),
                        videoPlayerController.isPlaying() ?? false
                            ? Text(
                                Duration(milliseconds: _currentPosition.toInt())
                                    .format(widget.durationStyle),
                                style: widget.durationTextStyle,
                              )
                            : Container(),
                        Text(
                          Duration(milliseconds: _videoEndPos.toInt())
                              .format(widget.durationStyle),
                          style: widget.durationTextStyle,
                        ),
                      ],
                    ),
                  ),
                )
              : Container(),
          CustomPaint(
            foregroundPainter: TrimEditorPainter(
              startPos: _startPos,
              endPos: _endPos,
              scrubberAnimationDx: _scrubberAnimation?.value ?? 0,
              startCircleSize: _startCircleSize,
              endCircleSize: _endCircleSize,
              borderRadius: _borderRadius,
              borderWidth: widget.editorProperties.borderWidth,
              scrubberWidth: widget.editorProperties.scrubberWidth,
              circlePaintColor: widget.editorProperties.circlePaintColor,
              borderPaintColor: widget.editorProperties.borderPaintColor,
              scrubberPaintColor: widget.editorProperties.scrubberPaintColor,
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(widget.areaProperties.borderRadius),
              child: Container(
                key: _trimmerAreaKey,
                color: Colors.grey[900],
                height: _thumbnailViewerH,
                width: _thumbnailViewerW == 0.0
                    ? widget.viewerWidth
                    : _thumbnailViewerW,
                child: thumbnailWidget ?? Container(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
