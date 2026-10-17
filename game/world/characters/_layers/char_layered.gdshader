// D-132 D1: the plain character material (ORMMaterial3D) for merged surfaces. Owner: ENV D.
// Layers: world/characters/_tools/char_layers.gd, build_char_layers.gd. Mirrors what BaseMaterial3D generates for
// those materials (burley diffuse, schlick-ggx specular, ORM: AO = r, roughness = g, metallic = b, normal map from RG
// with Z rebuilt by the renderer, skin SSS), reading the material's layer from UV2.x and its SSS strength from UV2.y
// (char_layers.gd encode_uv2). SPECULAR stays at its default 0.5: ORMMaterial3D does not apply metallic_specular
// (measured, Compatibility and Forward+: 0.35 / 0.5 / 1.0 render the same), so neither do we.
// Decals, fog and shadows stay on (the defaults).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

uniform sampler2DArray texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray texture_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray texture_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
	vec3 uvl = vec3(UV, round(UV2.x));
	ALBEDO = texture(texture_albedo, uvl).rgb;
	vec3 orm = texture(texture_orm, uvl).rgb;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	SSS_STRENGTH = clamp((UV2.y - 0.25) * 2.0, 0.0, 1.0);
	NORMAL_MAP = texture(texture_normal, uvl).rgb;
	NORMAL_MAP_DEPTH = 1.0;
}
