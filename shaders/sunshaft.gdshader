shader_type spatial;
render_mode unshaded, blend_add, shadows_disabled, depth_draw_never, cull_disabled;
uniform float strength = 0.;
void fragment() {
	float strip = pow(max(0.,sin(UV.x*3.14159)),2.0);
	float ends = smoothstep(0.,.22,UV.y)*(1.-smoothstep(.52,1.,UV.y));
	ALBEDO = vec3(1.,.76,.38);
	ALPHA = strength*strip*ends;
}
