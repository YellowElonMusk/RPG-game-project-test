## The literal joy-name -> pad-style fixture (story 014, GDD AC-12). The
## style a name maps to IS the requirement, so every expectation here is a
## hand-written literal, never computed by running the matcher over the
## config (that would be tautological). The names are synthetic stand-ins;
## real SDL3 hardware names are a deferred manual item.
class_name JoyNames
extends RefCounted

## [joy name, expected style] rows for the DEFAULT `pad_style_patterns`.
const DEFAULT_ROWS: Array = [
	["Xbox Series X Controller", &"xbox"],
	["XBOX 360 CONTROLLER", &"xbox"],
	["DualSense Wireless Controller", &"playstation"],
	["PS4 Controller", &"playstation"],
	["Nintendo Switch Pro Controller", &"nintendo"],
	["Steam Virtual Gamepad", &"xbox"],
	["Steam Deck Controller", &"xbox"],
	["Acme USB Pad", &"generic"],
	["", &"generic"],
]

## The non-default pattern list and its literal expectation.
const CUSTOM_PATTERNS: Array[String] = ["acme:nintendo"]
const CUSTOM_NAME: String = "Acme USB Pad"
const CUSTOM_STYLE: StringName = &"nintendo"

## First match wins: a name matching both rows takes the earlier row's style.
const ORDER_PATTERNS: Array[String] = ["pad:generic", "acme:nintendo"]
const ORDER_NAME: String = "Acme Pad"
const ORDER_STYLE: StringName = &"generic"

## Story 015's two pads.
const XBOX_NAME: String = "Xbox Series X Controller"
const PLAYSTATION_NAME: String = "DualSense Wireless Controller"
