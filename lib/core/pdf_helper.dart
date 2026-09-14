/// Helper class for parsing, cleaning, and formatting PDF, Medical Journal,
/// and document URLs for embedded in-app flipbook rendering.
class PdfHelper {
  /// Extracts Google Drive File ID from various link formats.
  static String? extractGoogleDriveFileId(String url) {
    if (!url.contains('drive.google.com') && !url.contains('docs.google.com')) {
      return null;
    }

    // Pattern 1: /file/d/FILE_ID/
    final fileMatch = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (fileMatch != null && fileMatch.groupCount >= 1) {
      return fileMatch.group(1);
    }

    // Pattern 2: id=FILE_ID
    final idMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (idMatch != null && idMatch.groupCount >= 1) {
      return idMatch.group(1);
    }

    return null;
  }

  /// Returns a clean, embed-friendly URL suitable for in-app WebView playback/reading.
  static String getPlayablePdfUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    final url = rawUrl.trim();

    // 1. Interactive HTML5 Flipbook platforms (Heyzine, Flipsnack, AnyFlip, Publuu, etc.)
    if (isInteractiveFlipbookUrl(url)) {
      return url;
    }

    // 2. Google Drive PDF preview conversion
    final gDriveId = extractGoogleDriveFileId(url);
    if (gDriveId != null && gDriveId.isNotEmpty) {
      return 'https://drive.google.com/file/d/$gDriveId/preview';
    }

    // 3. Direct PDF files (ends with .pdf or has .pdf?)
    if (RegExp(r'\.pdf(\?.*)?$', caseSensitive: false).hasMatch(url)) {
      return 'https://docs.google.com/gview?embedded=1&url=${Uri.encodeComponent(url)}';
    }

    // 4. DOI links (e.g., 10.1016/...)
    if (url.startsWith('10.') && url.contains('/')) {
      return 'https://doi.org/$url';
    }

    // 5. Fallback to standard URL
    return url;
  }

  /// Returns a direct download URL if available (e.g. for Google Drive or direct PDF).
  static String? getDirectDownloadUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final url = rawUrl.trim();

    final gDriveId = extractGoogleDriveFileId(url);
    if (gDriveId != null && gDriveId.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=$gDriveId';
    }

    if (RegExp(r'\.pdf(\?.*)?$', caseSensitive: false).hasMatch(url)) {
      return url;
    }

    return null;
  }

  /// Determines if the given URL points to a PDF or Google Drive document.
  static bool isPdfOrDriveDoc(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase();
    return clean.contains('drive.google.com') ||
        clean.contains('.pdf') ||
        clean.contains('docs.google.com');
  }

  /// Determines if the URL is an interactive web-based HTML5 Flipbook.
  static bool isInteractiveFlipbookUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase();
    return clean.contains('heyzine.com') ||
        clean.contains('flipsnack.com') ||
        clean.contains('anyflip.com') ||
        clean.contains('publuu.com') ||
        clean.contains('calameo.com') ||
        clean.contains('fliphtml5.com') ||
        clean.contains('issuu.com');
  }

  /// Normalizes DOI string into a full https://doi.org/ URL.
  static String formatDoiUrl(String? doi) {
    if (doi == null || doi.trim().isEmpty) return '';
    final cleanDoi = doi.trim();
    if (cleanDoi.startsWith('http://') || cleanDoi.startsWith('https://')) {
      return cleanDoi;
    }
    return 'https://doi.org/$cleanDoi';
  }
}
