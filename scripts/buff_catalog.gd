extends RefCounted
## Gate buffs for Dead Frontier (auto-running zombie survival). Every buff here has a real effect
## in player_3d.gd / main_3d.gd; there is no dodge, roll or sprint because the game has none.
##
## values: [common, rare, epic, legendary]. min: lowest rarity it may roll at.
## unit: how the value reads on the gate ("%" percent, "" flat, "/s" per second, "m" metres).

const BUFFS:={
	# --- survival ---
	"max_hp":      {"values":[15,30,50,80],   "unit":"",   "min":0, "group":"survival"}, # +max HP (and heals that much)
	"heal":        {"values":[15,30,55,100],  "unit":"",   "min":0, "group":"survival"}, # instant heal
	"regen":       {"values":[1,2,3,5],       "unit":"/s", "min":0, "group":"survival"}, # HP per second
	"kill_heal":   {"values":[1,2,4,8],       "unit":"",   "min":0, "group":"survival"}, # HP per kill
	"dmg_reduce":  {"values":[4,8,12,20],     "unit":"%",  "min":0, "group":"survival"}, # damage taken -x% (cap 60%)
	"shield":      {"values":[20,40,70,120],  "unit":"",   "min":0, "group":"survival"}, # absorbs damage before HP
	"move":        {"values":[4,8,12,20],     "unit":"%",  "min":0, "group":"survival"}, # run + side-step speed (cap +40%)
	# --- gun ---
	"damage":      {"values":[8,16,28,50],    "unit":"%",  "min":0, "group":"gun"},
	"rate":        {"values":[6,12,20,35],    "unit":"%",  "min":0, "group":"gun"},
	"bullet_speed":{"values":[10,20,35,60],   "unit":"%",  "min":0, "group":"gun"},
	"crit_chance": {"values":[5,10,15,25],    "unit":"%",  "min":0, "group":"gun"},   # cap 60%
	"crit_damage": {"values":[20,40,70,120],  "unit":"%",  "min":0, "group":"gun"},   # only once crit chance > 0
	"magazine":    {"values":[15,30,50,100],  "unit":"%",  "min":0, "group":"gun"},
	"reserve":     {"values":[1,2,4,8],       "unit":"",   "min":0, "group":"gun"},   # spare magazines; only with a non-pistol gun
	"reload":      {"values":[8,15,25,40],    "unit":"%",  "min":0, "group":"gun"},   # faster reload (cap 70%)
	"pierce":      {"values":[1,1,1,2],       "unit":"",   "min":1, "group":"gun"},
	"multishot":   {"values":[1,1,1,2],       "unit":"",   "min":2, "group":"gun"},   # more bullets per shot
	"split":       {"values":[1,1,2,3],       "unit":"",   "min":1, "group":"gun"},   # a hit bursts into fragments
	# --- on-hit effects ---
	"explode":     {"values":[8,15,25,40],    "unit":"%",  "min":1, "group":"effect"}, # chance of a small blast
	"burn":        {"values":[4,8,14,24],     "unit":"/s", "min":0, "group":"effect"}, # hits set zombies on fire (2.5 s)
	"poison":      {"values":[3,6,10,18],     "unit":"/s", "min":0, "group":"effect"}, # hits poison (5 s)
	"shock":       {"values":[10,18,28,45],   "unit":"%",  "min":1, "group":"effect"}, # chance to arc to nearby zombies
	# --- loot ---
	"coins":       {"values":[10,20,35,60],   "unit":"%",  "min":0, "group":"loot"},   # kill coins multiplier
	"drop":        {"values":[3,6,10,16],     "unit":"%",  "min":0, "group":"loot"},   # chance a kill drops a pickup
	"ammo_return": {"values":[8,15,25,40],    "unit":"%",  "min":0, "group":"loot"},   # chance a hit refunds the round
	"pickup_range":{"values":[1,2,3,4],       "unit":"m",  "min":0, "group":"loot"},   # x0.5 m extra reach
}

## Name | stat word. The number is appended from the rolled value.
const TEXT:={
	"en":{
		"max_hp":"TOUGH SKIN|MAX HP","heal":"FIELD MEDIC|HP","regen":"ADRENALINE|REGEN","kill_heal":"BLOODLUST|HP PER KILL",
		"dmg_reduce":"HARDENED|DAMAGE TAKEN","shield":"RIOT SHIELD|SHIELD","move":"LIGHT FEET|SPEED",
		"damage":"HEAVY ROUNDS|DAMAGE","rate":"FAST TRIGGER|FIRE RATE","bullet_speed":"HOT LOADS|BULLET SPEED",
		"crit_chance":"MARKSMAN|CRIT CHANCE","crit_damage":"HOLLOW POINT|CRIT DAMAGE","magazine":"EXTENDED MAG|MAGAZINE",
		"reserve":"AMMO CACHE|MAGAZINES","reload":"SPEED LOADER|RELOAD","pierce":"AP ROUNDS|PIERCE",
		"multishot":"TWIN BARREL|BULLETS","split":"FRAG ROUNDS|FRAGMENTS","explode":"HE ROUNDS|BLAST CHANCE",
		"burn":"INCENDIARY|BURN","poison":"TOXIN|POISON","shock":"TESLA COIL|SHOCK CHANCE",
		"coins":"SCAVENGER|COINS","drop":"LUCKY FIND|DROP CHANCE","ammo_return":"RECYCLER|AMMO BACK","pickup_range":"MAGNET|PICKUP RANGE"},
	"zh_CN":{
		"max_hp":"强韧体魄|生命上限","heal":"战地医疗|生命","regen":"肾上腺素|回血","kill_heal":"嗜血|击杀回血",
		"dmg_reduce":"硬化皮肤|受伤","shield":"防暴护盾|护盾","move":"轻装上阵|移速",
		"damage":"重型弹药|伤害","rate":"快速扳机|射速","bullet_speed":"高压弹药|弹速",
		"crit_chance":"神射手|暴击率","crit_damage":"空尖弹|暴击伤害","magazine":"扩容弹匣|弹匣",
		"reserve":"弹药补给|备用弹匣","reload":"快速装填|换弹","pierce":"穿甲弹|穿透",
		"multishot":"双联枪管|弹丸","split":"破片弹|分裂","explode":"高爆弹|爆炸几率",
		"burn":"燃烧弹|灼烧","poison":"毒素弹|中毒","shock":"特斯拉线圈|电击几率",
		"coins":"拾荒者|金币","drop":"好运连连|掉落几率","ammo_return":"弹药回收|回收几率","pickup_range":"磁吸|拾取范围"},
	"zh_TW":{
		"max_hp":"強韌體魄|生命上限","heal":"戰地醫療|生命","regen":"腎上腺素|回血","kill_heal":"嗜血|擊殺回血",
		"dmg_reduce":"硬化皮膚|受傷","shield":"防暴護盾|護盾","move":"輕裝上陣|移速",
		"damage":"重型彈藥|傷害","rate":"快速扳機|射速","bullet_speed":"高壓彈藥|彈速",
		"crit_chance":"神射手|暴擊率","crit_damage":"空尖彈|暴擊傷害","magazine":"擴容彈匣|彈匣",
		"reserve":"彈藥補給|備用彈匣","reload":"快速裝填|換彈","pierce":"穿甲彈|穿透",
		"multishot":"雙聯槍管|彈丸","split":"破片彈|分裂","explode":"高爆彈|爆炸機率",
		"burn":"燃燒彈|灼燒","poison":"毒素彈|中毒","shock":"特斯拉線圈|電擊機率",
		"coins":"拾荒者|金幣","drop":"好運連連|掉落機率","ammo_return":"彈藥回收|回收機率","pickup_range":"磁吸|拾取範圍"},
	"ja":{
		"max_hp":"強靭な体|最大HP","heal":"応急手当|HP","regen":"アドレナリン|再生","kill_heal":"血の渇き|撃破回復",
		"dmg_reduce":"硬化|被ダメージ","shield":"ライオットシールド|シールド","move":"軽装|移動速度",
		"damage":"重型弾薬|ダメージ","rate":"高速トリガー|射速","bullet_speed":"強装弾|弾速",
		"crit_chance":"名射手|会心率","crit_damage":"ホローポイント|会心ダメージ","magazine":"拡張マガジン|マガジン",
		"reserve":"弾薬補給|予備マガジン","reload":"スピードローダー|リロード","pierce":"徹甲弾|貫通",
		"multishot":"ツインバレル|弾数","split":"破片弾|分裂","explode":"榴弾|爆発率",
		"burn":"焼夷弾|炎上","poison":"毒弾|毒","shock":"テスラコイル|電撃率",
		"coins":"スカベンジャー|コイン","drop":"幸運|ドロップ率","ammo_return":"リサイクル|弾回収率","pickup_range":"マグネット|回収範囲"},
	"ko":{
		"max_hp":"강인한 체력|최대 체력","heal":"야전 의료|체력","regen":"아드레날린|재생","kill_heal":"피의 갈증|처치 회복",
		"dmg_reduce":"경화 피부|받는 피해","shield":"진압 방패|보호막","move":"경량 장비|이동 속도",
		"damage":"중형 탄약|피해","rate":"속사 방아쇠|발사 속도","bullet_speed":"고압탄|탄속",
		"crit_chance":"명사수|치명타 확률","crit_damage":"할로포인트|치명타 피해","magazine":"확장 탄창|탄창",
		"reserve":"탄약 보급|예비 탄창","reload":"스피드 로더|재장전","pierce":"철갑탄|관통",
		"multishot":"쌍열 총신|탄환","split":"파편탄|분열","explode":"고폭탄|폭발 확률",
		"burn":"소이탄|화상","poison":"독탄|중독","shock":"테슬라 코일|감전 확률",
		"coins":"수집가|코인","drop":"행운|드롭 확률","ammo_return":"탄약 회수|회수 확률","pickup_range":"자석|획득 범위"},
}

static func value_of(id: String,rarity: int) -> float:
	return float(BUFFS[id].values[clampi(rarity,0,3)])

## Display value: "+28%", "+2/s", "-12%" for damage taken, "+1.5m" for range.
static func value_text(id: String,value: float,code:="en") -> String:
	var unit: String=BUFFS[id].unit
	if id=="pickup_range": return "+%sm"%String.num(value*0.5,1).trim_suffix(".0")
	if id=="dmg_reduce": return "-%d%%"%int(value)
	if id in ["burn","poison"]: return "+%d%s"%[int(value),"/秒" if code.begins_with("zh") else "/s"]
	if unit=="/s": return "+%d%s"%[int(value),"/秒" if code.begins_with("zh") else "/s"]
	return "+%d%s"%[int(value),unit]

## [title, "stat +value"] in the player's language (English for languages without a table yet).
static func label(code: String,id: String,value: float) -> PackedStringArray:
	var table: Dictionary=TEXT.get(code,TEXT["en"])
	var parts:=String(table.get(id,TEXT["en"].get(id,id.to_upper()+"|"))).split("|")
	var stat: String=parts[1] if parts.size()>1 else ""
	return PackedStringArray([parts[0],stat+" "+value_text(id,value,code)])
