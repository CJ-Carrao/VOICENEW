class_name DomainCallout
extends RefCounted

static var count := 0
static var last_mode := ""
static var last_text := ""

# Kept as a no-op for network compatibility with domain FX messages.
static func announce(_parent: Node, _at: Vector3, _mode: String) -> void:
	pass
