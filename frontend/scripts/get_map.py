import urllib.request, json
url = 'https://raw.githubusercontent.com/johan/world.geo.json/master/countries.geo.json'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        
    width, height = 80, 28
    grid = [[' ' for _ in range(width)] for _ in range(height)]
    
    for feature in data['features']:
        geom = feature['geometry']
        if not geom: continue
        polys = geom['coordinates'] if geom['type'] == 'MultiPolygon' else [geom['coordinates']]
        for poly in polys:
            for ring in poly:
                for coord in ring:
                    if type(coord[0]) is list:
                        for lon, lat in coord:
                            x = int((lon + 180) / 360 * (width - 1))
                            y = int((90 - lat) / 180 * (height - 1))
                            if 0 <= x < width and 0 <= y < height:
                                grid[y][x] = 'x'
                    else:
                        lon, lat = coord
                        x = int((lon + 180) / 360 * (width - 1))
                        y = int((90 - lat) / 180 * (height - 1))
                        if 0 <= x < width and 0 <= y < height:
                            grid[y][x] = 'x'
    
    filled = [row[:] for row in grid]
    for y in range(1, height-1):
        for x in range(1, width-1):
            if grid[y][x] == 'x':
                filled[y][x] = 'x'
                filled[y][x-1] = 'x'
                filled[y][x+1] = 'x'

    print('RESULT:')
    for row in filled:
        print('    "' + ''.join(row) + '",')
except Exception as e:
    import traceback
    traceback.print_exc()
