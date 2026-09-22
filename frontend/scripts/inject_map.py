import re
import os
# Paths below are relative to the Flutter app root (frontend/).
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

with open('scripts/map.txt', 'r', encoding='utf-16le') as f:
    lines = f.read().splitlines()

map_lines = [line for line in lines if line.strip().startswith('"')]

new_grid = "  static const List<String> worldGrid = [\n" + "\n".join(map_lines) + "\n  ];"

with open('lib/src/admin2/screens/analytics_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace between "static const List<String> worldGrid = [" and "];"
pattern = re.compile(r'static const List<String> worldGrid = \[\n(?:.*?\n)*?  \];', re.MULTILINE)
new_content = pattern.sub(new_grid, content)

with open('lib/src/admin2/screens/analytics_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f"Replaced {len(map_lines)} lines.")
