shader_type spatial;
render_mode world_vertex_coords,diffuse_burley,specular_disabled;
uniform float air=0.08;
varying vec3 tint;
void vertex(){
	tint=COLOR.rgb;
	float gust=sin(dot(VERTEX.xz,vec2(.53,.25))-TIME*1.9);
	VERTEX.xz+=vec2(.39,.14)*gust*pow(max(0.,VERTEX.y),1.45)*air;
}
void fragment(){
	ALBEDO=tint;
	ROUGHNESS=.94;
}
