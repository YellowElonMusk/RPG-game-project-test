## Pure color-difference math for presentation data audits (GDD
## `design/gdd/sprite-camera-presentation.md` rule 11 and AC-16; the GDD's
## ΔE is CIEDE2000 throughout, e.g. `flood_native_de_min`). sRGB colors are
## converted to CIELAB under D65 and compared with the CIEDE2000 formula
## (Sharma, Wu & Dalal 2005). Holds no state and touches no node.
class_name ColorDifference
extends RefCounted

## D65 reference white (CIE 1931 2-degree observer), Y normalised to 1.
const _WHITE_X: float = 0.95047
const _WHITE_Y: float = 1.0
const _WHITE_Z: float = 1.08883
const _POW25_7: float = 6103515625.0  # 25^7
## CIELAB's linear-segment threshold and slope (CIE 15:2004 exact ratios).
const _LAB_EPS: float = 0.008856451679035631  # 216 / 24389
const _LAB_KAPPA: float = 903.2962962962963  # 24389 / 27


## The CIELAB `(L*, a*, b*)` of an sRGB `color` (alpha ignored), D65.
static func srgb_to_lab(color: Color) -> Vector3:
	var lin: Color = color.srgb_to_linear()
	var x: float = 0.4124564 * lin.r + 0.3575761 * lin.g + 0.1804375 * lin.b
	var y: float = 0.2126729 * lin.r + 0.7151522 * lin.g + 0.0721750 * lin.b
	var z: float = 0.0193339 * lin.r + 0.1191920 * lin.g + 0.9503041 * lin.b
	var fx: float = _lab_f(x / _WHITE_X)
	var fy: float = _lab_f(y / _WHITE_Y)
	var fz: float = _lab_f(z / _WHITE_Z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## CIEDE2000 ΔE between two sRGB colors (alpha ignored).
static func delta_e_srgb(a: Color, b: Color) -> float:
	return delta_e_2000(srgb_to_lab(a), srgb_to_lab(b))


## CIEDE2000 ΔE between two CIELAB colors `(L*, a*, b*)`, with
## `kL = kC = kH = 1`.
static func delta_e_2000(lab1: Vector3, lab2: Vector3) -> float:
	var c1: float = sqrt(lab1.y * lab1.y + lab1.z * lab1.z)
	var c2: float = sqrt(lab2.y * lab2.y + lab2.z * lab2.z)
	var c_bar7: float = pow((c1 + c2) * 0.5, 7.0)
	var g: float = 0.5 * (1.0 - sqrt(c_bar7 / (c_bar7 + _POW25_7)))
	var a1p: float = (1.0 + g) * lab1.y
	var a2p: float = (1.0 + g) * lab2.y
	var c1p: float = sqrt(a1p * a1p + lab1.z * lab1.z)
	var c2p: float = sqrt(a2p * a2p + lab2.z * lab2.z)
	var h1p: float = _hue_deg(lab1.z, a1p)
	var h2p: float = _hue_deg(lab2.z, a2p)

	var dl: float = lab2.x - lab1.x
	var dc: float = c2p - c1p
	var dh_deg: float = 0.0
	if c1p * c2p != 0.0:
		dh_deg = h2p - h1p
		if dh_deg > 180.0:
			dh_deg -= 360.0
		elif dh_deg < -180.0:
			dh_deg += 360.0
	var dh: float = 2.0 * sqrt(c1p * c2p) * sin(deg_to_rad(dh_deg) * 0.5)

	var l_bar: float = (lab1.x + lab2.x) * 0.5
	var c_bar_p: float = (c1p + c2p) * 0.5
	var h_bar_p: float = h1p + h2p
	if c1p * c2p != 0.0:
		if absf(h1p - h2p) <= 180.0:
			h_bar_p = (h1p + h2p) * 0.5
		elif h1p + h2p < 360.0:
			h_bar_p = (h1p + h2p + 360.0) * 0.5
		else:
			h_bar_p = (h1p + h2p - 360.0) * 0.5

	var t: float = 1.0 - 0.17 * cos(deg_to_rad(h_bar_p - 30.0)) \
			+ 0.24 * cos(deg_to_rad(2.0 * h_bar_p)) \
			+ 0.32 * cos(deg_to_rad(3.0 * h_bar_p + 6.0)) \
			- 0.20 * cos(deg_to_rad(4.0 * h_bar_p - 63.0))
	var d_theta: float = 30.0 * exp(-pow((h_bar_p - 275.0) / 25.0, 2.0))
	var c_bar_p7: float = pow(c_bar_p, 7.0)
	var r_c: float = 2.0 * sqrt(c_bar_p7 / (c_bar_p7 + _POW25_7))
	var l50: float = (l_bar - 50.0) * (l_bar - 50.0)
	var s_l: float = 1.0 + 0.015 * l50 / sqrt(20.0 + l50)
	var s_c: float = 1.0 + 0.045 * c_bar_p
	var s_h: float = 1.0 + 0.015 * c_bar_p * t
	var r_t: float = -sin(deg_to_rad(2.0 * d_theta)) * r_c
	var tl: float = dl / s_l
	var tc: float = dc / s_c
	var th: float = dh / s_h
	return sqrt(tl * tl + tc * tc + th * th + r_t * tc * th)


static func _lab_f(v: float) -> float:
	if v > _LAB_EPS:
		return pow(v, 1.0 / 3.0)
	return (_LAB_KAPPA * v + 16.0) / 116.0


static func _hue_deg(b: float, a_prime: float) -> float:
	if b == 0.0 and a_prime == 0.0:
		return 0.0
	var h: float = rad_to_deg(atan2(b, a_prime))
	return h + 360.0 if h < 0.0 else h
