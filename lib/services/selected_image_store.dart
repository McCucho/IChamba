import 'package:flutter/foundation.dart';

class SelectedImageStore {
  SelectedImageStore._private();

  static final SelectedImageStore instance = SelectedImageStore._private();

  /// Notifier that holds the latest selected image bytes (nullable).
  final ValueNotifier<Uint8List?> imageNotifier = ValueNotifier<Uint8List?>(
    null,
  );

  /// Optional filename for display/metadata
  final ValueNotifier<String?> filenameNotifier = ValueNotifier<String?>(null);

  /// Optional public avatar URL stored in backend (Supabase)
  final ValueNotifier<String?> avatarUrlNotifier = ValueNotifier<String?>(null);

  /// Notifier to indicate posts list has changed (increment to notify listeners)
  final ValueNotifier<int> postsVersion = ValueNotifier<int>(0);

  void setImage(Uint8List? bytes, [String? filename]) {
    imageNotifier.value = bytes;
    filenameNotifier.value = filename;
  }

  void setAvatarUrl(String? url) {
    avatarUrlNotifier.value = url;
  }

  void clear() {
    imageNotifier.value = null;
    filenameNotifier.value = null;
  }

  void notifyPostsChanged() {
    postsVersion.value = postsVersion.value + 1;
  }
}
