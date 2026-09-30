MarchingBlocks tileset, format 1. The tiles are placed by the rule below; nothing else.
Frame: right-handed, +Y up (glTF). 1 unit = 1 cell. Cell c covers [c, c+1] on each axis.
A layer is a set of full cells. Layers are independent: a layer only ever reads its own cells.
1. Vertices. A full cell c touches the 8 vertices c - corners[t], t = 0..7.
2. Bits. At vertex v, bit t is 1 when cell v + corners[t] is full (t = x + 2y + 4z).
3. Class. table[bits] = [class, quarter_turns]. class = -1: nothing is placed at v.
4. Context. Only if classes[class].outdoor_possible. Let top = the highest y of any full cell of
   the layer. v is OUTDOOR when, for EVERY EMPTY cell e among its 8, no cell (e.x, y, e.z) is full
   for y from v.y + 2 to top inclusive. Outdoor: use key '<class id>_outdoor' if the tileset has it,
   otherwise fall back on the bare key '<class id>'. Indoor: the bare key.
5. Copy. n = number of copies of the key (tiles[key].length). With 64-bit signed integers,
   h = (v.x * 73856093) XOR (v.y * 19349663) XOR (v.z * 83492791); k = (h AND 0x7FFFFFFF) mod n.
   Place tiles[key][k].
6. Missing. If the key is absent (or n = 0), place a clearly visible error marker. Never fill in.
7. Pose. The tile mesh is centred on the origin. Place it at (v + piece_offset) * cell_size,
   rotated by quarter_turns * 90 degrees about +Y, right-hand rule (+Z turns towards +X).
Rebuilding after cell (x, y, z) changes: only the vertices of columns x-1..x, z-1..z at heights
   up to y can change (their bits, or their context).
Engines with another frame must convert the cell grid with the SAME mapping their glTF importer
   applies to meshes. A mirroring conversion reverses the direction of the quarter turns.
Frame: tiles.glb carries a marker node, frame_marker.node, whose mesh has exactly the vertices
   frame_marker.points = (0,0,0), (1,0,0), (0,2,0), (0,0,3). Read where your importer put them
   (node pose included): the lengths 1, 2, 3 tell each axis apart, the shortest gives the scale.
   That linear map F is the conversion. Place a piece at F(v + piece_offset) * cell_size,
   rotated by F * R * F^-1 where R is the quarter-turn rotation. The marker is not a tile.

Open format — free plugins for Godot, Unity and Unreal read it. Made with MarchingBlocks 0.1.0.
