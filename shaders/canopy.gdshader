shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_enable;
uniform int quality = 2;
varying float height;
void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	height = smoothstep(0.65,2.7,VERTEX.y);
	if (quality > 0) {
		float gust = sin(dot(p.xz,vec2(.43,.21))-TIME*1.1);
		float flutter = sin(p.x*2.8+TIME*2.4)*.014;
		VERTEX.xz += vec2(.083,.035)*gust*height + vec2(flutter,0.)*height;
	}
}
void fragment() {
	vec3 leaves = texture(paint,UV).rgb;
	ALBEDO = leaves*mix(vec3(.84,.89,.81),vec3(1.07,1.05,.99),height);
	AO = mix(.75,1.,height);
	ROUGHNESS = .92;
}
