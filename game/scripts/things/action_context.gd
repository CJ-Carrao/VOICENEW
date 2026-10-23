class_name ActionContext
extends RefCounted



var point: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
var normal: Vector3 = Vector3.UP

var target: Node3D = null

var shots: int = -1

var barrel: int = -1

var charge: float = 0.0


static func make(at: Vector3, dir: Vector3 = Vector3.FORWARD, who: Node3D = null) -> ActionContext:
	var ctx: = ActionContext.new()
	ctx.point = at
	ctx.direction = dir.normalized() if dir.length_squared() > 0.0 else Vector3.FORWARD
	ctx.target = who
	return ctx
