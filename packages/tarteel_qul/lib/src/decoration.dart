import 'package:flutter/widgets.dart';

import 'ayah_key.dart';

/// A visual mark a consumer asks `MushafView` to paint over an ayah.
///
/// `MushafView` renders decorations without knowing what they mean — an
/// active-playback highlight, a search hit, a bookmark. Today the only field
/// is a fill colour; the type exists so future marks extend it without
/// changing the `MushafView` API.
@immutable
class MushafDecoration {
  const MushafDecoration({required this.ayah, required this.color});

  /// The ayah whose words this decoration is painted behind.
  final AyahKey ayah;

  /// The fill colour painted behind the ayah's words.
  final Color color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MushafDecoration && other.ayah == ayah && other.color == color;

  @override
  int get hashCode => Object.hash(ayah, color);
}
