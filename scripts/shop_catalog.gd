extends RefCounted

const WEAPON_BONUS_PER_LEVEL:=0.12

# Permanent upgrades purchased only with earned coins. Real-money IAP stays separate.
# Every item belongs to one piece of gear in the supply truck; the shop camera zooms to it.
static func items() -> Array:
	return [
		{"id":"medical","title":"BODY ARMOR","detail":"+15 MAX HP EACH RUN","cost":40,"max_level":5,"enabled":true,"name_key":"n_armor","detail_key":"d_hp"},
		{"id":"ammo","title":"AMMO CASE","detail":"+30 RESERVE AMMO EACH RUN","cost":30,"max_level":5,"enabled":true,"name_key":"n_ammo","detail_key":"d_ammo"},
		{"id":"w_pistol","title":"PISTOL","detail":"+12% PISTOL DAMAGE","cost":30,"max_level":5,"enabled":true,"name_key":"n_pistol","detail_key":"d_dmg","weapon":"PISTOL"},
		{"id":"w_smg","title":"SMG","detail":"+12% SMG DAMAGE","cost":45,"max_level":5,"enabled":true,"name_key":"n_smg","detail_key":"d_dmg","weapon":"SMG"},
		{"id":"w_shotgun","title":"SHOTGUN","detail":"+12% SHOTGUN DAMAGE","cost":50,"max_level":5,"enabled":true,"name_key":"n_shotgun","detail_key":"d_dmg","weapon":"SHOTGUN"},
		{"id":"w_rifle","title":"ASSAULT RIFLE","detail":"+12% RIFLE DAMAGE","cost":50,"max_level":5,"enabled":true,"name_key":"n_rifle","detail_key":"d_dmg","weapon":"RIFLE"},
		{"id":"w_sniper","title":"SNIPER RIFLE","detail":"+12% SNIPER DAMAGE","cost":60,"max_level":5,"enabled":true,"name_key":"n_sniper","detail_key":"d_dmg","weapon":"SNIPER"},
		{"id":"w_launcher","title":"GRENADE LAUNCHER","detail":"+12% BLAST DAMAGE","cost":70,"max_level":5,"enabled":true,"name_key":"n_launcher","detail_key":"d_dmg","weapon":"LAUNCHER"}
	]

static func default_levels() -> Dictionary:
	# "damage" is the retired global upgrade; kept so old saves still apply it.
	var levels:={"damage":0}
	for item in items(): levels[item.id]=0
	return levels

# Reserved for later App Store products; no billing or price is simulated here.
static func premium_items() -> Array:
	return []
