import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class MermaidRenderer {
  /// Renders a mermaid diagram to PNG via mermaid.ink.
  /// Returns null if the network request fails or the source is invalid.
  static Future<Uint8List?> renderToPng(String source) async {
    try {
      final encoded = base64Url.encode(utf8.encode(source));
      // type=png forces PNG; without it mermaid.ink returns JPEG.
      final uri = Uri.parse('https://mermaid.ink/img/$encoded?type=png');
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }
      final bytes = await response.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      client.close();
      final result = Uint8List.fromList(bytes);
      // Reject non-PNG responses (error pages, redirects, etc.)
      if (!_isPng(result)) return null;
      return result;
    } catch (_) {
      return null;
    }
  }

  static bool _isPng(Uint8List b) =>
      b.length >= 8 &&
      b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 &&
      b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A;

  /// Reads width and height from a PNG IHDR chunk (bytes 16–23).
  static (int width, int height) pngDimensions(Uint8List bytes) {
    if (!_isPng(bytes) || bytes.length < 24) return (800, 400);
    // Use explicit byte indexing — more reliable than ByteData with sublist offsets.
    final w = ((bytes[16] & 0xFF) << 24) | ((bytes[17] & 0xFF) << 16) |
              ((bytes[18] & 0xFF) << 8)  |  (bytes[19] & 0xFF);
    final h = ((bytes[20] & 0xFF) << 24) | ((bytes[21] & 0xFF) << 16) |
              ((bytes[22] & 0xFF) << 8)  |  (bytes[23] & 0xFF);
    return (w > 0 ? w : 800, h > 0 ? h : 400);
  }
}
