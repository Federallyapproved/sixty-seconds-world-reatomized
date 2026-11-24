class_name DoseFormat
extends RefCounted

## One consistent way to print radiation everywhere (HUD, journal, planner, nuke screen):
## dose rates in µSv/h · mSv/h · Sv/h and doses in mSv · Sv. Pure (no autoloads) so physics
## helpers and script-mode tools can use it.

static func rate(rate_msv_h: float) -> String:
	if rate_msv_h >= 1000.0:
		return "%.1f Sv/h" % (rate_msv_h / 1000.0)
	if rate_msv_h >= 10.0:
		return "%.0f mSv/h" % rate_msv_h
	if rate_msv_h >= 0.1:
		return "%.1f mSv/h" % rate_msv_h
	return "%.0f µSv/h" % (rate_msv_h * 1000.0)


static func dose(dose_msv: float) -> String:
	if dose_msv >= 1000.0:
		return "%.2f Sv" % (dose_msv / 1000.0)
	if dose_msv >= 1.0:
		return "%.0f mSv" % dose_msv
	return "%.2f mSv" % dose_msv
