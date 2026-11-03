## WCAG 2.x contrast (story 074, AC-69): relative luminance of sRGB colours
## and the (L1 + 0.05) / (L2 + 0.05) ratio, lighter over darker.
##
## Usage example:
## [codeblock]
## var ratio: float = WcagContrast.ratio(Color("#f2ead8"), Color("#2a2d40"))
## assert(ratio >= WcagContrast.AA_TEXT)
## [/codeblock]
class_name WcagContrast
extends RefCounted

## The AA minimum for normal text.
const AA_TEXT: float = 4.5


## Relative luminance of an sRGB colour (alpha ignored).
static func luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


## Contrast ratio between two sRGB colours, always >= 1.
static func ratio(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
