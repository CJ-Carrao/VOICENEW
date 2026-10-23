shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 eye_color : source_color = vec3(0.85,0.93,0.98);
uniform vec3 background_color : source_color = vec3(0.035,0.075,0.115);
uniform float brightness = 1.0;
uniform float separation = 1.0;
uniform vec2 gaze = vec2(0.0);
// xy=center, zw=size. L is anatomical -X = UV.x < .5.
uniform vec4 rect_L = vec4(.235,.5,.147,.49);
uniform vec4 rect_R = vec4(.765,.5,.147,.49);
// x=rounding UV, y=rotation radians, z=arc blend, w=openness.
uniform vec4 shape_L = vec4(.012,0,0,1);
uniform vec4 shape_R = vec4(.012,0,0,1);
uniform vec3 top_L = vec3(1,0,0);
uniform vec3 top_R = vec3(1,0,0);
uniform vec3 bottom_L = vec3(0);
uniform vec3 bottom_R = vec3(0);
float eye_mask(vec2 uv, vec4 rect, vec4 shape, vec3 top, vec3 bottom) {
 vec2 center = vec2(.5+(rect.x-.5)*separation,rect.y)+gaze;
 vec2 p=uv-center;
 float cs=cos(shape.y); float sn=sin(shape.y);
 p=mat2(vec2(cs,-sn),vec2(sn,cs))*p;
 vec2 size=max(vec2(.001),vec2(rect.z,rect.w*max(.002,shape.w)));
 float radius=min(shape.x,min(size.x,size.y)*.48);
 vec2 q=abs(p)-size*.5+radius;
 float d=length(max(q,vec2(0)))+min(max(q.x,q.y),0.0)-radius;
 float aa=max(fwidth(d),.0008);
 float mask=1.0-smoothstep(-aa,aa,d);
 vec2 n=p/size;
 float upper=.5-(1.0-top.x)+top.y*n.x+top.z*n.x*n.x;
 float lower=-.5+bottom.x+bottom.y*n.x+bottom.z*n.x*n.x;
 float lid_aa=max(fwidth(n.y),.002);
 mask*=1.0-smoothstep(upper-lid_aa,upper+lid_aa,n.y);
 mask*=smoothstep(lower-lid_aa,lower+lid_aa,n.y);
 float arc=abs(n.y-(.20-2.0*n.x*n.x))-.085;
 float am=(1.0-smoothstep(-lid_aa,lid_aa,arc))*(1.0-smoothstep(.46,.50,abs(n.x)));
 return mix(mask,am,shape.z);
}
void fragment() {
 vec2 screen_uv=vec2(UV.x,1.0-UV.y); // glTF UV V grows downward; authored face Y grows upward.
 float m=max(eye_mask(screen_uv,rect_L,shape_L,top_L,bottom_L),eye_mask(screen_uv,rect_R,shape_R,top_R,bottom_R));
 ALBEDO=mix(background_color,eye_color*brightness,m);
 ROUGHNESS=1.0;
}
