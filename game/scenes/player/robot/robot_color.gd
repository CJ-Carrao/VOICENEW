class_name RobotColor
extends RefCounted


static func to_rgb24(color: Color) -> int:
	return (clampi(roundi(color.r * 255.0), 0, 255) << 16)\
	| (clampi(roundi(color.g * 255.0), 0, 255) << 8)\
	| clampi(roundi(color.b * 255.0), 0, 255)

static func from_rgb24(value: int) -> Color:
	return Color8((value >> 16) & 255, (value >> 8) & 255, value & 255)
