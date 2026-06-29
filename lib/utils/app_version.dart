/// Semantic version parsed from pubspec (`1.0.0`) or build metadata (`1.0.0+4`).
class AppVersion implements Comparable<AppVersion> {
  const AppVersion({required this.major, required this.minor, required this.patch});

  final int major;
  final int minor;
  final int patch;

  static AppVersion parse(String raw) {
    final versionPart = raw.trim().split('+').first;
    final segments = versionPart.split('.');
    int part(int index) => int.tryParse(segments.elementAtOrNull(index) ?? '') ?? 0;
    return AppVersion(major: part(0), minor: part(1), patch: part(2));
  }

  bool isOlderThan(AppVersion other) => compareTo(other) < 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}
