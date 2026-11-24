class_name WalkNetwork
extends RefCounted

## Pedestrian routing over the real OSM highway geometry that came with the map data.
## Ways that share a vertex are joined (OSM ways share node coordinates exactly).
## Distances are shortest walking paths (Dijkstra); when a place is not reachable on the
## mapped network, callers get -1 and must fall back to a clearly labelled estimate.

const WALKABLE_KINDS: Array[String] = [
	"footway", "path", "pedestrian", "residential", "living_street", "service", "tertiary",
	"secondary", "primary", "unclassified", "steps", "track", "cycleway", "tertiary_link",
	"secondary_link", "primary_link", "trunk", "trunk_link", "corridor", "sidewalk", "crossing", "road"
]
const MAX_SNAP_M: float = 140.0
const ESTIMATE_DETOUR: float = 1.35


static func build(roads: Array, ref_lat: float, ref_lon: float) -> Dictionary:
	var cos_lat: float = cos(deg_to_rad(ref_lat))
	var key_to_idx: Dictionary = {}
	var pos: PackedVector2Array = PackedVector2Array()
	var adj: Array = []
	var segs: Array = []
	for r_v in roads:
		var r: Dictionary = r_v
		if not WALKABLE_KINDS.has(str(r.get("kind", ""))):
			continue
		var pts: Array = r.get("points_latlon", [])
		var prev: int = -1
		for p_v in pts:
			var p: Vector2 = p_v
			var key: String = "%d_%d" % [int(round(p.x * 1e7)), int(round(p.y * 1e7))]
			var idx: int
			if key_to_idx.has(key):
				idx = int(key_to_idx[key])
			else:
				idx = pos.size()
				key_to_idx[key] = idx
				pos.append(Vector2((p.x - ref_lon) * 111320.0 * cos_lat, (p.y - ref_lat) * 110540.0))
				adj.append([])
			if prev >= 0 and prev != idx:
				var w: float = pos[prev].distance_to(pos[idx])
				(adj[prev] as Array).append([idx, w])
				(adj[idx] as Array).append([prev, w])
				segs.append(Vector2i(prev, idx))
			prev = idx
	return {"ref_lat": ref_lat, "ref_lon": ref_lon, "cos_lat": cos_lat, "pos": pos, "adj": adj, "segs": segs}


static func to_local(net: Dictionary, lat: float, lon: float) -> Vector2:
	return Vector2((lon - float(net["ref_lon"])) * 111320.0 * float(net["cos_lat"]), (lat - float(net["ref_lat"])) * 110540.0)


## Nearest point on the network: {ok, a, b, point, off_m}
static func snap(net: Dictionary, lat: float, lon: float) -> Dictionary:
	var q: Vector2 = to_local(net, lat, lon)
	var pos: PackedVector2Array = net["pos"]
	var best: Dictionary = {"ok": false}
	var best_d: float = 1e20
	for s_v in net["segs"]:
		var s: Vector2i = s_v
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(q, pos[s.x], pos[s.y])
		var d: float = c.distance_to(q)
		if d < best_d:
			best_d = d
			best = {"ok": d <= MAX_SNAP_M, "a": s.x, "b": s.y, "point": c, "off_m": d}
	return best


## Dijkstra distances (metres) from a lat/lon to every network node.
static func distances_from(net: Dictionary, lat: float, lon: float) -> Dictionary:
	var pos: PackedVector2Array = net["pos"]
	var n: int = pos.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(1e20)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var s: Dictionary = snap(net, lat, lon)
	if not bool(s.get("ok", false)):
		return {"ok": false, "dist": dist, "source_off_m": float(s.get("off_m", 1e9))}
	var sp: Vector2 = s["point"]
	var heap_f: Array[float] = []
	var heap_i: Array[int] = []
	for end_idx in [int(s["a"]), int(s["b"])]:
		var d0: float = sp.distance_to(pos[end_idx])
		if d0 < dist[end_idx]:
			dist[end_idx] = d0
			_push(heap_f, heap_i, d0, end_idx)
	var adj: Array = net["adj"]
	while not heap_i.is_empty():
		var cur_f: float = heap_f[0]
		var cur: int = heap_i[0]
		_pop(heap_f, heap_i)
		if cur_f > dist[cur] + 0.001:
			continue
		for e_v in adj[cur]:
			var e: Array = e_v
			var nb: int = int(e[0])
			var nd: float = cur_f + float(e[1])
			if nd < dist[nb]:
				dist[nb] = nd
				prev[nb] = cur
				_push(heap_f, heap_i, nd, nb)
	return {"ok": true, "dist": dist, "prev": prev, "source_off_m": float(s["off_m"]), "source_snap": s}


## Walking route (local metres, x east / y north) from the Dijkstra source to a target.
static func route_to(net: Dictionary, dists: Dictionary, lat: float, lon: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not bool(dists.get("ok", false)):
		return out
	var t: Dictionary = snap(net, lat, lon)
	if not bool(t.get("ok", false)):
		return out
	var pos: PackedVector2Array = net["pos"]
	var dist: PackedFloat32Array = dists["dist"]
	var prev: PackedInt32Array = dists["prev"]
	var tp: Vector2 = t["point"]
	var a: int = int(t["a"])
	var b: int = int(t["b"])
	var end_node: int = a if dist[a] + tp.distance_to(pos[a]) <= dist[b] + tp.distance_to(pos[b]) else b
	var chain: Array[int] = []
	var cur: int = end_node
	var guard: int = 0
	while cur != -1 and guard < 100000:
		chain.append(cur)
		cur = prev[cur]
		guard += 1
	chain.reverse()
	out.append(Vector2.ZERO)
	var src: Dictionary = dists.get("source_snap", {})
	if not src.is_empty():
		out.append(src["point"])
	for idx in chain:
		out.append(pos[idx])
	out.append(tp)
	out.append(to_local(net, lat, lon))
	return out


## Walking metres from the Dijkstra source to a target, or -1 if not on the mapped network.
static func walk_distance_to(net: Dictionary, dists: Dictionary, lat: float, lon: float) -> float:
	if not bool(dists.get("ok", false)):
		return -1.0
	var t: Dictionary = snap(net, lat, lon)
	if not bool(t.get("ok", false)):
		return -1.0
	var pos: PackedVector2Array = net["pos"]
	var dist: PackedFloat32Array = dists["dist"]
	var tp: Vector2 = t["point"]
	var a: int = int(t["a"])
	var b: int = int(t["b"])
	var best: float = minf(dist[a] + tp.distance_to(pos[a]), dist[b] + tp.distance_to(pos[b]))
	# Same segment as the source: walk directly along it.
	var src: Dictionary = dists.get("source_snap", {})
	if not src.is_empty() and ((int(src["a"]) == a and int(src["b"]) == b) or (int(src["a"]) == b and int(src["b"]) == a)):
		best = minf(best, (src["point"] as Vector2).distance_to(tp))
	if best >= 1e19:
		return -1.0
	return best + float(dists["source_off_m"]) + float(t["off_m"])


## Annotates POI dictionaries with walk_m / walk_source ("network" or "estimate").
static func annotate_targets(targets: Array, roads: Array, house: Dictionary) -> void:
	var h_lat: float = float(house.get("lat", 0.0))
	var h_lon: float = float(house.get("lon", 0.0))
	var net: Dictionary = build(roads, h_lat, h_lon)
	var dists: Dictionary = distances_from(net, h_lat, h_lon) if (net["pos"] as PackedVector2Array).size() > 1 else {"ok": false}
	for t_v in targets:
		var t: Dictionary = t_v
		var straight: float = float(t.get("distance_m", 0.0))
		var w: float = walk_distance_to(net, dists, float(t.get("lat", 0.0)), float(t.get("lon", 0.0)))
		if w > 0.0:
			t["walk_m"] = int(round(maxf(w, straight)))
			t["walk_source"] = "network"
		else:
			t["walk_m"] = int(round(straight * ESTIMATE_DETOUR))
			t["walk_source"] = "estimate"


static func _push(hf: Array[float], hi: Array[int], f: float, idx: int) -> void:
	hf.append(f)
	hi.append(idx)
	var k: int = hf.size() - 1
	while k > 0:
		var p: int = (k - 1) / 2
		if hf[p] <= hf[k]:
			break
		var tf: float = hf[p]
		hf[p] = hf[k]
		hf[k] = tf
		var ti: int = hi[p]
		hi[p] = hi[k]
		hi[k] = ti
		k = p


static func _pop(hf: Array[float], hi: Array[int]) -> void:
	var last: int = hf.size() - 1
	hf[0] = hf[last]
	hi[0] = hi[last]
	hf.remove_at(last)
	hi.remove_at(last)
	var k: int = 0
	var n: int = hf.size()
	while true:
		var l: int = k * 2 + 1
		var r: int = l + 1
		var m: int = k
		if l < n and hf[l] < hf[m]:
			m = l
		if r < n and hf[r] < hf[m]:
			m = r
		if m == k:
			break
		var tf: float = hf[m]
		hf[m] = hf[k]
		hf[k] = tf
		var ti: int = hi[m]
		hi[m] = hi[k]
		hi[k] = ti
		k = m
