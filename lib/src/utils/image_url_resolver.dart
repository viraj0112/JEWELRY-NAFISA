import 'package:supabase_flutter/supabase_flutter.dart';

String resolveImageUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) return '';

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    return value;
  }

  final normalized = value.startsWith('/') ? value.substring(1) : value;
  final storagePrefix = 'storage/v1/object/public/';
  final objectPublicPrefix = 'object/public/';

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

  return Supabase.instance.client.storage
      .from('product-images')
      .getPublicUrl(normalized);
}

String _publicUrlFromStoragePath(String storagePath) {
  final slashIndex = storagePath.indexOf('/');
  if (slashIndex <= 0 || slashIndex == storagePath.length - 1) {
    return storagePath;
  }

  final bucket = storagePath.substring(0, slashIndex);
  final path = storagePath.substring(slashIndex + 1);

  return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
}
