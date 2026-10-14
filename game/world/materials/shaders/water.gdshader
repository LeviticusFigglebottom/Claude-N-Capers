// Night-harbour water (PO-13, ENV C). Library material: res://world/materials/water_harbour_night.tres
// (written by tools/texgen/build.py --only water_harbour_night; parameters in presets/gsr.py).
// Opaque, one draw, three samples of one 512 px ripple texture (RG normal, B slick mask), all in
// world XZ (mesh UVs unused, so any flat or boxed water mesh works and layers line up across meshes).
// No screen/depth texture and no SSR dependence: identical in Forward+ and Compatibility (opengl3).
// The look comes from the lighting: Godot's GGX specular + Schlick Fresnel turn the sodium lamps and
// the moon into rippled glints, and the sky/probe reflection brightens toward grazing angles. A small
// Fresnel "sheen" emission keeps the far water reading as fog-lit surface on maps with a dark sky.
// Lamp reflections: a lamp head is a small bright source whose true mirror image usually lands on
// the quay, not the water, and a spot light's cone rarely reaches it. So up to MAX_GLINTS map lights
// (glint_pos / glint_color, set by the map generator) are reflected analytically: the rippled
// reflection vector against each lamp, tight in azimuth and loose in elevation, gives the
// broken vertical streaks of lamps on night water. Fresnel-weighted; no screen-space data.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.1, 0.14, 0.13);
uniform vec3 sheen_color : source_color = vec3(0.27, 0.31, 0.31);
uniform float sheen : hint_range(0.0, 2.0) = 0.35;
uniform sampler2D ripple_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres of water per texture tile for ripple layer A (layer B is ripple_scale_b times finer).
uniform float tile_m = 8.0;
uniform float ripple_scale_b = 2.7;
uniform float slick_scale = 0.09;
// Drift in tiles per second (wind / tide); A and B cross, so the pattern never just slides.
uniform vec2 flow_a = vec2(0.012, 0.007);
uniform vec2 flow_b = vec2(-0.009, 0.013);
uniform vec2 flow_slick = vec2(0.002, -0.001);
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.45;
// Ripple amplitude left inside a glassy slick (0 = mirror flat, 1 = no slicks).
uniform float slick_calm : hint_range(0.0, 1.0) = 0.25;
// Ripples flatten with distance (stops far sparkle / aliasing; the fog takes over there).
uniform float far_fade_m = 70.0;
uniform float roughness_calm : hint_range(0.0, 1.0) = 0.04;
uniform float roughness_rippled : hint_range(0.0, 1.0) = 0.12;
uniform float specular_f0 : hint_range(0.0, 1.0) = 0.5;
// Optional darkening toward a quay wall: world plane (xyz = unit normal pointing into the water,
// w = offset; distance = dot(n, p) + w). shore_fade_m <= 0 disables it.
uniform vec4 shore_plane = vec4(0.0, 0.0, 1.0, 0.0);
uniform float shore_fade_m = 0.0;
uniform float shore_darken : hint_range(0.0, 1.0) = 0.5;
// Reflected lamps (world positions of the lamp heads; colour = linear colour x brightness).
const int MAX_GLINTS = 16;
uniform int glint_count = 0;
uniform vec3 glint_pos[MAX_GLINTS];
uniform vec3 glint_color[MAX_GLINTS];
uniform float glint_strength = 1.0;
// Azimuth tightness (cosine power) and elevation spread (radians) of a streak.
uniform float glint_sharpness = 1500.0;
uniform float glint_spread = 0.35;
// Haze between a glint source and the water (per metre): far-shore lights in the fog stay faint.
uniform float glint_fog = 0.0;

varying vec3 v_world;
varying vec3 v_world_n;


void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


vec2 slope(vec4 t) {
	return t.rg * 2.0 - 1.0;
}


void fragment() {
	vec2 p = v_world.xz / tile_m;
	vec4 a = texture(ripple_tex, p + flow_a * TIME);
	// Layer B: finer, rotated ~37 deg so the two tilings never line up.
	vec2 pb = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * ripple_scale_b;
	vec4 b = texture(ripple_tex, pb + flow_b * TIME);
	vec4 s = texture(ripple_tex, p * slick_scale + flow_slick * TIME);
	float rippled = mix(slick_calm, 1.0, s.b);
	vec3 to_cam = CAMERA_POSITION_WORLD - v_world;
	float dist = length(to_cam);
	vec3 v_dir = to_cam / dist;
	float fade = 1.0 - smoothstep(far_fade_m * 0.35, far_fade_m, dist);
	// A long low swell from the slick sample's own slope, kept even where the ripples fade.
	vec2 d = (slope(a) * 0.6 + slope(b) * 0.4) * ripple_strength * rippled * fade + slope(s) * 0.08;
	vec3 n_world = normalize(vec3(d.x, 1.0, d.y));
	// Only up-facing faces ripple (a boxed water mesh keeps flat sides).
	n_world = normalize(mix(v_world_n, n_world, smoothstep(0.6, 0.9, v_world_n.y)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float shore = 1.0;
	if (shore_fade_m > 0.0) {
		float sd = dot(shore_plane.xyz, v_world) + shore_plane.w;
		shore = mix(1.0 - shore_darken, 1.0, smoothstep(0.0, shore_fade_m, sd));
	}
	// Faint body variation: rippled patches scatter a touch more than the glassy slicks.
	ALBEDO = deep_color * (0.85 + 0.3 * s.b) * shore;
	METALLIC = 0.0;
	SPECULAR = specular_f0;
	ROUGHNESS = mix(roughness_calm, roughness_rippled, rippled * fade) + (1.0 - fade) * 0.06;
	float fres = pow(1.0 - clamp(dot(n_world, v_dir), 0.0, 1.0), 5.0);
	vec3 emit = sheen_color * sheen * fres * shore;
	vec3 r = reflect(-v_dir, n_world);
	float f_glint = 0.02 + 0.98 * fres;
	vec2 rh = normalize(r.xz + vec2(1e-5));
	// Below this azimuth cosine a streak is < e^-12 of its peak: skip the exp (cheap early-out).
	float c_min = exp(-12.0 / glint_sharpness);
	for (int i = 0; i < min(glint_count, MAX_GLINTS); i++) {
		vec3 l = glint_pos[i] - v_world;
		float c = dot(rh, l.xz) / max(length(l.xz), 1e-4);
		if (c > c_min) {
			float ll = length(l);
			float de = (r.y - l.y / ll) / glint_spread;
			// cos^sharpness * gaussian(elevation) * haze, as one exp.
			float e = glint_sharpness * log(c) - de * de - ll * glint_fog;
			emit += glint_color[i] * (exp(e) * f_glint * glint_strength);
		}
	}
	EMISSION = emit;
}
