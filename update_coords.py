import re

points = {
    'USA': (-95.7, 37.0),
    'CA': (-106.3, 56.1),
    'GB': (-3.4, 55.3),
    'FR': (2.2, 46.2),
    'IT': (12.5, 41.8),
    'AE': (53.8, 23.4),
    'IN': (78.9, 20.5),
    'CN': (104.1, 35.8),
    'JP': (138.2, 36.2),
    'AU': (133.7, -25.2),
    'BR': (-51.9, -14.2),
    'RU': (105.3, 61.5),
    'DE': (10.4, 51.1),
    'ES': (-3.7, 40.4),
    'CH': (8.2, 46.8),
    'SG': (103.8, 1.3),
    'HK': (114.1, 22.3),
}

width = 80
height = 28

lines = []
for code, (lon, lat) in points.items():
    col = (lon + 180) / 360 * width
    row = (90 - lat) / 180 * height
    lines.append(f"      '{code}': Offset(w * ({col:.1f} / {width}), h * ({row:.1f} / {height})),")

geo_map_code = "    final Map<String, Offset> geoMap = {\n" + "\n".join(lines) + "\n    };"

with open('lib/src/admin2/screens/analytics_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the geoMap block
pattern = re.compile(r'final Map<String, Offset> geoMap = \{.*?\};', re.MULTILINE | re.DOTALL)
new_content = pattern.sub(geo_map_code, content)

with open('lib/src/admin2/screens/analytics_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Updated geoMap coordinates.")
