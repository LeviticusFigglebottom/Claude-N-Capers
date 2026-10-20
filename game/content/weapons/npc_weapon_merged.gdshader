// NPC third-person merged weapons (NpcWeaponBake): one surface per gun, every part's look baked per vertex.
// COLOR.rgb = linear albedo, UV2 = (metallic, roughness). One shared material, so every NPC gun draws the same way.
// Owner: ENV B.
shader_type spatial;

void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = UV2.x;
	ROUGHNESS = UV2.y;
}
