extends Node

## Procedural 1950s Civil Defense CONELRAD Audio Synthesizer & Sound Manager (V2).
## Generates crisp 16-bit 22050 Hz PCM AudioStreamWAV SFX (19 cues) and rich 4.0s
## layered procedural music & atmospheric soundscapes ("menu", "scavenge", "bunker")
## with click-free 1024-sample loop crossfades and zero ObjectDB leaks on exit.

const MIX_RATE: int = 22050
const SFX_POOL_SIZE: int = 6
const AMBIENT_VOLUME_DB: float = -16.5

var _sfx_streams: Dictionary = {}
var _ambient_streams: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_cursor: int = 0
var _ambient_player: AudioStreamPlayer = null
var _current_ambience: String = "none"
var _noise_state: int = 2463534242
var _is_shutting_down: bool = false
var _headless_no_movie: bool = DisplayServer.get_name() == "headless" and not (OS.get_cmdline_args() + OS.get_cmdline_user_args()).has("--write-movie")

func _ready() -> void:
	var all_args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	_headless_no_movie = DisplayServer.get_name() == "headless" and not all_args.has("--write-movie")
	_is_shutting_down = false
	_setup_players()
	_generate_all_sfx()
	_generate_all_ambience()

func _exit_tree() -> void:
	shutdown_audio()
	_sfx_pool.clear()
	_ambient_player = null
	_sfx_streams.clear()
	_ambient_streams.clear()

func shutdown_audio() -> void:
	_is_shutting_down = true
	_current_ambience = "none"
	if is_instance_valid(_ambient_player):
		_ambient_player.stop()
		_ambient_player.stream = null
	for p in _sfx_pool:
		if is_instance_valid(p):
			p.stop()
			p.stream = null

func _setup_players() -> void:
	_sfx_pool.clear()
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer_%d" % i
		player.bus = "Master"
		add_child(player)
		_sfx_pool.append(player)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = "Master"
	_ambient_player.volume_db = AMBIENT_VOLUME_DB
	add_child(_ambient_player)

func play_sfx(sfx_name: String, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if _is_shutting_down:
		return
	if not _sfx_streams.has(sfx_name) or _sfx_pool.is_empty():
		return
	if _headless_no_movie:
		return
	var stream: AudioStreamWAV = _sfx_streams[sfx_name]
	var chosen: AudioStreamPlayer = null
	for p in _sfx_pool:
		if not p.playing:
			chosen = p
			break
	if chosen == null:
		chosen = _sfx_pool[_pool_cursor % _sfx_pool.size()]
		_pool_cursor = (_pool_cursor + 1) % _sfx_pool.size()
	chosen.stream = stream
	chosen.volume_db = volume_offset_db
	chosen.pitch_scale = maxf(0.1, pitch_scale)
	chosen.play()

func set_ambience(mode: String) -> void:
	if _is_shutting_down or _ambient_player == null:
		if mode == "none":
			_current_ambience = "none"
		return
	if mode == "none" or not _ambient_streams.has(mode):
		_current_ambience = "none"
		_ambient_player.stop()
		_ambient_player.stream = null
		return
	if _current_ambience == mode and (_ambient_player.playing or _headless_no_movie):
		return
	var stream: AudioStreamWAV = _ambient_streams[mode]
	_current_ambience = mode
	if _headless_no_movie:
		return
	_ambient_player.stream = stream
	_ambient_player.volume_db = AMBIENT_VOLUME_DB
	_ambient_player.pitch_scale = 1.0
	_ambient_player.play()

func has_sfx(sfx_name: String) -> bool:
	return _sfx_streams.has(sfx_name)

func get_current_ambience() -> String:
	return _current_ambience

func _next_noise() -> float:
	_noise_state = int((_noise_state * 1664525 + 1013904223) & 0x7fffffff)
	return (float(_noise_state) / 1073741823.5) - 1.0

func _lock_freq(target_hz: float, loop_dur: float) -> float:
	var cycles: float = maxf(1.0, round(target_hz * loop_dur))
	return cycles / loop_dur

func _build_wav(samples: PackedFloat32Array, looped: bool = false) -> AudioStreamWAV:
	var count: int = samples.size()
	if looped and count > 2048:
		# Smooth 1024-sample crossfade across loop seam for click-free continuous playback
		var fade_len: int = 1024
		for i in range(fade_len):
			var alpha: float = float(i) / float(fade_len)
			var tail_idx: int = count - fade_len + i
			var blended: float = samples[tail_idx] * (1.0 - alpha) + samples[i] * alpha
			samples[tail_idx] = blended

	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for i in range(count):
		var s: float = clampf(samples[i], -1.0, 1.0)
		var iv: int = clampi(int(round(s * 32767.0)), -32767, 32767)
		pcm.encode_s16(i * 2, iv)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = pcm
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 1024 if count > 2048 else 0
		wav.loop_end = count
	else:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return wav

func _generate_all_sfx() -> void:
	# Core 13 Civil Defense SFX
	_sfx_streams["siren"] = _synth_siren()
	_sfx_streams["tick"] = _synth_tick()
	_sfx_streams["urgent_tick"] = _synth_urgent_tick()
	_sfx_streams["pickup"] = _synth_pickup()
	_sfx_streams["hatch_drop"] = _synth_hatch_drop()
	_sfx_streams["hatch_slam"] = _synth_hatch_slam()
	_sfx_streams["nuke_boom"] = _synth_nuke_boom()
	_sfx_streams["page_turn"] = _synth_page_turn()
	_sfx_streams["button_click"] = _synth_button_click()
	_sfx_streams["geiger"] = _synth_geiger()
	_sfx_streams["knock"] = _synth_knock()
	_sfx_streams["victory"] = _synth_victory()
	_sfx_streams["gameover"] = _synth_gameover()

	# V2 Expanded SFX (Vehicle, Relationships, Achievements, Medical, Crafting)
	_sfx_streams["engine_start"] = _synth_engine_start()
	_sfx_streams["bond_chime"] = _synth_bond_chime()
	_sfx_streams["argument"] = _synth_argument()
	_sfx_streams["achievement"] = _synth_achievement()
	_sfx_streams["heal_pill"] = _synth_heal_pill()
	_sfx_streams["craft_wrench"] = _synth_craft_wrench()

func _generate_all_ambience() -> void:
	_ambient_streams["menu"] = _synth_ambience_menu()
	_ambient_streams["scavenge"] = _synth_ambience_scavenge()
	_ambient_streams["bunker"] = _synth_ambience_bunker()

# 1. "siren": Rising-and-falling 1950s dual-tone Civil Defense air-raid siren (2.2s)
func _synth_siren() -> AudioStreamWAV:
	var dur: float = 2.2
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var p1: float = 0.0
	var p2: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var u: float = t / dur
		var curve: float = 0.0
		if u < 0.52:
			curve = smoothstep(0.0, 0.52, u)
		else:
			curve = 1.0 - 0.58 * smoothstep(0.52, 1.0, u)
		var f1: float = lerpf(285.0, 690.0, curve)
		var f2: float = f1 * 1.20
		p1 += TAU * f1 * inv_sr
		p2 += TAU * f2 * inv_sr
		var horn_a: float = sin(p1) + 0.42 * sin(2.0 * p1) + 0.20 * sin(3.0 * p1)
		var horn_b: float = sin(p2) + 0.38 * sin(2.0 * p2) + 0.16 * sin(3.0 * p2)
		var env: float = minf(1.0, t / 0.09) * minf(1.0, (dur - t) / 0.22)
		var trem: float = 0.92 + 0.08 * sin(TAU * 7.5 * t)
		buf[i] = tanh((horn_a * 0.52 + horn_b * 0.48) * 0.65) * env * trem * 0.78
	return _build_wav(buf, false)

# 2. "tick": Crisp mechanical stopwatch tick (0.06s)
func _synth_tick() -> AudioStreamWAV:
	var dur: float = 0.06
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var env_fast: float = exp(-t * 155.0)
		var env_body: float = exp(-t * 78.0)
		var escapement: float = sin(TAU * 1920.0 * t) * 0.55 + sin(TAU * 3580.0 * t) * 0.35
		var click_noise: float = _next_noise() * exp(-t * 280.0) * 0.45
		var fade_out: float = minf(1.0, (dur - t) / 0.008)
		buf[i] = (escapement * env_body + click_noise * env_fast) * fade_out * 0.82
	return _build_wav(buf, false)

# 3. "urgent_tick": High-pitched double stopwatch tick + alarm beep (0.12s)
func _synth_urgent_tick() -> AudioStreamWAV:
	var dur: float = 0.12
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var s: float = 0.0
		s += (sin(TAU * 2350.0 * t) * 0.5 + _next_noise() * 0.35) * exp(-t * 130.0)
		if t >= 0.048:
			var dt: float = t - 0.048
			s += (sin(TAU * 2650.0 * dt) * 0.55 + _next_noise() * 0.35) * exp(-dt * 130.0)
		var beep_env: float = sin(PI * clampf(t / 0.105, 0.0, 1.0))
		var beep: float = (sin(TAU * 1040.0 * t) * 0.65 + sin(TAU * 2080.0 * t) * 0.25) * beep_env * 0.48
		var fade_out: float = minf(1.0, (dur - t) / 0.01)
		buf[i] = clampf((s + beep) * fade_out * 0.85, -0.95, 0.95)
	return _build_wav(buf, false)

# 4. "pickup": Snappy upward retro chime/pop (0.14s)
func _synth_pickup() -> AudioStreamWAV:
	var dur: float = 0.14
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var freq: float = 523.25
		if t < 0.045:
			freq = lerpf(310.0, 660.0, t / 0.045)
		else:
			freq = 880.0
		phase += TAU * freq * inv_sr
		var env: float = minf(1.0, t / 0.004) * exp(-t * 19.5) * minf(1.0, (dur - t) / 0.015)
		var chime: float = sin(phase) * 0.72 + sin(phase * 1.5) * 0.22 + sin(phase * 2.0) * 0.14
		buf[i] = chime * env * 0.78
	return _build_wav(buf, false)

# 5. "hatch_drop": Metallic chute whoosh + satisfying triad chord (0.28s)
func _synth_hatch_drop() -> AudioStreamWAV:
	var dur: float = 0.28
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var whoosh_phase: float = 0.0
	var lp_state: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var slide_f: float = lerpf(580.0, 175.0, clampf(t / 0.13, 0.0, 1.0))
		whoosh_phase += TAU * slide_f * inv_sr
		var raw_n: float = _next_noise()
		lp_state += 0.24 * (raw_n - lp_state)
		var whoosh_env: float = sin(PI * clampf(t / 0.14, 0.0, 1.0))
		var whoosh: float = (sin(whoosh_phase) * 0.45 + lp_state * 0.65) * whoosh_env * 0.55

		var chord: float = 0.0
		if t >= 0.055:
			var ct: float = t - 0.055
			var c_env: float = minf(1.0, ct / 0.01) * exp(-ct * 9.5)
			chord = (
				sin(TAU * 523.25 * ct) * 0.42
				+ sin(TAU * 659.25 * ct) * 0.34
				+ sin(TAU * 783.99 * ct) * 0.30
				+ sin(TAU * 1046.5 * ct) * 0.14
			) * c_env
		var fade_out: float = minf(1.0, (dur - t) / 0.02)
		buf[i] = clampf((whoosh + chord) * fade_out * 0.80, -0.95, 0.95)
	return _build_wav(buf, false)

# 6. "hatch_slam": Heavy steel blast door clang + latch lock (0.55s)
func _synth_hatch_slam() -> AudioStreamWAV:
	var dur: float = 0.55
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var sub_phase: float = 0.0
	var lp_noise: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var sub_f: float = lerpf(82.0, 38.0, clampf(t / 0.18, 0.0, 1.0))
		sub_phase += TAU * sub_f * inv_sr
		var thud: float = sin(sub_phase) * exp(-t * 11.0) * 0.72
		var clang: float = (
			sin(TAU * 148.0 * t) * 0.34
			+ sin(TAU * 289.0 * t) * 0.26
			+ sin(TAU * 462.0 * t) * 0.20
			+ sin(TAU * 738.0 * t) * 0.14
		) * exp(-t * 14.5)
		lp_noise += 0.32 * (_next_noise() - lp_noise)
		var impact_burst: float = lp_noise * exp(-t * 36.0) * 0.65

		var latch: float = 0.0
		if t >= 0.27:
			var lt: float = t - 0.27
			latch = (
				sin(TAU * 610.0 * lt) * 0.42
				+ sin(TAU * 1190.0 * lt) * 0.35
				+ _next_noise() * 0.30 * exp(-lt * 95.0)
			) * exp(-lt * 32.0) * 0.68

		var fade_out: float = minf(1.0, (dur - t) / 0.035)
		buf[i] = tanh((thud + clang + impact_burst + latch) * 1.15) * fade_out * 0.85
	return _build_wav(buf, false)

# 7. "nuke_boom": Deep low-pass seismic detonation boom + rumble (1.8s)
func _synth_nuke_boom() -> AudioStreamWAV:
	var dur: float = 1.8
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var sub_phase: float = 0.0
	var lp1: float = 0.0
	var lp2: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var u: float = t / dur
		var sub_f: float = lerpf(96.0, 28.0, pow(clampf(t / 0.45, 0.0, 1.0), 0.65))
		sub_phase += TAU * sub_f * inv_sr
		var sub_wave: float = (sin(sub_phase) + 0.35 * sin(2.0 * sub_phase)) * exp(-t * 2.1)

		var cutoff: float = lerpf(780.0, 95.0, clampf(t / 1.1, 0.0, 1.0))
		var alpha: float = clampf((TAU * cutoff * inv_sr) / (1.0 + TAU * cutoff * inv_sr), 0.01, 0.85)
		var raw: float = _next_noise()
		lp1 += alpha * (raw - lp1)
		lp2 += alpha * (lp1 - lp2)

		var shock_crack: float = raw * exp(-t * 48.0) * 0.55
		var tremor_mod: float = 0.84 + 0.16 * sin(TAU * 11.5 * t)
		var env: float = minf(1.0, t / 0.008) * (1.0 - pow(u, 1.85))
		buf[i] = tanh((sub_wave * 0.72 + lp2 * 1.35 * tremor_mod + shock_crack) * 1.25) * env * 0.88
	return _build_wav(buf, false)

# 8. "page_turn": Filtered noise paper flip (0.15s)
func _synth_page_turn() -> AudioStreamWAV:
	var dur: float = 0.15
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	var prev_raw: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var u: float = t / dur
		var raw: float = _next_noise()
		var hp: float = raw - prev_raw * 0.82
		prev_raw = raw
		var alpha: float = lerpf(0.18, 0.58, sin(PI * u))
		lp += alpha * (hp - lp)
		var env: float = sin(PI * pow(u, 0.72))
		var flick: float = hp * exp(-t * 160.0) * 0.25
		buf[i] = clampf((lp * env * 0.85 + flick) * 0.68, -0.9, 0.9)
	return _build_wav(buf, false)

# 9. "button_click": Tactile bakelite switch click (0.05s)
func _synth_button_click() -> AudioStreamWAV:
	var dur: float = 0.05
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var snap1: float = (
			sin(TAU * 980.0 * t) * 0.55
			+ sin(TAU * 2420.0 * t) * 0.35
			+ _next_noise() * 0.40 * exp(-t * 320.0)
		) * exp(-t * 170.0)
		var snap2: float = 0.0
		if t >= 0.015:
			var dt: float = t - 0.015
			snap2 = (sin(TAU * 420.0 * dt) * 0.60 + sin(TAU * 1240.0 * dt) * 0.30) * exp(-dt * 150.0) * 0.75
		var fade_out: float = minf(1.0, (dur - t) / 0.006)
		buf[i] = clampf((snap1 + snap2) * fade_out * 0.80, -0.95, 0.95)
	return _build_wav(buf, false)

# 10. "geiger": Short crisp Geiger-Muller clicks (0.18s)
func _synth_geiger() -> AudioStreamWAV:
	var dur: float = 0.18
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var pulse_times: Array[float] = [0.006, 0.034, 0.052, 0.097, 0.138, 0.156]
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var s: float = 0.0
		for pt in pulse_times:
			if t >= pt and t < pt + 0.016:
				var dt: float = t - pt
				var ring: float = sin(TAU * 3650.0 * dt) * 0.55 + _next_noise() * 0.65
				s += ring * exp(-dt * 340.0)
		buf[i] = clampf(s * 0.78, -0.92, 0.92)
	return _build_wav(buf, false)

# 11. "knock": Three hollow knocks on steel hatch (0.5s)
func _synth_knock() -> AudioStreamWAV:
	var dur: float = 0.5
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var hits: Array[float] = [0.012, 0.168, 0.325]
	var gains: Array[float] = [0.85, 0.92, 1.0]
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var s: float = 0.0
		for h_idx in range(hits.size()):
			var ht: float = hits[h_idx]
			if t >= ht:
				var dt: float = t - ht
				var cavity: float = (sin(TAU * 158.0 * dt) * 0.62 + sin(TAU * 246.0 * dt) * 0.38) * exp(-dt * 34.0)
				var steel: float = (sin(TAU * 510.0 * dt) * 0.25 + sin(TAU * 920.0 * dt) * 0.14) * exp(-dt * 52.0)
				var knuckle: float = _next_noise() * exp(-dt * 210.0) * 0.35
				s += (cavity + steel + knuckle) * gains[h_idx]
		var fade_out: float = minf(1.0, (dur - t) / 0.025)
		buf[i] = tanh(s * 1.1) * fade_out * 0.82
	return _build_wav(buf, false)

# 12. "victory": Warm brassy 4-note major Civil Defense fanfare (1.4s)
func _synth_victory() -> AudioStreamWAV:
	var dur: float = 1.4
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var s: float = 0.0
		if t < 0.20:
			s = _brass_voice(261.63, t, 0.20)
		elif t < 0.40:
			s = _brass_voice(329.63, t - 0.20, 0.20)
		elif t < 0.60:
			s = _brass_voice(392.00, t - 0.40, 0.20)
		else:
			var ct: float = t - 0.60
			var c_dur: float = 0.80
			var vibrato: float = 1.0 + 0.004 * sin(TAU * 5.2 * ct)
			s = (
				_brass_voice(523.25 * vibrato, ct, c_dur) * 0.48
				+ _brass_voice(392.00 * vibrato, ct, c_dur) * 0.30
				+ _brass_voice(329.63 * vibrato, ct, c_dur) * 0.26
				+ _brass_voice(261.63, ct, c_dur) * 0.22
			)
		buf[i] = tanh(s * 0.95) * 0.78
	return _build_wav(buf, false)

func _brass_voice(freq: float, local_t: float, note_dur: float) -> float:
	var attack: float = minf(1.0, local_t / 0.022)
	var release: float = minf(1.0, maxf(0.0, (note_dur - local_t) / 0.055))
	var sustain_decay: float = exp(-local_t * 1.35)
	var bright: float = 0.65 + 0.35 * minf(1.0, local_t / 0.05)
	var w: float = TAU * freq * local_t
	var wave: float = (
		sin(w) * 0.55
		+ sin(2.0 * w) * 0.32 * bright
		+ sin(3.0 * w) * 0.20 * bright
		+ sin(4.0 * w) * 0.11 * bright
		+ sin(5.0 * w) * 0.06 * bright
	)
	return wave * attack * release * sustain_decay

# 13. "gameover": Somber descending minor tube chord (1.5s)
func _synth_gameover() -> AudioStreamWAV:
	var dur: float = 1.5
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var vib: float = 1.0 + 0.005 * sin(TAU * 4.2 * t)
		var lead_f: float = 349.23
		var lead_env: float = 1.0
		if t < 0.34:
			lead_f = 349.23
			lead_env = minf(1.0, t / 0.03) * minf(1.0, (0.34 - t) / 0.04)
		elif t < 0.68:
			var lt: float = t - 0.34
			lead_f = 329.63
			lead_env = minf(1.0, lt / 0.03) * minf(1.0, (0.34 - lt) / 0.04)
		else:
			var lt2: float = t - 0.68
			lead_f = 293.66
			lead_env = minf(1.0, lt2 / 0.03) * exp(-lt2 * 1.8)

		var lead: float = (sin(TAU * lead_f * vib * t) * 0.6 + sin(TAU * 2.0 * lead_f * vib * t) * 0.22) * lead_env * 0.42
		var pad_env: float = minf(1.0, t / 0.08) * exp(-t * 1.15) * minf(1.0, (dur - t) / 0.18)
		var pad: float = (
			sin(TAU * 146.83 * t) * 0.42
			+ sin(TAU * 174.61 * vib * t) * 0.36
			+ sin(TAU * 220.00 * vib * t) * 0.32
			+ sin(TAU * 73.42 * t) * 0.28
		) * pad_env * 0.58
		buf[i] = tanh((lead + pad) * 1.05) * 0.78
	return _build_wav(buf, false)

# 14. "engine_start": 1950s Station Wagon starter crank + throaty V8 ignition roar (1.35s)
func _synth_engine_start() -> AudioStreamWAV:
	var dur: float = 1.35
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var crank_phase: float = 0.0
	var v8_phase: float = 0.0
	var lp_exhaust: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var s: float = 0.0
		if t < 0.48:
			# Three compression starter cranks before ignition catches
			var cyc: float = fmod(t, 0.16) / 0.16
			var load_dip: float = 1.0 - 0.26 * sin(PI * cyc)
			var gear_f: float = 375.0 * load_dip
			crank_phase += TAU * gear_f * inv_sr
			var whine: float = sin(crank_phase) * 0.42 + sin(crank_phase * 2.0) * 0.24 + sin(crank_phase * 0.5) * 0.35
			var chug_env: float = pow(sin(PI * cyc), 0.65)
			var solenoid: float = _next_noise() * exp(-t * 160.0) * 0.55
			var raw_c: float = _next_noise()
			lp_exhaust += 0.18 * (raw_c - lp_exhaust)
			s = (whine * 0.62 + lp_exhaust * 0.55) * chug_env + solenoid
		else:
			# V8 ignition bark -> rev flare -> muscular Detroit idle rumble
			var rt: float = t - 0.48
			var rev_curve: float = 0.0
			if rt < 0.24:
				rev_curve = smoothstep(0.0, 0.24, rt)
			else:
				rev_curve = 1.0 - 0.48 * smoothstep(0.24, 0.82, rt)
			var rpm_f: float = lerpf(48.0, 98.0, rev_curve)
			v8_phase += TAU * rpm_f * inv_sr
			# Cross-plane V8 uneven burble harmonics
			var cyl_wave: float = (
				sin(v8_phase) * 0.58
				+ sin(v8_phase * 1.5) * 0.32
				+ sin(v8_phase * 2.0) * 0.44
				+ sin(v8_phase * 3.0) * 0.22
				+ sin(v8_phase * 4.0) * 0.15
			)
			var raw_v: float = _next_noise()
			lp_exhaust += 0.26 * (raw_v - lp_exhaust)
			var catch_bark: float = lp_exhaust * exp(-rt * 11.0) * 0.95
			var rumble_noise: float = lp_exhaust * (0.35 + 0.25 * sin(v8_phase * 2.0))
			var env_r: float = minf(1.0, rt / 0.015) * minf(1.0, (dur - t) / 0.10)
			s = (cyl_wave * 0.78 + catch_bark + rumble_noise) * env_r
		buf[i] = tanh(s * 1.30) * 0.84
	return _build_wav(buf, false)

# 15. "bond_chime": Warm arpeggiated major-add9 vibraphone & celesta chord (0.68s)
func _synth_bond_chime() -> AudioStreamWAV:
	var dur: float = 0.68
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes: Array[float] = [261.63, 329.63, 392.00, 587.33, 659.25]
	var offsets: Array[float] = [0.0, 0.038, 0.076, 0.115, 0.155]
	var gains: Array[float] = [0.34, 0.30, 0.28, 0.24, 0.22]
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var s: float = 0.0
		var trem: float = 0.90 + 0.10 * sin(TAU * 5.8 * t)
		for idx in range(notes.size()):
			var st: float = offsets[idx]
			if t >= st:
				var dt: float = t - st
				var f: float = notes[idx]
				var env: float = minf(1.0, dt / 0.008) * exp(-dt * 4.4)
				var tone: float = sin(TAU * f * dt) * 0.74 + sin(TAU * f * 2.0 * dt) * 0.18 + sin(TAU * f * 4.0 * dt) * 0.10 * exp(-dt * 18.0)
				s += tone * env * gains[idx]
		var fade_out: float = minf(1.0, (dur - t) / 0.05)
		buf[i] = tanh(s * trem * 1.15) * fade_out * 0.80
	return _build_wav(buf, false)

# 16. "argument": Sharp locker slam + dissonant tritone/minor-2nd tension sting (0.52s)
func _synth_argument() -> AudioStreamWAV:
	var dur: float = 0.52
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var thud_p: float = 0.0
	var lp: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var tf: float = lerpf(118.0, 44.0, clampf(t / 0.14, 0.0, 1.0))
		thud_p += TAU * tf * inv_sr
		var slam: float = sin(thud_p) * exp(-t * 14.0) * 0.72
		lp += 0.36 * (_next_noise() - lp)
		var rattle: float = lp * exp(-t * 38.0) * 0.65

		# Harsh dissonant shelter tension chord (C3 + F#3 + B3 + C4)
		var sting_env: float = minf(1.0, t / 0.012) * exp(-t * 5.8)
		var wob: float = 1.0 + 0.008 * sin(TAU * 13.0 * t)
		var sting: float = (
			sin(TAU * 130.81 * t) * 0.36
			+ sin(TAU * 185.00 * wob * t) * 0.34
			+ sin(TAU * 246.94 * wob * t) * 0.30
			+ sin(TAU * 261.63 * t) * 0.28
			+ sin(TAU * 370.00 * t) * 0.16
		) * sting_env * 0.68
		var fade_out: float = minf(1.0, (dur - t) / 0.035)
		buf[i] = tanh((slam + rattle + sting) * 1.28) * fade_out * 0.82
	return _build_wav(buf, false)

# 17. "achievement": Bright 3-note Civil Defense brass medal fanfare (0.95s)
func _synth_achievement() -> AudioStreamWAV:
	var dur: float = 0.95
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var s: float = 0.0
		if t < 0.15:
			s = _brass_voice(392.00, t, 0.16) * 0.92
		elif t < 0.30:
			s = _brass_voice(493.88, t - 0.15, 0.16) * 0.95
		else:
			var ct: float = t - 0.30
			var c_dur: float = 0.65
			var vib: float = 1.0 + 0.004 * sin(TAU * 5.6 * ct)
			var chime: float = sin(TAU * 1567.98 * ct) * exp(-ct * 9.0) * 0.18
			s = (
				_brass_voice(587.33 * vib, ct, c_dur) * 0.48
				+ _brass_voice(493.88 * vib, ct, c_dur) * 0.30
				+ _brass_voice(392.00, ct, c_dur) * 0.28
				+ _brass_voice(196.00, ct, c_dur) * 0.22
				+ chime
			)
		var fade_out: float = minf(1.0, (dur - t) / 0.04)
		buf[i] = tanh(s * 1.05) * fade_out * 0.82
	return _build_wav(buf, false)

# 18. "heal_pill": Pill bottle pop + gentle upward crystalline 4-note sparkle (0.48s)
func _synth_heal_pill() -> AudioStreamWAV:
	var dur: float = 0.48
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var bells: Array[float] = [659.25, 830.61, 987.77, 1318.51]
	var starts: Array[float] = [0.035, 0.095, 0.155, 0.215]
	var pop_p: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var s: float = 0.0
		if t < 0.045:
			var pf: float = lerpf(420.0, 920.0, t / 0.045)
			pop_p += TAU * pf * inv_sr
			s += (sin(pop_p) * 0.45 + _next_noise() * 0.25 * exp(-t * 180.0)) * exp(-t * 65.0)
		for b_idx in range(bells.size()):
			var st: float = starts[b_idx]
			if t >= st:
				var dt: float = t - st
				var bf: float = bells[b_idx]
				var b_env: float = minf(1.0, dt / 0.005) * exp(-dt * 10.5)
				s += (sin(TAU * bf * dt) * 0.65 + sin(TAU * bf * 2.0 * dt) * 0.22 + sin(TAU * bf * 3.0 * dt) * 0.08) * b_env * 0.46
		var fade_out: float = minf(1.0, (dur - t) / 0.03)
		buf[i] = clampf(s * fade_out * 0.82, -0.95, 0.95)
	return _build_wav(buf, false)

# 19. "craft_wrench": Forged socket-wrench ratchet sweep & steel bolt clink x2 (0.46s)
func _synth_craft_wrench() -> AudioStreamWAV:
	var dur: float = 0.46
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ratchet_clicks: Array[float] = [
		0.015, 0.042, 0.068, 0.094, 0.122,
		0.235, 0.262, 0.288, 0.314, 0.342
	]
	var clink_hits: Array[float] = [0.135, 0.355]
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var s: float = 0.0
		for rt in ratchet_clicks:
			if t >= rt and t < rt + 0.022:
				var dt: float = t - rt
				var pawl: float = (sin(TAU * 2780.0 * dt) * 0.52 + sin(TAU * 4120.0 * dt) * 0.34 + _next_noise() * 0.42) * exp(-dt * 260.0)
				s += pawl * 0.62
		for c_idx in range(clink_hits.size()):
			var ct_start: float = clink_hits[c_idx]
			if t >= ct_start:
				var dt2: float = t - ct_start
				var pitch_mul: float = 1.0 if c_idx == 0 else 1.08
				var ring: float = (
					sin(TAU * 845.0 * pitch_mul * dt2) * 0.48
					+ sin(TAU * 1540.0 * pitch_mul * dt2) * 0.36
					+ sin(TAU * 2460.0 * pitch_mul * dt2) * 0.24
					+ _next_noise() * 0.32 * exp(-dt2 * 180.0)
				) * exp(-dt2 * 34.0)
				s += ring * 0.78
		var fade_out: float = minf(1.0, (dur - t) / 0.025)
		buf[i] = tanh(s * 1.18) * fade_out * 0.84
	return _build_wav(buf, false)

# ==============================================================================
# V2 LAYERED PROCEDURAL MUSIC & ATMOSPHERIC SOUNDSCAPES (4.0s Click-Free Loops)
# ==============================================================================

# Looping Music 1: "menu" — 1950s CONELRAD warm vibraphone / electric-organ minor-6th
# arpeggio motif over gentle radio carrier warmth (4.0s seamless 22050Hz loop)
func _synth_ambience_menu() -> AudioStreamWAV:
	var dur: float = 4.0
	var n: int = int(dur * MIX_RATE)
	var fade_len: int = 1024
	var loop_samples: int = n - fade_len
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var loop_dur: float = float(loop_samples) * inv_sr

	# A-minor-6th nostalgic 1950s Civil Defense broadcast arpeggio (A3-C4-E4-F#4-A4-F#4-E4-C4)
	var arp_targets: Array[float] = [220.00, 261.63, 329.63, 369.99, 440.00, 369.99, 329.63, 261.63]
	var step_samples: float = float(loop_samples) / float(arp_targets.size())
	var step_dur: float = step_samples * inv_sr

	# Phase-locked electric organ chord frequencies (A2, E3, A3, C4, F#4) + carrier
	var org_a2: float = _lock_freq(110.00, loop_dur)
	var org_e3: float = _lock_freq(164.81, loop_dur)
	var org_a3: float = _lock_freq(220.00, loop_dur)
	var org_c4: float = _lock_freq(261.63, loop_dur)
	var org_fs4: float = _lock_freq(369.99, loop_dur)
	var hum_60: float = _lock_freq(60.0, loop_dur)
	var carrier_640: float = _lock_freq(640.0, loop_dur)
	var lfo_trem: float = _lock_freq(5.5, loop_dur)
	var lfo_slow: float = _lock_freq(0.5, loop_dur)

	var core := PackedFloat32Array()
	core.resize(loop_samples)
	for i in range(loop_samples):
		var t: float = float(i) * inv_sr
		var step_idx: int = clampi(int(float(i) / step_samples), 0, arp_targets.size() - 1)
		var nt: float = (float(i) - float(step_idx) * step_samples) * inv_sr
		var nf: float = arp_targets[step_idx]

		# Warm motor-driven vibraphone mallet strike + fundamental + fast-decaying 4x harmonic
		var v_attack: float = smoothstep(0.0, 0.012, nt)
		var v_release: float = smoothstep(0.0, 0.028, step_dur - nt)
		var v_env: float = v_attack * v_release * exp(-nt * 3.6)
		var motor_trem: float = 0.80 + 0.20 * sin(TAU * lfo_trem * t)
		var chorus_w: float = sin(TAU * nf * nt) * 0.56 + sin(TAU * (nf * 1.0035) * nt) * 0.34
		var mallet_bell: float = sin(TAU * nf * 4.0 * nt) * 0.16 * exp(-nt * 18.0)
		var vibes: float = (chorus_w + mallet_bell) * v_env * motor_trem * 0.42

		# Warm vacuum-tube electric organ Am6 pad with gentle rotary scanner chorus
		var rot_mod: float = 0.0025 * sin(TAU * lfo_trem * t)
		var swell: float = 0.86 + 0.14 * sin(TAU * lfo_slow * t)
		var organ: float = (
			sin(TAU * org_a2 * t) * 0.24
			+ sin(TAU * org_e3 * t + rot_mod) * 0.18
			+ sin(TAU * org_a3 * t - rot_mod) * 0.16
			+ sin(TAU * org_c4 * t + rot_mod * 1.4) * 0.15
			+ sin(TAU * org_fs4 * t - rot_mod * 1.2) * 0.12
		) * swell * 0.32

		# Gentle CONELRAD 640 KC tube carrier & 60 Hz filament warmth
		var radio_warmth: float = (
			sin(TAU * hum_60 * t) * 0.08
			+ sin(TAU * hum_60 * 2.0 * t) * 0.035
			+ sin(TAU * carrier_640 * t) * (0.018 + 0.008 * sin(TAU * lfo_slow * 2.0 * t))
		)
		core[i] = vibes + organ + radio_warmth

	# Circular stereo-feeling tape slapback echo (186ms + 310ms) + gentle vinyl/tube hiss
	var delay_a: int = 4100
	var delay_b: int = 6835
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp_hiss: float = 0.0
	for i in range(n):
		var c_idx: int = i % loop_samples
		var echo_a: float = core[(c_idx - delay_a + loop_samples) % loop_samples]
		var echo_b: float = core[(c_idx - delay_b + loop_samples) % loop_samples]
		lp_hiss += 0.06 * (_next_noise() - lp_hiss)
		var layered: float = core[c_idx] * 0.78 + echo_a * 0.28 + echo_b * 0.14 + lp_hiss * 0.06
		buf[i] = tanh(layered * 1.05) * 0.72
	return _build_wav(buf, true)

# Looping Music 2: "scavenge" — Driving rhythmic staccato bass pulse + ticking brass
# urgency motif (4.0s seamless 22050Hz loop)
func _synth_ambience_scavenge() -> AudioStreamWAV:
	var dur: float = 4.0
	var n: int = int(dur * MIX_RATE)
	var fade_len: int = 1024
	var loop_samples: int = n - fade_len
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var loop_dur: float = float(loop_samples) * inv_sr

	# 16-step urgent mid-century spy/Civil-Defense staccato bassline in D minor
	var bass_steps: Array[float] = [
		73.42, 73.42, 146.83, 73.42,
		87.31, 73.42, 98.00, 73.42,
		82.41, 82.41, 164.81, 82.41,
		116.54, 110.00, 87.31, 82.41
	]
	# Syncopated muted-brass urgency stabs on steps 0, 3, 6, 8, 11, 14 (0.0 = rest)
	var brass_hi: Array[float] = [
		293.66, 0.0, 0.0, 349.23,
		0.0, 0.0, 392.00, 0.0,
		329.63, 0.0, 0.0, 369.99,
		0.0, 0.0, 440.00, 0.0
	]
	var brass_lo: Array[float] = [
		220.00, 0.0, 0.0, 261.63,
		0.0, 0.0, 293.66, 0.0,
		220.00, 0.0, 0.0, 261.63,
		0.0, 0.0, 349.23, 0.0
	]

	var step_samples: float = float(loop_samples) / 16.0
	var step_dur: float = step_samples * inv_sr
	var drone_d1: float = _lock_freq(36.71, loop_dur)
	var lfo_siren: float = _lock_freq(1.0, loop_dur)

	var core := PackedFloat32Array()
	core.resize(loop_samples)
	for i in range(loop_samples):
		var t: float = float(i) * inv_sr
		var step_idx: int = clampi(int(float(i) / step_samples), 0, 15)
		var st: float = (float(i) - float(step_idx) * step_samples) * inv_sr

		# 1. Driving staccato bass pulse
		var bf: float = bass_steps[step_idx]
		var b_att: float = smoothstep(0.0, 0.007, st)
		var b_rel: float = smoothstep(0.0, 0.018, step_dur - st)
		var b_env: float = b_att * b_rel * exp(-st * 9.5)
		var bass_wave: float = (
			sin(TAU * bf * st) * 0.56
			+ sin(TAU * bf * 2.0 * st) * 0.34
			+ sin(TAU * bf * 3.0 * st) * 0.18 * exp(-st * 16.0)
		) * b_env * 0.52

		# 2. Syncopated ticking brass urgency motif
		var brass_sig: float = 0.0
		var bh: float = brass_hi[step_idx]
		if bh > 1.0:
			var bl: float = brass_lo[step_idx]
			var br_att: float = smoothstep(0.0, 0.008, st)
			var br_rel: float = smoothstep(0.0, 0.022, step_dur - st)
			var br_env: float = br_att * br_rel * exp(-st * 7.8)
			var br_bright: float = 0.65 + 0.35 * exp(-st * 22.0)
			var v_hi: float = sin(TAU * bh * st) * 0.50 + sin(TAU * bh * 2.0 * st) * 0.34 * br_bright + sin(TAU * bh * 3.0 * st) * 0.20 * br_bright
			var v_lo: float = sin(TAU * bl * st) * 0.45 + sin(TAU * bl * 2.0 * st) * 0.26 * br_bright
			brass_sig = (v_hi + v_lo) * br_env * 0.34

		# 3. Crisp rhythmic clockwork rim-tick on every step (accented on even 8th notes)
		var tick_acc: float = 1.0 if (step_idx % 2 == 0) else 0.52
		var tick_att: float = smoothstep(0.0, 0.002, st)
		var tick_sig: float = (sin(TAU * 1760.0 * st) * 0.55 + sin(TAU * 3120.0 * st) * 0.35) * tick_att * exp(-st * 95.0) * tick_acc * 0.22

		# 4. Subtle dynamo tension sub-pedal
		var sub_pedal: float = sin(TAU * drone_d1 * t) * (0.10 + 0.04 * sin(TAU * lfo_siren * t))
		core[i] = bass_wave + brass_sig + tick_sig + sub_pedal

	# Dotted-16th spatial room slapback delay + subtle air rush
	var slap_samples: int = int(step_samples * 1.5)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp_air: float = 0.0
	for i in range(n):
		var c_idx: int = i % loop_samples
		var slap: float = core[(c_idx - slap_samples + loop_samples) % loop_samples]
		lp_air += 0.10 * (_next_noise() - lp_air)
		var mix_s: float = core[c_idx] * 0.84 + slap * 0.24 + lp_air * 0.05
		buf[i] = tanh(mix_s * 1.15) * 0.74
	return _build_wav(buf, true)

# Looping Music 3: "bunker" — Somber, cinematic subterranean cello/organ chord progression
# + faint distant wind & ventilation resonance (4.0s seamless 22050Hz loop)
func _synth_ambience_bunker() -> AudioStreamWAV:
	var dur: float = 4.0
	var n: int = int(dur * MIX_RATE)
	var fade_len: int = 1024
	var loop_samples: int = n - fade_len
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var loop_dur: float = float(loop_samples) * inv_sr

	# Smoothly morphing 2-chord subterranean progression:
	# Half A: Dm(add9) [D2=73.42, A2=110.0, D3=146.83, F3=174.61, E4=329.63]
	# Half B: Gm6/Bb   [Bb1=58.27, G2=98.00, D3=146.83, F3=174.61, A3=220.00]
	var c1_d2: float = _lock_freq(73.42, loop_dur)
	var c1_a2: float = _lock_freq(110.00, loop_dur)
	var c1_d3: float = _lock_freq(146.83, loop_dur)
	var c1_f3: float = _lock_freq(174.61, loop_dur)
	var c1_e4: float = _lock_freq(329.63, loop_dur)

	var c2_bb1: float = _lock_freq(58.27, loop_dur)
	var c2_g2: float = _lock_freq(98.00, loop_dur)
	var c2_a3: float = _lock_freq(220.00, loop_dur)

	var lfo_vib: float = _lock_freq(4.5, loop_dur)
	var lfo_breath: float = _lock_freq(0.5, loop_dur)
	var vent_60: float = _lock_freq(60.0, loop_dur)

	var core := PackedFloat32Array()
	core.resize(loop_samples)
	for i in range(loop_samples):
		var t: float = float(i) * inv_sr
		var u: float = float(i) / float(loop_samples)
		# Smooth periodic crossfade weight between Chord A (u around 0/1) and Chord B (u around 0.5)
		var morph_b: float = pow(sin(PI * u), 2.0)
		var morph_a: float = 1.0 - morph_b

		var vib_phase: float = 0.018 * sin(TAU * lfo_vib * t)
		var bow_swell: float = 0.84 + 0.16 * sin(TAU * lfo_breath * 2.0 * t)

		# Subterranean bowed cello & contrabass (warm string harmonics 1..4)
		var cello_a: float = (
			sin(TAU * c1_d2 * t) * 0.44
			+ sin(TAU * c1_d2 * 2.0 * t) * 0.22
			+ sin(TAU * c1_a2 * t + vib_phase) * 0.30
			+ sin(TAU * c1_d3 * t + vib_phase * 1.5) * 0.28
			+ sin(TAU * c1_d3 * 2.0 * t + vib_phase * 2.0) * 0.12
		)
		var cello_b: float = (
			sin(TAU * c2_bb1 * t) * 0.46
			+ sin(TAU * c2_bb1 * 2.0 * t) * 0.24
			+ sin(TAU * c2_g2 * t + vib_phase) * 0.30
			+ sin(TAU * c1_d3 * t + vib_phase * 1.3) * 0.26
			+ sin(TAU * c2_a3 * t - vib_phase) * 0.18
		)
		var cello_mix: float = (cello_a * morph_a + cello_b * morph_b) * bow_swell * 0.44

		# Somber shelter organ harmony + mournful high voice (E4 <-> A3)
		var organ_a: float = sin(TAU * c1_f3 * t) * 0.24 + sin(TAU * c1_e4 * t + vib_phase) * 0.16
		var organ_b: float = sin(TAU * c1_f3 * t) * 0.22 + sin(TAU * c2_a3 * t + vib_phase) * 0.20
		var organ_mix: float = (organ_a * morph_a + organ_b * morph_b) * 0.36

		# Shelter air-filtration ballast resonance
		var vent_hum: float = sin(TAU * vent_60 * t) * 0.08 + sin(TAU * vent_60 * 2.0 * t) * 0.035
		core[i] = cello_mix + organ_mix + vent_hum

	# Subterranean concrete cavern reflection (245ms) + faint distant wasteland wind
	var cavern_delay: int = 5400
	var buf := PackedFloat32Array()
	buf.resize(n)
	var wind_lp1: float = 0.0
	var wind_lp2: float = 0.0
	for i in range(n):
		var c_idx: int = i % loop_samples
		var u_all: float = float(c_idx) / float(loop_samples)
		var wind_cutoff: float = 0.035 + 0.025 * sin(TAU * u_all)
		var raw_w: float = _next_noise()
		wind_lp1 += wind_cutoff * (raw_w - wind_lp1)
		wind_lp2 += wind_cutoff * (wind_lp1 - wind_lp2)
		var wind_gust: float = wind_lp2 * (0.22 + 0.10 * sin(TAU * u_all + 0.9))

		var refl: float = core[(c_idx - cavern_delay + loop_samples) % loop_samples]
		var out_s: float = core[c_idx] * 0.80 + refl * 0.28 + wind_gust
		buf[i] = tanh(out_s * 1.08) * 0.72
	return _build_wav(buf, true)
