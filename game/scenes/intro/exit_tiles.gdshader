shader_type canvas_item;
render_mode unshaded;
varying vec4 region;
varying vec4 tint;
void vertex() { region = INSTANCE_CUSTOM; tint = COLOR; }
void fragment() { COLOR = texture(TEXTURE, region.xy + vec2(UV.x, 1.0 - UV.y) * region.zw) * tint; }
