import 'package:supabase_flutter/supabase_flutter.dart';

String resolveImageUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) return '';

  // If already an absolute http/https URL:
  if (value.startsWith('http://') || value.startsWith('https://')) {
    if (value.contains(' ')) {
      return value.replaceAll(' ', '%20');
    }
    return value;
  }

  // Handle protocol-relative URL
  if (value.startsWith('//')) {
    return 'https:$value';
  }

  final normalized = value.startsWith('/') ? value.substring(1) : value;
  const storagePrefix = 'storage/v1/object/public/';
  const objectPublicPrefix = 'object/public/';

  if (normalized.startsWith(storagePrefix)) {
    final storagePath = normalized.substring(storagePrefix.length);
    return _publicUrlFromStoragePath(storagePath);
  }

  if (normalized.startsWith(objectPublicPrefix)) {
    final storagePath = normalized.substring(objectPublicPrefix.length);
    return _publicUrlFromStoragePath(storagePath);
  }

  if (normalized.contains('/')) {
    return _publicUrlFromStoragePath(normalized);
  }

  final publicUrl = Supabase.instance.client.storage
      .from('product-images')
      .getPublicUrl(normalized);
  return Uri.encodeFull(publicUrl);
}

String _publicUrlFromStoragePath(String storagePath) {
  if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
    return Uri.encodeFull(storagePath);
  }

  final slashIndex = storagePath.indexOf('/');
  if (slashIndex <= 0 || slashIndex == storagePath.length - 1) {
    return storagePath;
  }

  final bucket = storagePath.substring(0, slashIndex);
  if (bucket == 'http:' || bucket == 'https:' || bucket.contains(':')) {
    return storagePath;
  }

  final path = storagePath.substring(slashIndex + 1);

  final publicUrl =
      Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
  return Uri.encodeFull(publicUrl);
}
