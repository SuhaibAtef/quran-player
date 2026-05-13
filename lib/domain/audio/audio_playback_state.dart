import 'audio_queue_item.dart';
import 'reciter.dart';

enum AudioPlayerStatus {
  idle,
  loading,
  playing,
  paused,
  buffering,
  completed,
  error,
}

class AudioPlaybackState {
  const AudioPlaybackState({
    required this.status,
    required this.queue,
    required this.currentIndex,
    required this.position,
    required this.duration,
    required this.reciter,
    this.message,
  });

  const AudioPlaybackState.idle()
    : status = AudioPlayerStatus.idle,
      queue = const <AudioQueueItem>[],
      currentIndex = -1,
      position = Duration.zero,
      duration = null,
      reciter = null,
      message = null;

  final AudioPlayerStatus status;
  final List<AudioQueueItem> queue;
  final int currentIndex;
  final Duration position;
  final Duration? duration;
  final Reciter? reciter;
  final String? message;

  AudioQueueItem? get currentItem {
    if (currentIndex < 0 || currentIndex >= queue.length) return null;
    return queue[currentIndex];
  }

  bool get hasQueue => queue.isNotEmpty && currentItem != null;

  bool get canGoNext => currentIndex >= 0 && currentIndex < queue.length - 1;

  bool get canGoPrevious => currentIndex > 0 && currentIndex < queue.length;

  bool get isPlaying => status == AudioPlayerStatus.playing;

  AudioPlaybackState copyWith({
    AudioPlayerStatus? status,
    List<AudioQueueItem>? queue,
    int? currentIndex,
    Duration? position,
    Duration? duration,
    Reciter? reciter,
    String? message,
    bool clearMessage = false,
  }) {
    return AudioPlaybackState(
      status: status ?? this.status,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      reciter: reciter ?? this.reciter,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}
