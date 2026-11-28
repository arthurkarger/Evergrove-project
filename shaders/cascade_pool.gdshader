shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment(){
	vec2 p=(UV-.5)*2.;
	float radius=length(p);
	float twist=sin(p.x*8.+TIME*2.)*.055+cos(p.y*11.-TIME*1.7)*.035;
	float rings=sin((radius+twist)*24.-TIME*5.);
	float coverage=(1.-smoothstep(.62,1.,radius))*(.38+.54*smoothstep(-.25,.65,rings));
	ALBEDO=mix(vec3(.48,.85,.82),vec3(.94,.99,.95),smoothstep(.15,.8,rings));
	ALPHA=coverage;
}
