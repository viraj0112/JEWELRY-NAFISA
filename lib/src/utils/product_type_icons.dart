/// Resolves a product-type label (as stored in the DB, with all its real
/// variance: plurals, misspellings like "Acessories", compound names like
/// "Kada Bracelet") to a small golden PNG icon in assets/jewelry_icons/.
///
/// Adding an icon for a NEW product type introduced in production:
///   1. Drop the source SVG into "Jewellery icon/" (white strokes on black).
///   2. Add its stem to WANTED in scripts/optimize_jewelry_icons.py and run
///      `python scripts/optimize_jewelry_icons.py` — this emits the small
///      gold/transparent PNG into assets/jewelry_icons/.
///   3. Add a normalized (lowercase, singular) entry to [_icons] below.
/// Until then, unknown types simply render without an icon — never an error.
/// Compound labels ("Kada Bracelet", "Tennis Bracelet") automatically fall
/// back to their last word's icon, so many new types need no change at all.
library;

const Map<String, String> _icons = {
  'ring': 'Ring.png',
  'bangle': 'Bangle.png',
  'bracelet': 'Bracelet.png',
  'earring': 'Earrings.png',
  'necklace': 'Necklace set.png',
  'necklace set': 'Necklace set.png',
  'pendant': 'Pendant.png',
  'pendant set': 'Pendant set.png',
  'full set': 'Full set.png',
  'accessory': 'Accessories.png',
  'accessorie': 'Accessories.png', // handles "Accessories" after 's' strip
  'acessorie': 'Accessories.png', // DB misspelling "Acessories"
  'chain': 'Chain.png',
  'anklet': 'Anklet.png',
  'armlet': 'Armlet.png',
  'nose ring': 'Nose Ring.png',
  'toe ring': 'Toe Ring.png',
  'waist band': 'Waist Band.png',
  'watch': 'Watch.png',
};

String _normalize(String label) {
  var key = label.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  if (key.endsWith('s') && key.length > 1) {
    key = key.substring(0, key.length - 1);
  }
  return key;
}

/// Returns the asset path for [label]'s icon, or null when no icon matches
/// (callers should render the label without an icon in that case).
String? productTypeIconAsset(String label) {
  final key = _normalize(label);
  var file = _icons[key];
  if (file == null && key.contains(' ')) {
    // Compound type ("kada bracelet") — fall back to its last word.
    file = _icons[key.substring(key.lastIndexOf(' ') + 1)];
  }
  return file == null ? null : 'assets/jewelry_icons/$file';
}
