extends RefCounted

# Adapt the Lab silhouettes to the upstream CreatureAnimator without replacing their art.
static func build(original: Array, aerial: bool) -> Dictionary:
 var pieces: Array = original.duplicate(true)
 for piece: Dictionary in pieces: piece.erase("bone")
 var full := ModelBuilder._piece_box(pieces[0])
 for piece: Dictionary in pieces: full=full.merge(ModelBuilder._piece_box(piece))
 var center:=full.get_center()
 var joints: Dictionary={"body":{"pivot":[center.x,center.y,center.z],"parent":""}}
 var legs: Array=[]
 for piece: Dictionary in pieces:
  var tag=String(piece.get("tag",""))
  if not tag.begins_with("leg"):continue
  var point=ModelBuilder._vec(piece.get("pos",[0,0,0]))
  var side=-1 if point.x<center.x else 1
  var group: Dictionary={}
  for candidate: Dictionary in legs:
   if candidate.side==side and absf(float(candidate.z)-point.z)<maxf(.035,full.size.z*.055):group=candidate;break
  if group.is_empty():
   group={"side":side,"z":point.z,"pieces":[],"box":ModelBuilder._piece_box(piece)}
   legs.append(group)
  group.pieces.append(piece)
  group.box=group.box.merge(ModelBuilder._piece_box(piece))
 var kind="flier" if aerial else "biped" if legs.size()==2 else "quadruped" if legs.size()==4 else "arthropod" if legs.size()>0 else "generic"
 legs.sort_custom(func(a,b):return a.z<b.z)
 var serial={-1:0,1:0}
 for index in legs.size():
  var group: Dictionary=legs[index]
  var box: AABB=group.box
  var foot=Vector3(box.get_center().x,box.position.y,box.get_center().z)
  var hip=Vector3(foot.x,box.end.y,foot.z)
  var knee=hip.lerp(foot,.5)
  var side="l" if group.side<0 else "r"
  var suffix=side
  if kind=="quadruped":
   suffix=("f" if serial[group.side]==0 else "h")+side;serial[group.side]+=1
  elif legs.size()!=2:
   suffix=side+"_"+str(serial[group.side]);serial[group.side]+=1
  group.hip="hip_"+suffix;group.knee="knee_"+suffix
  var phase=float(index%2)*.5
  if kind=="quadruped":phase=.5 if suffix in ["fl","hr"] else 0.0
  joints[group.hip]={"pivot":[hip.x,hip.y,hip.z],"parent":"body","phase":phase,"foot":[foot.x,foot.y,foot.z]}
  joints[group.knee]={"pivot":[knee.x,knee.y,knee.z],"parent":group.hip,"foot":[foot.x,foot.y,foot.z]}
  # Single block legs become two linked blocks, preserving the rest silhouette.
  if group.pieces.size()==1:
   var piece: Dictionary=group.pieces[0]
   if String(piece.get("shape",""))=="box" and piece.get("rot",[0,0,0])==[0,0,0] and piece.has("size"):
    var lower=piece.duplicate(true)
    var size=ModelBuilder._vec(piece.size)
    var point=ModelBuilder._vec(piece.pos)
    piece.size=[size.x,size.y*.5,size.z];piece.pos=[point.x,point.y+size.y*.25,point.z];piece.bone=group.hip
    lower.size=[size.x,size.y*.5,size.z];lower.pos=[point.x,point.y-size.y*.25,point.z];lower.bone=group.knee
    pieces.append(lower)
  for piece: Dictionary in group.pieces:
   if not piece.has("bone"):piece.bone=group.hip if ModelBuilder._vec(piece.get("pos",[0,0,0])).y>=knee.y else group.knee
 # Head details share a pivot, so eyes, horns and mouth stay attached when looking around.
 var head_box:=AABB()
 var head_seen=false
 for piece: Dictionary in pieces:
  if ModelBuilder._anatomy_group(piece)=="head":
   head_box=head_box.merge(ModelBuilder._piece_box(piece)) if head_seen else ModelBuilder._piece_box(piece);head_seen=true
 if head_seen:
  var at=Vector3(head_box.get_center().x,head_box.position.y,head_box.get_center().z)
  joints.head={"pivot":[at.x,at.y,at.z],"parent":"body"}
 for piece: Dictionary in pieces:
  if piece.has("bone"):continue
  var tag=String(piece.get("tag",""))
  var point=ModelBuilder._vec(piece.get("pos",[0,0,0]))
  var group=ModelBuilder._anatomy_group(piece)
  if group=="head" and head_seen:piece.bone="head"
  elif group=="legs" and not legs.is_empty():
   var nearest: Dictionary=legs[0]
   for leg: Dictionary in legs:
    if (leg.box as AABB).get_center().distance_to(point)<(nearest.box as AABB).get_center().distance_to(point):nearest=leg
   piece.bone=nearest.knee
  elif group=="wings" or tag=="arm":
   var side="l" if point.x<center.x else "r"
   var bone=("wing_" if group=="wings" else "arm_")+side
   if not joints.has(bone):
    var at=Vector3(center.x+(-1 if side=="l" else 1)*full.size.x*.12,point.y,point.z)
    joints[bone]={"pivot":[at.x,at.y,at.z],"parent":"body"}
   piece.bone=bone
  elif group=="tail":
   if not joints.has("tail_1"):joints.tail_1={"pivot":[center.x,point.y,center.z+full.size.z*.2],"parent":"body"}
   piece.bone="tail_1"
  else:piece.bone="body"
 return {"pieces":pieces,"rig":{"type":kind,"height_m":maxf(full.size.y,.1),"joints":joints,"lab_adapted":true}}
