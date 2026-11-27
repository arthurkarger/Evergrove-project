shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_enable;
uniform int quality = 2;
uniform float air=.08;
varying float height;
void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	height = smoothstep(0.65,2.7,VERTEX.y);
	if (quality > 0 || air>.4) {
		float gust = sin(dot(p.xz,vec2(.43,.21))-TIME*1.1);
		float flutter = sin(p.x*2.8+TIME*2.4)*.014;
		VERTEX.xz += vec2(.073,.030)*gust*height*(1.+air*2.9) + vec2(flutter,0.)*height;
	}
}
void fragment() {
	vec3 leaves = texture(paint,UV).rgb;
	ALBEDO = leaves*mix(vec3(.76,.88,.69),vec3(1.18,1.15,.83),height);
	BACKLIGHT = ALBEDO * (0.12+0.24*height);
	AO = mix(.75,1.,height);
	ROUGHNESS = .92;
}
