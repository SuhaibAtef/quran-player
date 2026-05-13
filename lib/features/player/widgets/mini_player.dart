import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../domain/audio/audio_playback_state.dart';
import '../state/audio_player_controller.dart';

class MiniPlayerKeys {
  const MiniPlayerKeys._();

  static const root = Key('player.mini.root');
  static const artwork = Key('player.mini.artwork');
  static const title = Key('player.mini.title');
  static const subtitle = Key('player.mini.subtitle');
  static const previous = Key('player.mini.previous');
  static const playPause = Key('player.mini.play_pause');
  static const next = Key('player.mini.next');
  static const progress = Key('player.mini.progress');
  static const expanded = Key('player.expanded');
}

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerControllerProvider);
    if (!state.hasQueue) return const SizedBox.shrink();

    return DecoratedBox(
      key: MiniPlayerKeys.root,
      decoration: BoxDecoration(
        color: context.theme.colors.background,
        border: Border(
          top: BorderSide(color: context.theme.colors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProgressBar(
                    key: MiniPlayerKeys.progress,
                    state: state,
                    onSeek: (position) => ref
                        .read(audioPlayerControllerProvider.notifier)
                        .seek(position),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Artwork(state: state),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => showExpandedPlayer(context),
                          child: _TrackLabels(state: state, compact: compact),
                        ),
                      ),
                      if (!compact) const SizedBox(width: 12),
                      _TransportControls(state: state),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> showExpandedPlayer(BuildContext context) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: 0.72,
    builder: (_) => const _ExpandedPlayer(),
  );
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.state});

  final AudioPlaybackState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: MiniPlayerKeys.artwork,
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.theme.colors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'MR',
        style: context.theme.typography.sm.copyWith(
          color: context.theme.colors.primaryForeground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrackLabels extends StatelessWidget {
  const _TrackLabels({required this.state, required this.compact});

  final AudioPlaybackState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final item = state.currentItem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item?.label ?? 'Quran recitation',
          key: MiniPlayerKeys.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.theme.typography.sm.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          state.reciter?.name ?? 'Default reciter',
          key: MiniPlayerKeys.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.theme.typography.xs,
        ),
      ],
    );
  }
}

class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.state});

  final AudioPlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final isPlaying =
        state.status == AudioPlayerStatus.playing ||
        state.status == AudioPlayerStatus.buffering;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FButton(
          key: MiniPlayerKeys.previous,
          variant: FButtonVariant.ghost,
          onPress: state.canGoPrevious ? controller.previous : null,
          child: const Icon(FIcons.skipBack),
        ),
        FButton(
          key: MiniPlayerKeys.playPause,
          variant: FButtonVariant.primary,
          onPress: isPlaying ? controller.pause : controller.play,
          child: Icon(isPlaying ? FIcons.pause : FIcons.play),
        ),
        FButton(
          key: MiniPlayerKeys.next,
          variant: FButtonVariant.ghost,
          onPress: state.canGoNext ? controller.next : null,
          child: const Icon(FIcons.skipForward),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.state, required this.onSeek, super.key});

  final AudioPlaybackState state;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final duration = state.duration ?? state.currentItem?.track.duration;
    final totalMs = duration?.inMilliseconds ?? 0;
    final currentMs = state.position.inMilliseconds.clamp(0, totalMs);
    final fraction = totalMs == 0 ? 0.0 : currentMs / totalMs;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: totalMs == 0
          ? null
          : (details) {
              final box = context.findRenderObject() as RenderBox?;
              final width = box?.size.width ?? 1;
              final raw = (details.localPosition.dx / width).clamp(0.0, 1.0);
              onSeek(Duration(milliseconds: (totalMs * raw).round()));
            },
      child: Container(
        height: 10,
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(height: 4, color: context.theme.colors.secondary),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 4,
                  color: context.theme.colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedPlayer extends ConsumerWidget {
  const _ExpandedPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerControllerProvider);
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    return Padding(
      key: MiniPlayerKeys.expanded,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Artwork(state: state),
              const SizedBox(width: 12),
              Expanded(child: _TrackLabels(state: state, compact: false)),
              _TransportControls(state: state),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressBar(state: state, onSeek: controller.seek),
          const SizedBox(height: 16),
          Text(
            'Queue',
            style: context.theme.typography.sm.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.queue.length,
              itemBuilder: (context, index) {
                final item = state.queue[index];
                final selected = index == state.currentIndex;
                return FTile(
                  selected: selected,
                  prefix: Icon(
                    selected ? FIcons.volume2 : FIcons.play,
                    size: 16,
                  ),
                  title: Text(item.label),
                  subtitle: Text(item.track.ayahKey.toString()),
                  onPress: () => controller.jumpTo(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
