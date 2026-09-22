/// Matches bulk-upload image files to CSV product titles.
///
/// Accepted file names for a product titled "Gold Ring":
///   Gold Ring.jpg
///   Gold Ring-Image1.jpg / -image1 / -img1 / _Image1 / Gold Ring Image1.jpg
///
/// Matching is case- and whitespace-insensitive because titles come from Excel
/// (stray casing, trailing spaces) while file names come from a filesystem.
String stripExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  // No dot, or a leading-dot file like ".gitkeep" - there is no extension to
  // strip. Guarding this also avoids a RangeError on substring(0, -1).
  if (dot <= 0) return fileName;
  return fileName.substring(0, dot);
}

String _normalize(String value) => value.trim().toLowerCase();

/// The separators allowed between a title and its image index.
const List<String> _imageSeparators = ['-', '_', ' '];
const List<String> _imageMarkers = ['image', 'img'];

bool imageFileMatchesTitle(String fileName, String title) {
  final base = _normalize(stripExtension(fileName));
  final normalizedTitle = _normalize(title);
  if (normalizedTitle.isEmpty) return false;

  if (base == normalizedTitle) return true;

  if (!base.startsWith(normalizedTitle)) return false;
  final suffix = base.substring(normalizedTitle.length);

  // Require a separator + image marker (e.g. "-image1"). Without this, the
  // title "Ring" would also claim "Ring Gold-Image1.jpg".
  for (final separator in _imageSeparators) {
    if (!suffix.startsWith(separator)) continue;
    final afterSeparator = suffix.substring(separator.length);
    for (final marker in _imageMarkers) {
      if (afterSeparator.startsWith(marker)) return true;
    }
  }

  return false;
}

/// Splits a name into text and numeric chunks so "Image2" sorts before
/// "Image10" (a plain string compare puts "Image10" first).
List<Object> _naturalKey(String value) {
  final chunks = <Object>[];
  final matches = RegExp(r'\d+|\D+').allMatches(_normalize(value));
  for (final match in matches) {
    final chunk = match.group(0)!;
    final number = int.tryParse(chunk);
    chunks.add(number ?? chunk);
  }
  return chunks;
}

int compareImageFileNames(String a, String b) {
  final keyA = _naturalKey(a);
  final keyB = _naturalKey(b);

  for (var i = 0; i < keyA.length && i < keyB.length; i++) {
    final chunkA = keyA[i];
    final chunkB = keyB[i];

    if (chunkA is int && chunkB is int) {
      final result = chunkA.compareTo(chunkB);
      if (result != 0) return result;
    } else {
      final result = chunkA.toString().compareTo(chunkB.toString());
      if (result != 0) return result;
    }
  }

  return keyA.length.compareTo(keyB.length);
}

/// MIME type for an image file name, so uploads are not all labelled as JPEG.
String contentTypeFor(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot <= 0 ? '' : _normalize(fileName.substring(dot + 1));
  switch (extension) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'avif':
      return 'image/avif';
    case 'heic':
      return 'image/heic';
    default:
      return 'image/jpeg';
  }
}

/// Returns every image whose name matches [title], in natural order.
List<T> matchingImagesForTitle<T>(
  Iterable<T> files,
  String title,
  String Function(T file) nameOf,
) {
  final matches =
      files.where((file) => imageFileMatchesTitle(nameOf(file), title)).toList();
  matches.sort((a, b) => compareImageFileNames(nameOf(a), nameOf(b)));
  return matches;
}
