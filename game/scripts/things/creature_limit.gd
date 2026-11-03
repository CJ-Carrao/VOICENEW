class_name CreatureLimit
extends RefCounted

static func cap() -> int:
 return maxi(1,int(Lexicon.bal("caps.live_creatures_per_player",30)))

static func family(body: Thing) -> Array:
 var result: Array=[]
 var pending: Array=[body]
 var seen: Dictionary={}
 while not pending.is_empty():
  var item=pending.pop_back()
  if not is_instance_valid(item) or item.is_dead or seen.has(item):continue
  seen[item]=true;result.append(item)
  pending.append_array(item.grafts)
  var ball=item.get_node_or_null("CaptureBall")
  if ball!=null and ball.occupant()!=null:pending.append(ball.occupant())
 return result

static func count(owner_id: int) -> int:
 var found: Dictionary={}
 var candidates: Array=Forge.live_things(owner_id).duplicate()
 if Forge.world!=null:
  candidates.append_array(Forge.world.get_node("Things").get_children())
 for body in candidates:
  if not body is Thing:continue
  for item in family(body):
   if item.category!="creature":continue
   var temporary=item.get_node_or_null("CreativeEffects")
   if item.owner_id==owner_id or (temporary!=null and temporary.team_time>0.0 and temporary.old_owner==owner_id):found[item]=true
 return found.size()

static func slots(node: Dictionary, grouped: bool=false, depth: int=0, budget: Dictionary={}) -> int:
 if budget.is_empty():budget={"left":int(Lexicon.bal("caps.grafts_per_recipe",16))}
 var total=1 if Lexicon.data.category_of(String(node.get("thing","")))=="creature" else 0
 if depth<int(Lexicon.bal("caps.graft_depth",4)):
  for graft in node.get("mods",{}).get("grafts",[]):
   if budget.left<=0:break
   budget.left-=1
   total+=slots(graft.get("node",{}),false,depth+1,budget)
 if grouped and Lexicon.data.placement_for(String(node.get("thing",""))) in ["front","aim_ground","flyover"]:
  total*=maxi(1,int(node.get("mods",{}).get("count",1)))
 return total

static func allows(owner_id: int, node: Dictionary, grouped: bool=false) -> bool:
 var needed=slots(node,grouped)
 return needed==0 or count(owner_id)+needed<=cap()

static func can_transfer(body: Thing, owner_id: int) -> bool:
 var extra=0
 for item in family(body):
  if item.category=="creature" and item.owner_id!=owner_id:extra+=1
 return extra==0 or count(owner_id)+extra<=cap()

static func warning() -> String:
 return "Limite de %d animais por jogador atingido. Remova um animal para criar outro." % cap()
