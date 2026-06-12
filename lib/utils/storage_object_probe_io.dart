import 'dart:io';

/// Lightweight range GET — confirms a public Firebase Storage object exists without auth.
Future<bool> storageObjectExistsAtUrl(String mediaUrl) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client.getUrl(Uri.parse(mediaUrl));
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    final response = await request.close().timeout(const Duration(seconds: 3));
    return response.statusCode == 200 || response.statusCode == 206;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}
