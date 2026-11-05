extends SceneTree
# Render real nested Artwork slots at one overlap point. Verify actual pixels,
# including mirrored actors and a nonzero actor Z, instead of only reading Z values.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("verify")
func verify() -> void:
 var rig = load("res://scenes/rig.tscn").instantiate()
 root.add_child(rig)
 await physics_frame
 var sprites = rig.find_children("Artwork", "Sprite2D", true, false)
 check(sprites.size() == 20, "20 independently replaceable Artwork slots")
 check(rig.find_children("*", "Bone2D", true, false).size() == 22, "22 joints preserved")
 var groups: Array = [[],[],[],[],[],[],[],[]]
 for sprite in sprites:
  var path := str(rig.get_path_to(sprite))
  var layer := 4
  if "/BackShoulder/" in path: layer = 0
  elif "/BackThigh/" in path: layer = 1
  elif "/Ponytail/" in path: layer = 2
  elif "/FrontThigh/" in path: layer = 3
  elif "/FrontShoulder/" in path: layer = 7
  elif "/Hat/" in path: layer = 6
  elif "/Head/" in path: layer = 5
  groups[layer].append(sprite)
  check(sprite.texture != null, path + " replaceable texture")
 var colors: Array[Color] = []
 for layer in 8:
  var color := Color.from_hsv(float(layer)/8.0, 0.8, 0.9)
  colors.append(color)
  var image := Image.create(12,12,false,Image.FORMAT_RGBA8)
  image.fill(color)
  for sprite in groups[layer]: sprite.texture = ImageTexture.create_from_image(image)
 for facing in [1.0,-1.0]:
  for actor_z in [0,20]:
   rig.scale.x = facing
   rig.z_index = actor_z
   for sprite in sprites:
    sprite.show()
    sprite.global_transform = Transform2D(0,Vector2(40,40))
   for layer in range(7,-1,-1):
    await physics_frame
    RenderingServer.force_draw(false,1.0/60)
    var pixel: Color = root.get_texture().get_image().get_pixel(40,40)
    var delta := Vector3(pixel.r-colors[layer].r,pixel.g-colors[layer].g,pixel.b-colors[layer].b).length()
    check(delta < 0.03, "visible layer %s facing %s actor Z %s" % [layer,facing,actor_z])
    for sprite in groups[layer]: sprite.hide()
 print("RENDER ORDER TESTS: %s (%s checks)" % ["PASS" if failures == 0 else "FAIL", checks])
 quit(0 if failures == 0 else 1)
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
