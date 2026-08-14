import 'dart:convert';

void main() {
  final str = '{"Diamond Earrings","Sui Dhaga Earrings"}';
  print(str.startsWith('{'));
  if (str.startsWith('{') && str.endsWith('}')) {
    final inner = str.substring(1, str.length - 1);
    final parts = inner.split(',').map((e) => e.trim());
    for (var p in parts) {
      print(p);
    }
  }
}
