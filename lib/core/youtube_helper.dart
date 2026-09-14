/// Helper class for parsing video URLs (YouTube, Google Drive, direct links),
/// extracting IDs, and generating embeddable playable URLs.
class YouTubeHelper {
  /// Extracts the 11-character YouTube video ID from standard URLs, short URLs, embed links, and Shorts.
  static String? extractVideoId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final clean = url.trim();

    // Standard YouTube URL regex pattern
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?v=|embed\/|v\/|shorts\/)|youtu\.be\/|youtube-nocookie\.com\/embed\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );

    final match = regExp.firstMatch(clean);
    return match?.group(1);
  }

  /// Returns the high-resolution YouTube thumbnail URL for a given video URL.
  static String getThumbnailUrl(String? url) {
    final videoId = extractVideoId(url);
    if (videoId != null && videoId.isNotEmpty) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    return '';
  }

  /// Returns a clean, embed-friendly URL suitable for in-app WebView playback.
  static String getPlayableUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    final url = rawUrl.trim();

    // 1. YouTube link conversion
    final ytId = extractVideoId(url);
    if (ytId != null && ytId.isNotEmpty) {
      return 'https://www.youtube-nocookie.com/embed/$ytId?enablejsapi=1&origin=https://www.youtube.com&playsinline=1&rel=0&modestbranding=1';
    }

    // 2. Google Drive video preview conversion
    if (url.contains('drive.google.com')) {
      if (url.contains('/view')) {
        return url.replaceAll('/view', '/preview');
      }
      if (!url.contains('/preview') && url.contains('/file/d/')) {
        return '$url/preview';
      }
    }

    return url;
  }

  /// Generates clean HTML wrapper with strict referrer policy and origin compliance for YouTube embeds.
  static String buildPlayerHtml(String videoId) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; background-color: #000000; }
    html, body { width: 100%; height: 100%; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    .iframe-container { position: relative; width: 100%; height: 100%; }
    iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  <div class="iframe-container">
    <iframe 
      id="player"
      src="https://www.youtube-nocookie.com/embed/$videoId?enablejsapi=1&origin=https://www.youtube.com&playsinline=1&rel=0&modestbranding=1&fs=1" 
      frameborder="0"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen" 
      referrerpolicy="strict-origin-when-cross-origin"
      allowfullscreen>
    </iframe>
  </div>
</body>
</html>
''';
  }
}
