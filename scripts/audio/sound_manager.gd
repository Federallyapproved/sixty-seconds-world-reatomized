extends Node

## Procedural audio synthesizer and sound manager (outdoor warning sirens, emergency-alert tones).
## Generates crisp 16-bit mono 22050 Hz PCM AudioStreamWAV assets at startup so
## there are zero external audio dependencies and Godot --write-movie captures
## its SFX and continuous atmospheric background audio.

const MIX_RATE: int = 22050
const SFX_POOL_SIZE: int = 6
const AMBIENT_VOLUME_DB: float = -18.0

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

func _build_wav(samples: PackedFloat32Array, looped: bool = false) -> AudioStreamWAV:
	var count: int = samples.size()
	if looped and count > 2048:
		# Smooth crossfade across loop seam for click-free continuous playback
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
	_sfx_streams["gunshot"] = _synth_gunshot()
	_sfx_streams["wrench"] = _synth_wrench()
	_sfx_streams["cheer"] = _synth_cheer()
	_sfx_streams["thud"] = _synth_thud()
	_sfx_streams["sparks"] = _synth_sparks()
	_sfx_streams["engine_start"] = _synth_engine_start()
	_sfx_streams["ladder"] = _synth_ladder()

func _generate_all_ambience() -> void:
	_ambient_streams["menu"] = _synth_ambience_menu()
	_ambient_streams["scavenge"] = _synth_ambience_scavenge()
	_ambient_streams["bunker"] = _synth_ambience_bunker()

# 1. "siren": Rising-and-falling dual-tone outdoor warning siren (2.2s)
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
		var f2: float = f1 * 1.20 # 5:6 dual-rotor siren portamento
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
		# First tick at t=0.0
		s += (sin(TAU * 2350.0 * t) * 0.5 + _next_noise() * 0.35) * exp(-t * 130.0)
		# Second tick at t=0.048
		if t >= 0.048:
			var dt: float = t - 0.048
			s += (sin(TAU * 2650.0 * dt) * 0.55 + _next_noise() * 0.35) * exp(-dt * 130.0)
		# Emergency Alert System two-tone pip (853 Hz + 960 Hz)
		var beep_env: float = sin(PI * clampf(t / 0.105, 0.0, 1.0))
		var beep: float = (sin(TAU * 853.0 * t) * 0.48 + sin(TAU * 960.0 * t) * 0.42) * beep_env * 0.48
		var fade_out: float = minf(1.0, (dur - t) / 0.01)
		buf[i] = clampf((s + beep) * fade_out * 0.85, -0.95, 0.95)
	return _build_wav(buf, false)

# 4. "pickup": Snappy upward chime/pop (0.14s)
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
		# Chute downward slide + filtered air noise
		var slide_f: float = lerpf(580.0, 175.0, clampf(t / 0.13, 0.0, 1.0))
		whoosh_phase += TAU * slide_f * inv_sr
		var raw_n: float = _next_noise()
		lp_state += 0.24 * (raw_n - lp_state)
		var whoosh_env: float = sin(PI * clampf(t / 0.14, 0.0, 1.0))
		var whoosh: float = (sin(whoosh_phase) * 0.45 + lp_state * 0.65) * whoosh_env * 0.55

		# Confirming C-major triad starting at t=0.055s
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
		# Heavy blast door thud + steel plate modes
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

		# Secondary mechanical steel dog-latch lock at t=0.27s
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

		# Two-pole sweeping low-pass filter on shockwave roar noise
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
		# High-passed crispness + swept low-pass for paper rustle contour
		var hp: float = raw - prev_raw * 0.82
		prev_raw = raw
		var alpha: float = lerpf(0.18, 0.58, sin(PI * u))
		lp += alpha * (hp - lp)
		var env: float = sin(PI * pow(u, 0.72))
		var flick: float = hp * exp(-t * 160.0) * 0.25
		buf[i] = clampf((lp * env * 0.85 + flick) * 0.68, -0.9, 0.9)
	return _build_wav(buf, false)

# 9. "button_click": Tactile plastic switch click (0.05s)
func _synth_button_click() -> AudioStreamWAV:
	var dur: float = 0.05
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		# Stage 1: crisp phenolic contact snap
		var snap1: float = (
			sin(TAU * 980.0 * t) * 0.55
			+ sin(TAU * 2420.0 * t) * 0.35
			+ _next_noise() * 0.40 * exp(-t * 320.0)
		) * exp(-t * 170.0)
		# Stage 2: housing settle at t=0.015s
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

# 12. "victory": Warm brassy 4-note major fanfare (1.4s)
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

# 13. "gameover": Somber descending minor chord (1.5s)
func _synth_gameover() -> AudioStreamWAV:
	var dur: float = 1.5
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var vib: float = 1.0 + 0.005 * sin(TAU * 4.2 * t)
		var lead_f: float = 349.23 # F4 -> E4 -> D4 mournful descent
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
		# Underlying warm D-minor pad (D3, F3, A3)
		var pad_env: float = minf(1.0, t / 0.08) * exp(-t * 1.15) * minf(1.0, (dur - t) / 0.18)
		var pad: float = (
			sin(TAU * 146.83 * t) * 0.42
			+ sin(TAU * 174.61 * vib * t) * 0.36
			+ sin(TAU * 220.00 * vib * t) * 0.32
			+ sin(TAU * 73.42 * t) * 0.28
		) * pad_env * 0.58
		buf[i] = tanh((lead + pad) * 1.05) * 0.78
	return _build_wav(buf, false)

# Looping Ambience 1: "menu" — mains hum & a faint emergency-broadcast carrier tone (2.0s seamless loop)
func _synth_ambience_menu() -> AudioStreamWAV:
	var dur: float = 2.0
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var hum: float = sin(TAU * 60.0 * t) * 0.22 + sin(TAU * 120.0 * t) * 0.11 + sin(TAU * 180.0 * t) * 0.04
		var carrier: float = sin(TAU * 640.0 * t) * (0.035 + 0.015 * sin(TAU * 0.5 * t))
		lp += 0.08 * (_next_noise() - lp)
		buf[i] = (hum + carrier + lp * 0.16) * 0.55
	return _build_wav(buf, true)

# Looping Ambience 2: "scavenge" — Urgent siren-backed drone & subtle pulse (2.0s seamless loop)
func _synth_ambience_scavenge() -> AudioStreamWAV:
	var dur: float = 2.0
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		var pulse: float = 0.72 + 0.28 * sin(TAU * 2.0 * t)
		var dynamo: float = (sin(TAU * 55.0 * t) * 0.26 + sin(TAU * 110.0 * t) * 0.16 + sin(TAU * 220.0 * t) * 0.07) * pulse
		var distant_horn: float = (sin(TAU * 330.0 * t) * 0.045 + sin(TAU * 396.0 * t) * 0.035) * (0.6 + 0.4 * sin(TAU * 1.0 * t))
		lp += 0.12 * (_next_noise() - lp)
		buf[i] = (dynamo + distant_horn + lp * 0.14) * 0.60
	return _build_wav(buf, true)

# Looping Ambience 3: "bunker" — Deep shelter air-filtration rumble & ballast hum (2.0s seamless loop)
func _synth_ambience_bunker() -> AudioStreamWAV:
	var dur: float = 2.0
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp1: float = 0.0
	var lp2: float = 0.0
	var inv_sr: float = 1.0 / float(MIX_RATE)
	for i in range(n):
		var t: float = float(i) * inv_sr
		lp1 += 0.06 * (_next_noise() - lp1)
		lp2 += 0.06 * (lp1 - lp2)
		var duct_swell: float = 0.85 + 0.15 * sin(TAU * 0.5 * t)
		var ballast: float = sin(TAU * 60.0 * t) * 0.18 + sin(TAU * 120.0 * t) * 0.09 + sin(TAU * 240.0 * t) * 0.025
		buf[i] = (ballast + lp2 * 0.42 * duct_swell) * 0.58
	return _build_wav(buf, true)


# --- Pass-2 cinematic effects ------------------------------------------------

func _synth_gunshot() -> AudioStreamWAV:
	var dur: float = 0.7
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var crack: float = _next_noise() * exp(-t * 60.0)
		lp = lp + (_next_noise() - lp) * 0.08
		var boom: float = lp * exp(-t * 7.0) * 2.2 + sin(TAU * 62.0 * t) * exp(-t * 9.0) * 0.6
		var echo: float = 0.0
		if t > 0.18:
			echo = _next_noise() * exp(-(t - 0.18) * 14.0) * 0.18
		buf[i] = tanh((crack * 1.4 + boom + echo) * 1.3) * 0.9
	return _build_wav(buf, false)


func _synth_wrench() -> AudioStreamWAV:
	var dur: float = 0.6
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var hits: Array[float] = [0.0, 0.16, 0.31]
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var s: float = 0.0
		for h in hits:
			if t >= h:
				var dt: float = t - h
				s += (sin(TAU * 1250.0 * dt) * 0.4 + sin(TAU * 2310.0 * dt) * 0.25 + sin(TAU * 3480.0 * dt) * 0.15) * exp(-dt * 24.0)
				s += _next_noise() * exp(-dt * 180.0) * 0.3
		buf[i] = tanh(s) * 0.7
	return _build_wav(buf, false)


func _synth_cheer() -> AudioStreamWAV:
	var dur: float = 1.3
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var bp1: float = 0.0
	var bp2: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var env: float = minf(1.0, t / 0.15) * exp(-maxf(0.0, t - 0.5) * 2.2)
		var nz: float = _next_noise()
		bp1 = bp1 + (nz - bp1) * 0.18
		bp2 = bp2 + (bp1 - bp2) * 0.35
		var voices: float = (sin(TAU * (300.0 + 40.0 * sin(t * 7.0)) * t) + sin(TAU * (420.0 + 30.0 * sin(t * 5.3)) * t) * 0.7 + sin(TAU * (520.0 + 50.0 * sin(t * 9.1)) * t) * 0.5) * 0.25
		var claps: float = 0.0
		var ph: float = fmod(t * 7.3, 1.0)
		if ph < 0.05 and t > 0.2:
			claps = _next_noise() * (0.05 - ph) * 12.0
		buf[i] = tanh((bp2 * 1.6 + voices * (0.5 + 0.5 * bp2) + claps) * env) * 0.75
	return _build_wav(buf, false)


func _synth_thud() -> AudioStreamWAV:
	var dur: float = 0.45
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		lp = lp + (_next_noise() - lp) * 0.05
		var body: float = sin(TAU * (95.0 - 40.0 * t) * t) * exp(-t * 11.0)
		buf[i] = tanh((body * 1.2 + lp * exp(-t * 16.0) * 2.0) * 1.2) * 0.85
	return _build_wav(buf, false)


func _synth_sparks() -> AudioStreamWAV:
	var dur: float = 0.5
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var hp_prev: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var nz: float = _next_noise()
		var hp: float = nz - hp_prev
		hp_prev = nz
		var crackle: float = hp * (1.0 if _next_noise() > 0.7 else 0.15)
		var hum: float = sin(TAU * 120.0 * t) * 0.25 * exp(-t * 4.0)
		buf[i] = tanh((crackle * 0.9 + hum) * exp(-t * 3.0) * 1.4) * 0.75
	return _build_wav(buf, false)


func _synth_engine_start() -> AudioStreamWAV:
	var dur: float = 2.6
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var s: float = 0.0
		if t < 1.1:
			# starter motor cranking: chugging ~6 Hz
			var crank: float = 0.5 + 0.5 * sin(TAU * 6.2 * t)
			s = (sin(TAU * 140.0 * t) * 0.4 + _next_noise() * 0.25) * crank * 0.8
		else:
			# catches and idles: rising rpm then settles
			var rpm_hz: float = 28.0 + 22.0 * exp(-(t - 1.1) * 2.0) + 6.0
			phase += rpm_hz / float(MIX_RATE)
			var pulse: float = pow(0.5 + 0.5 * sin(TAU * phase), 6.0)
			s = (pulse * 0.9 + sin(TAU * rpm_hz * 2.0 * t) * 0.15 + _next_noise() * 0.08) * minf(1.0, (t - 1.1) * 6.0)
		var fade: float = minf(1.0, (dur - t) / 0.3)
		buf[i] = tanh(s * 1.3) * 0.8 * fade
	return _build_wav(buf, false)


func _synth_ladder() -> AudioStreamWAV:
	var dur: float = 0.9
	var n: int = int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var steps: Array[float] = [0.0, 0.22, 0.44, 0.66]
	for i in range(n):
		var t: float = float(i) / float(MIX_RATE)
		var s: float = 0.0
		for st in steps:
			if t >= st:
				var dt: float = t - st
				s += (sin(TAU * 420.0 * dt) * 0.35 + sin(TAU * 810.0 * dt) * 0.2) * exp(-dt * 40.0) + _next_noise() * exp(-dt * 120.0) * 0.25
		buf[i] = tanh(s) * 0.6
	return _build_wav(buf, false)
