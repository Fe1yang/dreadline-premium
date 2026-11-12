extends RefCounted
## Gate buffs for Dead Frontier (auto-running zombie survival). Every buff here has a real effect
## in player_3d.gd / main_3d.gd; there is no dodge, roll or sprint because the game has none.
##
## values: [common, rare, epic, legendary]. min: lowest rarity it may roll at.
## Steps you can feel (about +8% for a common damage / fire-rate gate) but no runaway: a run grows
## at every gate, and
## the strongest effects (pierce, extra bullets, fragments) are rare and capped in player_3d.gd.
## unit: how the value reads on the gate ("%" percent, "" flat, "/s" per second, "m" metres).

const BUFFS:={
	# --- survival ---
	"max_hp":      {"values":[2,3,5,8],      "unit":"",   "min":0, "group":"survival"}, # +max HP (and heals that much)
	"heal":        {"values":[6,10,16,26],   "unit":"",   "min":0, "group":"survival"}, # instant heal
	"regen":       {"values":[0.2,0.35,0.5,0.8],"unit":"/s", "min":0, "group":"survival"}, # HP per second
	"kill_heal":   {"values":[0.2,0.35,0.5,0.8],"unit":"", "min":0, "group":"survival"}, # HP per kill
	"dmg_reduce":  {"values":[1,2,3,5],      "unit":"%",  "min":0, "group":"survival"}, # damage taken -x% (cap 60%)
	"shield":      {"values":[6,10,16,26],   "unit":"",   "min":0, "group":"survival"}, # absorbs damage before HP
	"move":        {"values":[4,6,9,12],     "unit":"%",  "min":0, "group":"survival"}, # run + side-step speed (cap +40%)
	# --- gun ---
	"damage":      {"values":[8,12,18,25],    "unit":"%",  "min":0, "group":"gun"},
	"rate":        {"values":[6,9,13,18],    "unit":"%",  "min":0, "group":"gun"},
	"bullet_speed":{"values":[8,15,22,35],   "unit":"%",  "min":0, "group":"gun"},
	"range":       {"values":[10,15,22,35],   "unit":"%",  "min":0, "group":"gun"},   # bullet reach (cap +180%)
	"strafe":      {"values":[5,8,12,18],    "unit":"%",  "min":0, "group":"survival"}, # side-step only (cap +60%)
	"crit_chance": {"values":[2,4,6,10],       "unit":"%",  "min":0, "group":"gun"},   # common 1%, cap 100%
	"crit_damage": {"values":[10,15,25,40],    "unit":"%",  "min":0, "group":"gun"},   # only once crit chance > 0
	"magazine":    {"values":[15,25,40,60],  "unit":"%",  "min":0, "group":"gun"},
	"reserve":     {"values":[1,1,2,3],       "unit":"",   "min":0, "group":"gun"},   # spare magazines; only with a non-pistol gun
	"reload":      {"values":[8,12,18,25],    "unit":"%",  "min":0, "group":"gun"},   # faster reload (cap 70%)
	"pierce":      {"values":[1,1,1,1],       "unit":"",   "min":2, "group":"gun"},
	"multishot":   {"values":[1,1,1,1],       "unit":"",   "min":3, "group":"gun"},   # more bullets per shot
	"split":       {"values":[1,1,1,2],       "unit":"",   "min":1, "group":"gun"},   # a hit bursts into fragments
	# --- on-hit effects ---
	"explode":     {"values":[6,10,15,22],    "unit":"%",  "min":2, "group":"effect"}, # chance of a small blast
	"burn":        {"values":[3,5,8,12],     "unit":"/s", "min":0, "group":"effect"}, # hits set zombies on fire (2.5 s)
	"poison":      {"values":[2,4,6,9],     "unit":"/s", "min":0, "group":"effect"}, # hits poison (5 s)
	"shock":       {"values":[8,12,18,25],   "unit":"%",  "min":2, "group":"effect"}, # chance to arc to nearby zombies
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
		"damage":"HEAVY ROUNDS|DAMAGE","rate":"FAST TRIGGER|FIRE RATE","bullet_speed":"HOT LOADS|BULLET SPEED","range":"LONG BARREL|RANGE","strafe":"QUICK FEET|SIDE STEP",
		"crit_chance":"MARKSMAN|CRIT CHANCE","crit_damage":"HOLLOW POINT|CRIT DAMAGE","magazine":"EXTENDED MAG|MAGAZINE",
		"reserve":"AMMO CACHE|MAGAZINES","reload":"SPEED LOADER|RELOAD","pierce":"AP ROUNDS|PIERCE",
		"multishot":"TWIN BARREL|BULLETS","split":"FRAG ROUNDS|FRAGMENTS","explode":"HE ROUNDS|BLAST CHANCE",
		"burn":"INCENDIARY|BURN","poison":"TOXIN|POISON","shock":"TESLA COIL|SHOCK CHANCE",
		"coins":"SCAVENGER|COINS","drop":"LUCKY FIND|DROP CHANCE","ammo_return":"RECYCLER|AMMO BACK","pickup_range":"MAGNET|PICKUP RANGE"},
	"zh_CN":{
		"max_hp":"强韧体魄|生命上限","heal":"战地医疗|生命","regen":"肾上腺素|回血","kill_heal":"嗜血|击杀回血",
		"dmg_reduce":"硬化皮肤|受伤","shield":"防暴护盾|护盾","move":"轻装上阵|移速",
		"damage":"重型弹药|伤害","rate":"快速扳机|射速","bullet_speed":"高压弹药|弹速","range":"长管|射程","strafe":"轻步|横移速度",
		"crit_chance":"神射手|暴击率","crit_damage":"空尖弹|暴击伤害","magazine":"扩容弹匣|弹匣",
		"reserve":"弹药补给|备用弹匣","reload":"快速装填|换弹","pierce":"穿甲弹|穿透",
		"multishot":"双联枪管|弹丸","split":"破片弹|分裂","explode":"高爆弹|爆炸几率",
		"burn":"燃烧弹|灼烧","poison":"毒素弹|中毒","shock":"特斯拉线圈|电击几率",
		"coins":"拾荒者|金币","drop":"好运连连|掉落几率","ammo_return":"弹药回收|回收几率","pickup_range":"磁吸|拾取范围"},
	"zh_TW":{
		"max_hp":"強韌體魄|生命上限","heal":"戰地醫療|生命","regen":"腎上腺素|回血","kill_heal":"嗜血|擊殺回血",
		"dmg_reduce":"硬化皮膚|受傷","shield":"防暴護盾|護盾","move":"輕裝上陣|移速",
		"damage":"重型彈藥|傷害","rate":"快速扳機|射速","bullet_speed":"高壓彈藥|彈速","range":"長管|射程","strafe":"輕步|橫移速度",
		"crit_chance":"神射手|暴擊率","crit_damage":"空尖彈|暴擊傷害","magazine":"擴容彈匣|彈匣",
		"reserve":"彈藥補給|備用彈匣","reload":"快速裝填|換彈","pierce":"穿甲彈|穿透",
		"multishot":"雙聯槍管|彈丸","split":"破片彈|分裂","explode":"高爆彈|爆炸機率",
		"burn":"燃燒彈|灼燒","poison":"毒素彈|中毒","shock":"特斯拉線圈|電擊機率",
		"coins":"拾荒者|金幣","drop":"好運連連|掉落機率","ammo_return":"彈藥回收|回收機率","pickup_range":"磁吸|拾取範圍"},
	"ja":{"range":"長銃身|射程","strafe":"軽業|横移動",
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
		"damage":"중형 탄약|피해","rate":"속사 방아쇠|발사 속도","bullet_speed":"고압탄|탄속","range":"긴 총열|사거리","strafe":"경보|측면 이동",
		"crit_chance":"명사수|치명타 확률","crit_damage":"할로포인트|치명타 피해","magazine":"확장 탄창|탄창",
		"reserve":"탄약 보급|예비 탄창","reload":"스피드 로더|재장전","pierce":"철갑탄|관통",
		"multishot":"쌍열 총신|탄환","split":"파편탄|분열","explode":"고폭탄|폭발 확률",
		"burn":"소이탄|화상","poison":"독탄|중독","shock":"테슬라 코일|감전 확률",
		"coins":"수집가|코인","drop":"행운|드롭 확률","ammo_return":"탄약 회수|회수 확률","pickup_range":"자석|획득 범위"},
	"uk":{"max_hp":"ТОВСТА ШКІРА|МАКС HP","heal":"ФЕЛЬДШЕР|HP","regen":"АДРЕНАЛІН|РЕГЕН.","kill_heal":"СПРАГА КРОВІ|HP ЗА ВБИВСТВО","dmg_reduce":"ГАРТОВАНИЙ|ОТРИМАНА ШКОДА","shield":"ЩИТ|ЩИТ","move":"ЛЕГКІ НОГИ|ШВИДКІСТЬ","damage":"ВАЖКІ КУЛІ|ШКОДА","rate":"ШВИДКИЙ СПУСК|ШВИДКОСТРІЛ","bullet_speed":"ГАРЯЧИЙ ЗАРЯД|ШВИДКІСТЬ КУЛІ","range":"ДОВГИЙ СТВОЛ|ДАЛЬНІСТЬ","strafe":"ШВИДКИЙ КРОК|УБІК","crit_chance":"СНАЙПЕР|ШАНС КРИТА","crit_damage":"ЕКСПАНСИВНА|ШКОДА КРИТА","magazine":"ВЕЛИКИЙ МАГАЗИН|МАГАЗИН","reserve":"ЗАПАС ПАТРОНІВ|МАГАЗИНИ","reload":"ШВИДКА ПЕРЕЗАРЯДКА|ПЕРЕЗАРЯДКА","pierce":"БРОНЕБІЙНІ|ПРОБИТТЯ","multishot":"ДВА СТВОЛИ|КУЛІ","split":"ОСКОЛКОВІ|ОСКОЛКИ","explode":"РОЗРИВНІ|ШАНС ВИБУХУ","burn":"ЗАПАЛЮВАЛЬНІ|ОПІК","poison":"ОТРУТА|ОТРУТА","shock":"КОТУШКА ТЕСЛИ|ШАНС РОЗРЯДУ","coins":"МАРОДЕР|МОНЕТИ","drop":"ЩАСЛИВА ЗНАХІДКА|ШАНС ДРОПУ","ammo_return":"ПЕРЕРОБНИК|ПАТРОН НАЗАД","pickup_range":"МАГНІТ|РАДІУС ПІДБОРУ"},
	"vi":{"max_hp":"DA DÀY|HP TỐI ĐA","heal":"Y TÁ CHIẾN TRƯỜNG|HP","regen":"ADRENALINE|HỒI PHỤC","kill_heal":"KHÁT MÁU|HP MỖI MẠNG","dmg_reduce":"CHAI LÌ|SÁT THƯƠNG NHẬN","shield":"KHIÊN CHỐNG BẠO LOẠN|KHIÊN","move":"CHÂN NHẸ|TỐC ĐỘ","damage":"ĐẠN NẶNG|SÁT THƯƠNG","rate":"CÒ NHANH|TỐC ĐỘ BẮN","bullet_speed":"NẠP NÓNG|TỐC ĐỘ ĐẠN","range":"NÒNG DÀI|TẦM BẮN","strafe":"BƯỚC NHANH|BƯỚC NGANG","crit_chance":"XẠ THỦ|TỈ LỆ CHÍ MẠNG","crit_damage":"ĐẠN RỖNG|SÁT THƯƠNG CHÍ MẠNG","magazine":"BĂNG ĐẠN LỚN|BĂNG ĐẠN","reserve":"DỰ TRỮ ĐẠN|BĂNG ĐẠN","reload":"NẠP NHANH|NẠP ĐẠN","pierce":"ĐẠN XUYÊN|XUYÊN PHÁ","multishot":"HAI NÒNG|ĐẠN","split":"ĐẠN MẢNH|MẢNH","explode":"ĐẠN NỔ|TỈ LỆ NỔ","burn":"ĐẠN LỬA|CHÁY","poison":"ĐỘC TỐ|ĐỘC","shock":"CUỘN TESLA|TỈ LỆ GIẬT","coins":"KẺ VƠ VÉT|XU","drop":"PHÁT HIỆN MAY|TỈ LỆ RƠI","ammo_return":"TÁI CHẾ|HOÀN ĐẠN","pickup_range":"NAM CHÂM|TẦM NHẶT"},
	"th":{"max_hp":"หนังหนา|HP สูงสุด","heal":"หมอสนาม|HP","regen":"อะดรีนาลีน|ฟื้นฟู","kill_heal":"กระหายเลือด|HP ต่อการฆ่า","dmg_reduce":"แข็งแกร่ง|ความเสียหายที่รับ","shield":"โล่ป้องกัน|โล่","move":"เท้าเบา|ความเร็ว","damage":"กระสุนหนัก|ความเสียหาย","rate":"ไกเร็ว|อัตราการยิง","bullet_speed":"ดินปืนร้อน|ความเร็วกระสุน","range":"ลำกล้องยาว|ระยะยิง","strafe":"ก้าวเร็ว|ก้าวข้าง","crit_chance":"มือปืน|โอกาสคริติคอล","crit_damage":"หัวกระสุนกลวง|ความเสียหายคริติคอล","magazine":"แม็กใหญ่|แม็กกาซีน","reserve":"สำรองกระสุน|แม็กกาซีน","reload":"บรรจุเร็ว|บรรจุ","pierce":"กระสุนเจาะ|การเจาะ","multishot":"สองลำกล้อง|กระสุน","split":"กระสุนแตก|สะเก็ด","explode":"กระสุนระเบิด|โอกาสระเบิด","burn":"กระสุนเพลิง|การเผาไหม้","poison":"สารพิษ|พิษ","shock":"ขดลวดเทสลา|โอกาสช็อต","coins":"นักเก็บของ|เหรียญ","drop":"โชคดี|โอกาสดรอป","ammo_return":"รีไซเคิล|กระสุนคืน","pickup_range":"แม่เหล็ก|ระยะเก็บของ"},
	"pl":{"max_hp":"GRUBA SKÓRA|MAKS HP","heal":"SANITARIUSZ|HP","regen":"ADRENALINA|REGEN.","kill_heal":"ŻĄDZA KRWI|HP ZA ZABÓJSTWO","dmg_reduce":"ZAHARTOWANY|OTRZYMANE OBRAŻENIA","shield":"TARCZA|TARCZA","move":"LEKKIE NOGI|SZYBKOŚĆ","damage":"CIĘŻKIE POCISKI|OBRAŻENIA","rate":"SZYBKI SPUST|SZYBKOSTRZELNOŚĆ","bullet_speed":"GORĄCY ŁADUNEK|SZYBKOŚĆ POCISKU","range":"DŁUGA LUFĄ|ZASIĘG","strafe":"SZYBKI KROK|KROK W BOK","crit_chance":"STRZELEC|SZANSA NA KRYT","crit_damage":"POCISK DRĄŻONY|OBRAŻENIA KRYT.","magazine":"WIĘKSZY MAGAZYNEK|MAGAZYNEK","reserve":"ZAPAS AMUNICJI|MAGAZYNKI","reload":"SZYBKI ZAMEK|PRZEŁADOWANIE","pierce":"POCISKI PRZEB.|PRZEBICIE","multishot":"PODWÓJNA LUFĄ|POCISKI","split":"POCISKI ODLAMKOWE|ODŁAMKI","explode":"POCISKI WYBUCHOWE|SZANSA WYBUCHU","burn":"ZAPALAJĄCE|POPARZENIE","poison":"TOKSYNA|TRUCIZNA","shock":"CEWKA TESLI|SZANSA PORAŻENIA","coins":"SZABROWNIK|MONETY","drop":"SZCZĘŚLIWY ZNAŁAZ|SZANSA DROPU","ammo_return":"RECYKLER|AMUNICJA ZWROTNA","pickup_range":"MAGNES|ZASIĘG ZBIERANIA"},
	"nl":{"max_hp":"DIKKE HUID|MAX HP","heal":"VELDART|HP","regen":"ADRENALINE|REGEN","kill_heal":"BLOEDDORST|HP PER KILL","dmg_reduce":"GEHARD|ONTvangen SCHADE","shield":"RELschILD|SCHILD","move":"LICHTE VOETEN|SNELHEID","damage":"ZWARE KOGELS|SCHADE","rate":"SNELLE TREKKER|VUURSNELHEID","bullet_speed":"HEET SCHOT|KOGELSNELHEID","range":"LANG LOPEN|BEREIK","strafe":"SNELLE STAP|ZIJSTAP","crit_chance":"SCHUTTER|KRIT-KANS","crit_damage":"HOL PUNT|KRIT-SCHADE","magazine":"GROOT MAGAZIJN|MAGAZIJN","reserve":"MUNITIEVOORRAAD|MAGAZIJNEN","reload":"SNELLADER|HERLADEN","pierce":"PANTSERDOORBOREND|DOORBORING","multishot":"DUBBELE LOOP|KOGELS","split":"SPLINTERKOGELS|SPLINTERS","explode":"EXPLOSIEVE KOGELS|EXPLOSIEKANS","burn":"BRANDSTICHTEND|BRANDWOND","poison":"GIF|GIF","shock":"TESLA-SPOEL|SCHOKKANS","coins":"PLUNDERAAR|MUNTEN","drop":"GELUKSVONDST|DROPKANS","ammo_return":"RECYCLER|MUNITIE TERUG","pickup_range":"MAGNEET|OPRAAPBEREIK"},
	"tr":{"max_hp":"KALIN DERİ|MAKS HP","heal":"SAHRA SAĞLIKÇISI|HP","regen":"ADRENALİN|YENİLENME","kill_heal":"KAN SUSUZLUĞU|ÖLDÜRME BAŞINA HP","dmg_reduce":"SERTLEŞMİŞ|ALINAN HASAR","shield":"İSYAN KALKANI|KALKAN","move":"HAFİF AYAK|HIZ","damage":"AĞIR MERMİ|HASAR","rate":"HIZLI TETİK|ATIŞ HIZI","bullet_speed":"SICAK DOLU|MERMİ HIZI","range":"UZUN NAMLU|MENZİL","strafe":"HIZLI ADIM|YAN ADIM","crit_chance":"NİŞANCI|KRİTİK ŞANSI","crit_damage":"İÇİ BOŞ MERMİ|KRİTİK HASAR","magazine":"BÜYÜK ŞARJÖR|ŞARJÖR","reserve":"MERMİ YEDEĞİ|ŞARJÖRLER","reload":"HIZLI DOLDURMA|DOLDURMA","pierce":"DELİCİ MERMİ|DELME","multishot":"ÇİFT NAMLU|MERMİLER","split":"PARÇALI MERMİ|PARÇALAR","explode":"PATLAYICI MERMİ|PATLAMA ŞANSI","burn":"YAKICI|YANMA","poison":"TOKSİN|ZEHİR","shock":"TESLA BOBİNİ|ŞOK ŞANSI","coins":"YAĞMACI|JETON","drop":"ŞANSLI BULGU|DÜŞME ŞANSI","ammo_return":"GERİ DÖNÜŞÜM|MERMİ İADESİ","pickup_range":"MIKNATIS|TOPLAMA MENZİLİ"},
	"it":{"max_hp":"PELLE DURA|HP MAX","heal":"MEDICO DA CAMPO|HP","regen":"ADRENALINA|RIGENERAZIONE","kill_heal":"SETE DI SANGUE|HP PER UCCISIONE","dmg_reduce":"TEMPRATO|DANNI SUBITI","shield":"SCUDO ANTISOMMOSSA|SCUDO","move":"PIEDI LEGGERI|VELOCITÀ","damage":"MUNIZIONI PESANTI|DANNO","rate":"GRILETTO RAPIDO|CADENZA","bullet_speed":"CARICA CALDA|VELOCITÀ PROIETTILE","range":"CANNA LUNGA|PORTATA","strafe":"PASSO RAPIDO|PASSO LATERALE","crit_chance":"TIRATORE|PROB. CRITICO","crit_damage":"PUNTA CAVA|DANNO CRITICO","magazine":"CARICATORE ESTESO|CARICATORE","reserve":"RISERVA MUNIZIONI|CARICATORI","reload":"RICARICA RAPIDA|RICARICA","pierce":"PROIETTILI PERFORANTI|PERFORAZIONE","multishot":"DOPPIA CANNA|PROIETTILI","split":"PROIETTILI A FRAMMENTI|FRAMMENTI","explode":"PROIETTILI ESPLOSIVI|PROB. ESPLOSIONE","burn":"INCENDIARIO|USTIONE","poison":"TOSSINA|VELENO","shock":"BOBINA TESLA|PROB. SCOSSA","coins":"SCIACALLO|MONETE","drop":"BOTTINO|PROB. RITROVAMENTO","ammo_return":"RICICLATORE|MUNIZIONI RESTITUITE","pickup_range":"CALAMITA|PORTATA RACCOLTA"},
	"id":{"max_hp":"KULIT TEBAL|HP MAKS","heal":"MEDIS LAPANGAN|HP","regen":"ADRENALIN|REGEN","kill_heal":"HAUS DARAH|HP PER BUNUH","dmg_reduce":"MENGERAS|DAMAGE DITERIMA","shield":"PERISAI ANTI RUSUH|PERISAI","move":"KAKI RINGAN|KECEPATAN","damage":"PELURU BERAT|DAMAGE","rate":"PELATUK CEPAT|LAJU TEMBAK","bullet_speed":"ISI PANAS|LAJU PELURU","range":"LARAS PANJANG|JANGKAUAN","strafe":"LANGKAH CEPAT|GESER","crit_chance":"PENEMBAK JITU|PELUANG KRITIS","crit_damage":"PELURU BERONGGA|DAMAGE KRITIS","magazine":"MAGAZIN BESAR|MAGAZIN","reserve":"CADANGAN PELURU|MAGAZIN","reload":"ISI CEPAT|ISI ULANG","pierce":"PELURU TUSUK|TUSUK","multishot":"LARAS GANDA|PELURU","split":"PELURU PECAH|SERPIHAN","explode":"PELURU LEDAK|PELUANG LEDAKAN","burn":"PEMBAKAR|BAKAR","poison":"RACUN|RACUN","shock":"KOIL TESLA|PELUANG SETRUM","coins":"PEMULUNG|KOIN","drop":"TEMUAN|PELUANG DROP","ammo_return":"PENDAUR ULANG|PELURU KEMBALI","pickup_range":"MAGNET|JANGKAUAN AMBIL"},
	"hi":{"max_hp":"मोटी खाल|अधिकतम HP","heal":"फील्ड मेडिक|HP","regen":"एड्रेनालिन|रीजन","kill_heal":"खून की प्यास|प्रति किल HP","dmg_reduce":"सख्त|लिया गया नुकसान","shield":"रायट शील्ड|शील्ड","move":"हल्के पैर|गति","damage":"भारी गोलियाँ|नुकसान","rate":"तेज़ ट्रिगर|फायर रेट","bullet_speed":"गरम चार्ज|गोली की गति","range":"लंबी बैरल|रेंज","strafe":"तेज़ कदम|साइड स्टेप","crit_chance":"निशानेबाज़|क्रिट संभावना","crit_damage":"हॉलो पॉइंट|क्रिट नुकसान","magazine":"बड़ा मैगज़ीन|मैगज़ीन","reserve":"गोली भंडार|मैगज़ीन","reload":"तेज़ रीलोड|रीलोड","pierce":"भेदी गोलियाँ|भेदन","multishot":"दोहरी बैरल|गोलियाँ","split":"छर्रे वाली गोली|छर्रे","explode":"विस्फोटक गोलियाँ|विस्फोट संभावना","burn":"आग लगाने वाली|जलन","poison":"ज़हर|ज़हर","shock":"टेस्ला कॉइल|करंट संभावना","coins":"लूटेरा|सिक्के","drop":"भाग्यशाली|ड्रॉप संभावना","ammo_return":"रीसायकलर|गोली वापस","pickup_range":"चुंबक|उठाने की रेंज"},
	"ar":{"max_hp":"جلد سميك|أقصى صحة","heal":"مسعف ميداني|صحة","regen":"أدرينالين|تجديد","kill_heal":"تعطش للدم|صحة لكل قتل","dmg_reduce":"متصلب|الضرر المتلقى","shield":"درع|درع","move":"قدمان خفيفتان|سرعة","damage":"ذخيرة ثقيلة|ضرر","rate":"زناد سريع|معدل النار","bullet_speed":"حشوة ساخنة|سرعة الرصاصة","range":"ماسورة طويلة|المدى","strafe":"خطوة سريعة|حركة جانبية","crit_chance":"قناص|فرصة الحرج","crit_damage":"رصاصة جوفاء|ضرر الحرج","magazine":"مخزن ممتد|المخزن","reserve":"احتياطي الذخيرة|مخازن","reload":"تلقيم سريع|التلقيم","pierce":"رصاص خارق|الاختراق","multishot":"ماسورتان|رصاص","split":"رصاص متشظٍّ|شظايا","explode":"رصاص متفجر|فرصة الانفجار","burn":"حارق|حرق","poison":"سم|سم","shock":"ملف تسلا|فرصة الصعق","coins":"نهاب|عملات","drop":"اكتشاف|فرصة السقوط","ammo_return":"معيد تدوير|ذخيرة مستردة","pickup_range":"مغناطيس|مدى الالتقاط"},
	"ru":{"max_hp":"ТОЛСТАЯ КОЖА|МАКС HP","heal":"ФЕЛЬДШЕР|HP","regen":"АДРЕНАЛИН|РЕГЕН.","kill_heal":"ЖАЖДА КРОВИ|HP ЗА УБИЙСТВО","dmg_reduce":"ЗАКАЛЁННЫЙ|ПОЛУЧАЕМЫЙ УРОН","shield":"ЩИТ|ЩИТ","move":"ЛЁГКИЕ НОГИ|СКОРОСТЬ","damage":"ТЯЖЁЛЫЕ ПУЛИ|УРОН","rate":"БЫСТРЫЙ СПУСК|СКОРОСТРЕЛЬНОСТЬ","bullet_speed":"ГОРЯЧИЙ ЗАРЯД|СКОРОСТЬ ПУЛИ","range":"ДЛИННЫЙ СТВОЛ|ДАЛЬНОСТЬ","strafe":"БЫСТРЫЙ ШАГ|ВБОК","crit_chance":"СНАЙПЕР|ШАНС КРИТА","crit_damage":"ЭКСПАНСИВНАЯ|УРОН КРИТА","magazine":"БОЛЬШОЙ МАГАЗИН|МАГАЗИН","reserve":"ЗАПАС ПАТРОНОВ|МАГАЗИНЫ","reload":"БЫСТРАЯ ПЕРЕЗАРЯДКА|ПЕРЕЗАРЯДКА","pierce":"БРОНЕБОЙНЫЕ|ПРОБИТИЕ","multishot":"ДВА СТВОЛА|ПУЛИ","split":"ОСКОЛОЧНЫЕ|ОСКОЛКИ","explode":"РАЗРЫВНЫЕ|ШАНС ВЗРЫВА","burn":"ЗАЖИГАТЕЛЬНЫЕ|ОЖОГ","poison":"ЯД|ЯД","shock":"КАТУШКА ТЕСЛЫ|ШАНС РАЗРЯДА","coins":"МАРОДЁР|МОНЕТЫ","drop":"УДАЧА|ШАНС ДРОПА","ammo_return":"ПЕРЕРАБОТКА|ПАТРОН ОБРАТНО","pickup_range":"МАГНИТ|РАДИУС ПОДБОРА"},
	"pt":{"max_hp":"PELE GROSSA|HP MÁX","heal":"MÉDICO DE CAMPO|HP","regen":"ADRENALINA|REGEN.","kill_heal":"SEDE DE SANGUE|HP POR ABATE","dmg_reduce":"CURTIDO|DANO SOFRIDO","shield":"ESCUDO ANTIMOTIM|ESCUDO","move":"PÉS LEVES|VELOCIDADE","damage":"MUNIÇÃO PESADA|DANO","rate":"GATILHO RÁPIDO|CADÊNCIA","bullet_speed":"CARGA QUENTE|VEL. DA BALA","range":"CANO LONGO|ALCANCE","strafe":"PASSO RÁPIDO|PASSO LATERAL","crit_chance":"ATIRADOR|CHANCE CRÍTICA","crit_damage":"PONTA OCA|DANO CRÍTICO","magazine":"CARREGADOR ESTENDIDO|CARREGADOR","reserve":"RESERVA DE MUNIÇÃO|CARREGADORES","reload":"RECARGA RÁPIDA|RECARGA","pierce":"BALAS PERFURANTES|PERFURAÇÃO","multishot":"CANO DUPLO|BALAS","split":"BALAS FRAGMENTADAS|FRAGMENTOS","explode":"BALAS EXPLOSIVAS|CHANCE DE EXPLOSÃO","burn":"INCENDIÁRIO|QUEIMADURA","poison":"TOXINA|VENENO","shock":"BOBINA TESLA|CHANCE DE CHOQUE","coins":"CARRONHEIRO|MOEDAS","drop":"ACHADO|CHANCE DE DROP","ammo_return":"RECICLADOR|MUNIÇÃO DE VOLTA","pickup_range":"ÍMÃ|ALCANCE DE COLETA"},
	"de":{"max_hp":"DICKE HAUT|MAX HP","heal":"SANITÄTER|HP","regen":"ADRENALIN|REGEN.","kill_heal":"BLUTDURST|HP PRO KILL","dmg_reduce":"ABGEHÄRTET|SCHAden","shield":"SCHILD|SCHILD","move":"LEICHTE FÜSSE|TEMPO","damage":"SCHWERE MUNITION|SCHAden","rate":"SCHNELLER ABZUG|FEUERRATE","bullet_speed":"HEISSE LADUNG|GESCHOSS-TEMPO","range":"LANGER LAUF|REICHWEITE","strafe":"SCHNELLE FÜSSE|SEITWÄRTS","crit_chance":"SCHÜTZE|KRIT-CHANCE","crit_damage":"HOHLSPITZE|KRIT-SCHADEN","magazine":"GROSSES MAGAZIN|MAGAZIN","reserve":"MUNITIONSLAGER|MAGAZINE","reload":"SCHNELLLADER|NACHLADEN","pierce":"PANZERBRECHER|DURCHSCHLAG","multishot":"DOPPELLAUF|KUGELN","split":"SPLITTERKUGELN|SPLITTER","explode":"SPRENGKUGELN|EXPLO-CHANCE","burn":"BRANDMUNITION|BRAND","poison":"TOXIN|GIFT","shock":"TESLA-SPULE|SCHOCK-CHANCE","coins":"PLÜNDERER|MÜNZEN","drop":"GLÜCKSSACHE|DROP-CHANCE","ammo_return":"RECYCLER|MUNITION ZURÜCK","pickup_range":"MAGNET|AUFNAHME-RADIUS"},
	"fr":{"max_hp":"PEAU DURE|PV MAX","heal":"MÉDECIN DE TERRAIN|PV","regen":"ADRÉNALINE|RÉGÉN.","kill_heal":"SOIF DE SANG|PV PAR KILL","dmg_reduce":"ENDUREI|DÉGÂTS SUBIS","shield":"BOUCLIER ANTI-ÉMEUTE|BOUCLIER","move":"PIEDS LÉGERS|VITESSE","damage":"BALLES LOURDES|DÉGÂTS","rate":"DÉTENTE RAPIDE|CADENCE","bullet_speed":"CHARGE CHAUDE|VITESSE BALLE","range":"LONG CANON|PORTÉE","strafe":"PAS RAPIDE|PAS LATÉRAL","crit_chance":"TIREUR|CHANCE CRIT.","crit_damage":"POINTE CREUSE|DÉGÂTS CRIT.","magazine":"CHARGEUR LONG|CHARGEUR","reserve":"RÉSERVE|CHARGEURS","reload":"RECHARGE RAPIDE|RECHARGE","pierce":"BALLES PERFORANTES|PERFORATION","multishot":"DOUBLE CANON|BALLES","split":"BALLES FRAGMENTÉES|FRAGMENTS","explode":"BALLES EXPLOSIVES|CHANCE EXPLO.","burn":"INCENDIAIRE|BRÛLURE","poison":"TOXINE|POISON","shock":"BOBINE TESLA|CHANCE CHOC","coins":"FOURRAGE|PIÈCES","drop":"TROUVAILLE|CHANCE DE BUTIN","ammo_return":"RECYCLEUR|MUNITIONS RENDUES","pickup_range":"AIMANT|PORTÉE DE RAMASSAGE"},
	"es":{"max_hp":"PIEL DURA|HP MÁX","heal":"MÉDICO DE CAMPO|HP","regen":"ADRENALINA|REGENERACIÓN","kill_heal":"SED DE SANGRE|HP POR BAJA","dmg_reduce":"CURTIDO|DAÑO RECIBIDO","shield":"ESCUDO ANTIMOTÍN|ESCUDO","move":"PIES LIGEROS|VELOCIDAD","damage":"MUNICIÓN PESADA|DAÑO","rate":"GATILLO RÁPIDO|CADENCIA","bullet_speed":"CARGA CALIENTE|VEL. DE BALA","range":"CAÑÓN LARGO|ALCANCE","strafe":"PASO RÁPIDO|PASO LATERAL","crit_chance":"TIRADOR|PROB. CRÍTICA","crit_damage":"PUNTA HUECA|DAÑO CRÍTICO","magazine":"CARGADOR EXTENDIDO|CARGADOR","reserve":"RESERVA DE MUNICIÓN|CARGADORES","reload":"RECARGA RÁPIDA|RECARGA","pierce":"BALAS PERFORANTES|PERFORACIÓN","multishot":"DOBLE CAÑÓN|BALAS","split":"BALAS FRAGMENTADAS|FRAGMENTOS","explode":"BALAS EXPLOSIVAS|PROB. EXPLOSIÓN","burn":"INCENDIARIO|QUEMADURA","poison":"TOXINA|VENENO","shock":"BOBINA TESLA|PROB. DESCARGA","coins":"CARRONERO|MONEDAS","drop":"HALLAZGO|PROB. DE OBJETO","ammo_return":"RECICLADOR|MUNICIÓN DEVUELTA","pickup_range":"IMÁN|ALCANCE DE RECOGIDA"},
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
