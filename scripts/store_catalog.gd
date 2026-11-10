extends RefCounted
## Real-money store: coin packs, voucher packs and bundles, priced in the player's own currency.
##
## Prices are App Store style price points. Each pack names a tier (its US price); every
## currency lists the matching local price for each tier, rounded the way stores show them
## (¥6 / ¥30 / ¥68 in China, ¥160 in Japan, R$ 5,90 in Brazil ...). The currency comes from the
## device region (OS.get_locale()), not the in-game language. The real charge is made by the
## App Store at checkout, so these are display prices and should be refreshed from StoreKit's
## localized prices once purchasing is connected (see main_3d.buy_pack).

const TIERS:=[0.99,1.99,4.99,9.99,19.99,49.99,99.99,10.0]

## id, art (res://assets/ui/store/<id>.png, goods only: the glow behind it is animated by hud.gd),
## coins, vouchers, price tier index, bonus %, kind, glow colour and number of light rays.
## One voucher opens one supply case, so vouchers are kept scarce.
const PACKS:=[
	{"id":"pass_weekly","kind":"pass","name":"pass_weekly","coins":200,"cans":30,"vouchers":0,"tier":2,"bonus":0,"glow":"violet","rays":12},
	{"id":"pass_monthly","kind":"pass","name":"pass_monthly","coins":500,"cans":100,"vouchers":0,"tier":3,"bonus":0,"glow":"gold","rays":16},
	{"id":"unlock_all","kind":"unlock","name":"unlock_all","coins":0,"vouchers":0,"silver":0,"cans":0,"tier":7,"once":true,"glow":"gold","rays":24},
	{"id":"bundle_starter","kind":"bundle","name":"starter","coins":1000,"vouchers":1,"tier":1,"bonus":0,"once":true,"glow":"gold","rays":8},
	{"id":"bundle_supply","kind":"bundle","name":"supply","coins":4000,"vouchers":3,"tier":3,"bonus":0,"once":false,"glow":"amber","rays":12},
	{"id":"bundle_legend","kind":"bundle","name":"legend","coins":22000,"vouchers":12,"tier":5,"bonus":0,"once":false,"glow":"violet","rays":16},
	{"id":"cans_1","kind":"cans","name":"can_packs","cans":10,"coins":0,"vouchers":0,"tier":0,"bonus":0,"glow":"gold","rays":6},
	{"id":"cans_2","kind":"cans","name":"can_packs","cans":30,"coins":0,"vouchers":0,"tier":1,"bonus":0,"glow":"gold","rays":6},
	{"id":"cans_3","kind":"cans","name":"can_packs","cans":60,"coins":0,"vouchers":0,"tier":2,"bonus":0,"glow":"amber","rays":8},
	{"id":"cans_4","kind":"cans","name":"can_packs","cans":150,"coins":0,"vouchers":0,"tier":3,"bonus":0,"glow":"amber","rays":10},
	{"id":"cans_5","kind":"cans","name":"can_packs","cans":300,"coins":0,"vouchers":0,"tier":4,"bonus":0,"glow":"red","rays":12},
	{"id":"cans_6","kind":"cans","name":"can_packs","cans":600,"coins":0,"vouchers":0,"tier":5,"bonus":0,"glow":"violet","rays":16},
	{"id":"coins_1","kind":"coins","coins":300,"vouchers":0,"tier":0,"bonus":0,"glow":"gold","rays":6},
	{"id":"coins_2","kind":"coins","coins":1650,"vouchers":0,"tier":2,"bonus":10,"glow":"gold","rays":6},
	{"id":"coins_3","kind":"coins","coins":3500,"vouchers":0,"tier":3,"bonus":17,"glow":"amber","rays":8},
	{"id":"coins_4","kind":"coins","coins":7400,"vouchers":0,"tier":4,"bonus":23,"glow":"amber","rays":10},
	{"id":"coins_5","kind":"coins","coins":19500,"vouchers":0,"tier":5,"bonus":30,"glow":"red","rays":12},
	{"id":"coins_6","kind":"coins","coins":41000,"vouchers":0,"tier":6,"bonus":37,"glow":"violet","rays":16},
	{"id":"coins_7","kind":"coins","coins":5000,"vouchers":0,"tier":3,"bonus":0,"glow":"red","rays":12,"art":"coins_3"},
	{"id":"coins_8","kind":"coins","coins":50000,"vouchers":0,"tier":5,"bonus":0,"glow":"violet","rays":16,"art":"coins_6"},
	{"id":"coins_9","kind":"coins","coins":500000,"vouchers":0,"tier":6,"bonus":0,"glow":"violet","rays":16,"art":"coins_6"},
	# Silver packs: same 6 amounts as coins, about half price (tier one step below gold).
	# They grant the separate silver wallet, not gold. Art reuses the coin pile shape.
	{"id":"silver_1","kind":"silver","silver":300,"vouchers":0,"tier":0,"bonus":0,"glow":"silver","rays":6,"art":"silver_1"},
	{"id":"silver_2","kind":"silver","silver":1650,"vouchers":0,"tier":1,"bonus":10,"glow":"silver","rays":6,"art":"silver_2"},
	{"id":"silver_3","kind":"silver","silver":3500,"vouchers":0,"tier":2,"bonus":17,"glow":"silver","rays":8,"art":"silver_3"},
	{"id":"silver_4","kind":"silver","silver":7400,"vouchers":0,"tier":3,"bonus":23,"glow":"silver","rays":10,"art":"silver_4"},
	{"id":"silver_5","kind":"silver","silver":19500,"vouchers":0,"tier":4,"bonus":30,"glow":"silver","rays":12,"art":"silver_5"},
	{"id":"silver_6","kind":"silver","silver":41000,"vouchers":0,"tier":5,"bonus":37,"glow":"silver","rays":16,"art":"silver_6"},
	{"id":"vouchers_1","kind":"vouchers","coins":0,"vouchers":1,"tier":0,"bonus":0,"glow":"red","rays":6},
	{"id":"vouchers_2","kind":"vouchers","coins":0,"vouchers":5,"tier":2,"bonus":0,"glow":"red","rays":6},
	{"id":"vouchers_3","kind":"vouchers","coins":0,"vouchers":10,"tier":3,"bonus":0,"glow":"red","rays":8},
	{"id":"vouchers_4","kind":"vouchers","coins":0,"vouchers":25,"tier":4,"bonus":25,"glow":"violet","rays":10},
	{"id":"vouchers_5","kind":"vouchers","coins":0,"vouchers":50,"tier":5,"bonus":0,"glow":"violet","rays":12},
	{"id":"vouchers_6","kind":"vouchers","coins":0,"vouchers":100,"tier":6,"bonus":0,"glow":"violet","rays":16},
	# Unlockable survivors and outfits: Mason and Riley are free; everyone else is a
	# one-time App Store purchase. `char` indexes lobby.CHARACTERS, `skin` indexes lobby.SKINS.
	{"id":"char_darius","kind":"character","name":"char_darius","char":2,"perk":"perk_darius","coins":1200,"vouchers":0,"tier":7,"bonus":0,"once":true,"glow":"gold","rays":8},
	{"id":"char_maya","kind":"character","name":"char_maya","char":3,"perk":"perk_maya","coins":1600,"vouchers":0,"tier":7,"bonus":0,"once":true,"glow":"violet","rays":10},
	{"id":"char_riley","kind":"character","name":"char_riley","char":1,"coins":5000,"vouchers":0,"tier":7,"bonus":0,"once":true,"glow":"teal","rays":8},
	{"id":"pet_0","kind":"pet","name":"pets","pet":0,"coins":2500,"silver":0,"vouchers":0,"tier":2,"bonus":0,"once":true,"glow":"gold","rays":8},
	{"id":"pet_1","kind":"pet","name":"pets","pet":1,"silver":12000,"coins":0,"vouchers":0,"tier":2,"bonus":0,"once":true,"glow":"amber","rays":8},
	{"id":"pet_2","kind":"pet","name":"pets","pet":2,"coins":3000,"silver":0,"vouchers":0,"tier":2,"bonus":0,"once":true,"glow":"violet","rays":10},
	{"id":"pet_3","kind":"pet","name":"pets","pet":3,"coins":4000,"silver":0,"vouchers":0,"tier":2,"bonus":0,"once":true,"glow":"red","rays":10},
	{"id":"pet_4","kind":"pet","name":"pets","pet":4,"coins":6000,"silver":0,"vouchers":0,"tier":3,"bonus":0,"once":true,"glow":"amber","rays":12},
	{"id":"pet_6","kind":"pet","name":"pets","pet":6,"coins":12000,"silver":0,"vouchers":0,"tier":5,"bonus":0,"once":true,"glow":"gold","rays":20},
{"id":"pet_5","kind":"pet","name":"pets","pet":5,"coins":10000,"silver":0,"vouchers":0,"tier":5,"bonus":0,"once":true,"glow":"gold","rays":20},
	{"id":"vehicle_bike","kind":"vehicle","vehicle":"BIKE","name":"bike","coins":0,"silver":6000,"vouchers":0,"tier":3,"bonus":0,"once":true,"glow":"teal","rays":12,"art":"vehicle_bike"},
	{"id":"vehicle_sport","kind":"vehicle","vehicle":"SPORT","name":"sport","coins":4000,"silver":0,"vouchers":0,"tier":3,"bonus":0,"once":true,"glow":"amber","rays":12,"art":"vehicle_sport"},
	{"id":"vehicle_car","kind":"vehicle","vehicle":"CRUISER","name":"cruiser","coins":7000,"silver":0,"vouchers":0,"tier":4,"bonus":0,"once":true,"glow":"red","rays":16,"art":"vehicle_cruiser"},
	{"id":"vehicle_gold","kind":"vehicle","vehicle":"GOLD","name":"gold","coins":10000,"silver":0,"vouchers":0,"tier":5,"bonus":0,"once":true,"glow":"gold","rays":20,"art":"vehicle_gold"},
	{"id":"vehicle_tank","kind":"vehicle","vehicle":"TANK","name":"tank","coins":20000,"silver":0,"vouchers":0,"tier":6,"bonus":0,"once":true,"glow":"silver","rays":24,"art":"vehicle_tank"},
{"id":"weapon_flame","kind":"special","weapon":"FLAME","name":"flame","coins":10000,"silver":0,"vouchers":0,"tier":5,"bonus":0,"once":true,"glow":"gold","rays":14},
	{"id":"vehicle_sedan","kind":"vehicle","vehicle":"SEDAN","name":"sedan","coins":5000,"silver":0,"vouchers":0,"tier":3,"bonus":0,"once":true,"glow":"silver","rays":18,"art":"vehicle_sedan"},
{"id":"vehicle_gold_car","kind":"vehicle","vehicle":"GOLD_CAR","name":"gold_car","coins":30000,"silver":0,"vouchers":0,"tier":5,"bonus":0,"once":true,"glow":"gold","rays":22,"art":"vehicle_gold_car"},
]

## Limited-time offers: one pops up every two to three days (see main_3d.maybe_show_offer) and
## stays for OFFER_HOURS. "was" is the tier the contents would normally cost; the badge shows
## the saving between the two US prices.
const OFFER_HOURS:=6
const GLOW:={"gold":Color(1.0,0.72,0.25),"amber":Color(1.0,0.48,0.15),"red":Color(0.95,0.2,0.15),"violet":Color(0.62,0.32,1.0),"silver":Color(0.85,0.90,1.0),"teal":Color(0.15,0.78,0.72)}
const OFFERS:=[
]
static func offer(id: String) -> Dictionary:
	for o in OFFERS:
		if o.id==id: return o
	return {}

static func discount(o: Dictionary) -> int:
	var now: float=float(o.get("usd",TIERS[clampi(int(o.tier),0,TIERS.size()-1)]))
	var was: float=float(TIERS[clampi(int(o.get("was",o.tier)),0,TIERS.size()-1)])
	return int(round((1.0-now/was)*100.0))

## code: [symbol, symbol after the number?, decimals, decimal mark, thousands mark, prices per tier]
const CURRENCIES:={
	"USD":["$",false,2,".",",",[0.99,1.99,4.99,9.99,19.99,49.99,99.99,10.0]],
	"CNY":["¥",false,0,".",",",[6,12,30,68,128,328,648],70],
	"JPY":["¥",false,0,".",",",[160,300,800,1500,3000,7800,15800],1550],
	"KRW":["₩",false,0,".",",",[1400,2900,7500,14000,29000,73000,149000],14500],
	"TWD":["NT$",false,0,".",",",[30,60,150,300,590,1490,2990],310],
	"HKD":["HK$",false,0,".",",",[8,15,38,78,158,388,778],80],
	"SGD":["S$",false,2,".",",",[1.48,2.98,6.98,13.98,27.98,68.98,138.98],14.0],
	"EUR":["€",true,2,",",".",[0.99,1.99,4.99,9.99,19.99,49.99,99.99,10.99]],
	"GBP":["£",false,2,".",",",[0.99,1.99,4.99,9.99,19.99,49.99,99.99,10.49]],
	"RUB":["₽",true,0,","," ",[99,199,499,999,1990,4990,9990],1050],
	"UAH":["₴",true,0,","," ",[39,79,199,399,799,1999,3999],419],
	"PLN":["zł",true,2,","," ",[4.99,9.99,24.99,49.99,99.99,249.99,499.99],52.99],
	"TRY":["₺",false,2,",",".",[39.99,79.99,199.99,399.99,799.99,1999.99,3999.99],449.99],
	"INR":["₹",false,0,".",",",[89,179,449,899,1799,4499,8999],999],
	"IDR":["Rp",false,0,",",".",[16000,32000,79000,159000,319000,799000,1599000],169000],
	"THB":["฿",false,0,".",",",[35,69,179,349,699,1790,3590],369],
	"VND":["₫",true,0,",",".",[25000,49000,129000,249000,499000,1290000,2490000],259000],
	"BRL":["R$",false,2,",",".",[5.90,11.90,29.90,59.90,119.90,299.90,599.90],64.90],
	"MXN":["MX$",false,0,".",",",[19,39,99,199,399,999,1999],219],
	"CAD":["CA$",false,2,".",",",[1.39,2.79,6.99,13.99,27.99,69.99,139.99],14.49],
	"AUD":["A$",false,2,".",",",[1.49,2.99,7.99,15.99,29.99,79.99,159.99],16.99],
	"SAR":["ر.س",true,2,".",",",[3.99,7.99,19.99,39.99,79.99,199.99,399.99,44.99]],
	"AED":["د.إ",true,2,".",",",[3.99,7.99,19.99,39.99,79.99,199.99,399.99,44.99]],
}
const REGION_CURRENCY:={
	"US":"USD","CN":"CNY","JP":"JPY","KR":"KRW","TW":"TWD","HK":"HKD","MO":"HKD","SG":"SGD",
	"GB":"GBP","RU":"RUB","UA":"UAH","PL":"PLN","TR":"TRY","IN":"INR","ID":"IDR","TH":"THB",
	"VN":"VND","BR":"BRL","MX":"MXN","CA":"CAD","AU":"AUD","SA":"SAR","AE":"AED",
	"DE":"EUR","FR":"EUR","ES":"EUR","IT":"EUR","NL":"EUR","PT":"EUR","BE":"EUR","AT":"EUR",
	"IE":"EUR","FI":"EUR","GR":"EUR","SK":"EUR","SI":"EUR","LT":"EUR","LV":"EUR","EE":"EUR",
	"LU":"EUR","MT":"EUR","CY":"EUR","HR":"EUR"}
## When the device gives a language but no region.
const LANGUAGE_CURRENCY:={"zh":"CNY","ja":"JPY","ko":"KRW","ru":"RUB","uk":"UAH","pl":"PLN",
	"tr":"TRY","hi":"INR","id":"IDR","th":"THB","vi":"VND","pt":"BRL","ar":"SAR",
	"de":"EUR","fr":"EUR","es":"EUR","it":"EUR","nl":"EUR"}

static func currency_for_locale(locale: String) -> String:
	var parts:=locale.replace("-","_").split("_")
	for i in range(parts.size()-1,0,-1):
		var region:=parts[i].to_upper()
		if REGION_CURRENCY.has(region): return REGION_CURRENCY[region]
		if region=="HANT": return "TWD"
	return LANGUAGE_CURRENCY.get(parts[0].to_lower(),"USD")

static func device_currency() -> String:
	return currency_for_locale(OS.get_locale())

static func pack(id: String) -> Dictionary:
	for p in PACKS:
		if p.id==id: return p
	return offer(id)

## Bundles do not sit on the tier ladder (29.99 is not one of our price points), so they
## carry an explicit USD price and the local amount is scaled from our 49.99 point.
static func bundle_price(currency: String,usd: float) -> String:
	var c: Array=CURRENCIES.get(currency,CURRENCIES["USD"])
	if currency=="USD": return format_amount(c,usd)
	var ref: float=float(c[5][5])
	return format_amount(c,ref*(usd/49.99))

static func price_text(currency: String,tier: int) -> String:
	var c: Array=CURRENCIES.get(currency,CURRENCIES["USD"])
	return format_amount(c,float(c[5][clampi(tier,0,TIERS.size()-1)]))

static func format_amount(c: Array,amount: float) -> String:
	var decimals: int=c[2]
	var whole:=int(floor(amount+0.0001))
	var digits:=str(whole)
	var grouped:=""
	for i in range(digits.length()):
		if i>0 and (digits.length()-i)%3==0: grouped+=String(c[4])
		grouped+=digits[i]
	var number:=grouped
	if decimals>0:
		var frac:=int(round((amount-whole)*pow(10,decimals)))
		number+=String(c[3])+str(frac).pad_zeros(decimals)
	return (number+" "+String(c[0])) if bool(c[1]) else (String(c[0])+(" " if String(c[0]).length()>1 else "")+number)

## Store words for all 20 languages. Missing keys fall back to English.
const T:={
	"en":{"gold_car":"Golden Supercar","gold_car_desc":"Gold plated supercar · no guns, ploughs through wrecks and rams the horde · first 1000m every run, until it breaks","pay_failed":"Top-up failed","pay_failed_msg":"The purchase didn't go through and nothing was added. Check your connection and try again.","retry":"Retry","close":"Close","limited":"Limited offer","ends":"Ends in","was":"Was","offer_supply":"Supply drop","offer_arms":"Arms deal","offer_hoard":"Gold hoard","buy":"Buy","characters":"Survivors","skins":"Skins","pets":"Pets","vehicles":"Vehicles","bike":"Motorcycle","bike_desc":"Ride it for the first 1000m every run, until it breaks","sport":"Sport Bike","sport_desc":"Faster, harder-hitting ride · first 1000m every run, until it breaks","cruiser":"Cruiser","cruiser_desc":"Heavy chrome cruiser · first 1000m every run, until it breaks","tank":"Battle Tank","tank_desc":"Auto-fires shells that wipe the whole lane | takes 6-8 shots to wreck | very slow to steer","sedan":"Black Sedan","sedan_desc":"No guns: it ploughs through wrecks and rams the horde · first 1000m every run, until it breaks","offer_gold_bike":"Golden Bike Bundle","offer_tank":"Battle Tank Bundle","offer_sport_bike":"Sport Bike Bundle","offer_darius_bundle":"Medic + 5000 Coins","gold":"Golden Bike","gold_desc":"Run-down zombies drop coins · first 1000m every run, until it breaks","pass_monthly":"Monthly Pass","pass_monthly_desc":"$9.99 a month. 500 coins + 100 rations every day.","unlock_all":"Cheat Code","unlock_all_desc":"Every item and resource added in future updates is yours free, forever. Every survivor, pet, vehicle and skin, no ads, endless coins and rations. One purchase, permanent.","passes":"Subscriptions","pass_weekly":"Weekly Pass","pass_weekly_desc":"7 days free, then $3.99 a week. 200 coins + 30 rations every day.","store":"Store","bundles":"Best value","coin_packs":"Coins","silver_packs":"Silver","voucher_packs":"Vouchers","once":"Once only","owned":"Purchased","note":"Approximate local prices. The App Store charges the final amount.","pay_soon":"Payments are not connected yet","test_grant":"Test purchase: added","starter":"Starter pack","supply":"Supply pack","legend":"Legend pack","bonus":"bonus"},
	"zh_CN":{"gold_car":"金色跑车","gold_car_desc":"纯金涂装超跑 · 不开枪，直接冲过路障、撞飞僵尸 · 每局前1000米自动行驶，直到损坏","pay_failed":"充值失败","pay_failed_msg":"本次购买没有完成，奖励未发放。请检查网络后重试。","retry":"重试","close":"关闭","limited":"限时礼包","ends":"剩余","was":"原价","offer_supply":"补给空投","offer_arms":"军火特惠","offer_hoard":"黄金宝藏","buy":"购买","characters":"角色","skins":"皮肤","pets":"宠物","vehicles":"载具","bike":"摩托车","bike_desc":"每局前1000米自动骑乘，直到损坏","sport":"跑车摩托","sport_desc":"速度更快、撞击更强 · 每局前1000米自动骑乘，直到损坏","cruiser":"巡航摩托","cruiser_desc":"重型巡航、撞击最猛 · 每局前1000米自动骑乘，直到损坏","tank":"坦克","tank_desc":"自动开炮，一炮清空整条路 | 约 6-8 发后报废 | 左右移动很慢","sedan":"黑色轿车","sedan_desc":"不开枪，直接冲过路障、撞飞僵尸 · 每局前1000米自动行驶，直到损坏","offer_gold_bike":"黄金摩托礼包","offer_tank":"坦克礼包","offer_sport_bike":"跑车摩托礼包","offer_darius_bundle":"医护兵 + 5000 金币","gold":"黄金摩托","gold_desc":"撞飞僵尸掉金币 · 每局前1000米自动骑乘，直到损坏","pass_monthly":"月卡","pass_monthly_desc":"$9.99/月。每天 500 金币 + 100 罐头。","unlock_all":"金手指","unlock_all_desc":"今后更新新增的所有物品与资源同样免费永久拥有。 金手指：全部角色、宠物、载具、皮肤，免广告，金币与罐头无限。一次购买永久有效。","passes":"订阅","pass_weekly":"周卡","pass_weekly_desc":"前 7 天免费，之后 $3.99/周。每天 200 金币 + 30 罐头。","store":"商店","bundles":"超值礼包","coin_packs":"金币","silver_packs":"银币","voucher_packs":"券","once":"限购一次","owned":"已购买","note":"价格为当地参考价，最终以 App Store 结算为准。","pay_soon":"支付功能尚未接入","test_grant":"测试购买：已到账","starter":"新手礼包","supply":"补给礼包","legend":"传奇礼包","bonus":"赠送"},
	"zh_TW":{"gold_car":"金色跑車","gold_car_desc":"純金塗裝超跑 · 不開槍，直接衝過路障、撞飛殭屍 · 每局前1000公尺自動行駛，直到損壞","pay_failed":"儲值失敗","pay_failed_msg":"本次購買沒有完成，獎勵未發放。請檢查網路後重試。","retry":"重試","close":"關閉","limited":"限時禮包","ends":"剩餘","was":"原價","offer_supply":"補給空投","offer_arms":"軍火特惠","offer_hoard":"黃金寶藏","buy":"購買","characters":"角色","skins":"造型","pets":"寵物","store":"商店","bundles":"超值禮包","coin_packs":"金幣","silver_packs":"銀幣","voucher_packs":"券","once":"限購一次","owned":"已購買","note":"價格為當地參考價，最終以 App Store 結帳為準。","pay_soon":"支付功能尚未接入","test_grant":"測試購買：已到帳","starter":"新手禮包","supply":"補給禮包","legend":"傳奇禮包","bonus":"贈送"},
	"ja":{"gold_car":"ゴールドスーパーカー","gold_car_desc":"純金のスーパーカー · 銃は使わず障害物を突き破りゾンビを跳ね飛ばす · 毎回最初の1000mを自動走行、壊れるまで","pay_failed":"購入に失敗しました","pay_failed_msg":"購入が完了せず、アイテムは付与されていません。通信環境を確認して再度お試しください。","retry":"再試行","close":"閉じる","limited":"期間限定","ends":"残り","was":"通常","offer_supply":"補給投下","offer_arms":"武器特価","offer_hoard":"黄金の山","buy":"購入","characters":"キャラクター","skins":"スキン","pets":"ペット","store":"ショップ","bundles":"お得なパック","coin_packs":"コイン","voucher_packs":"チケット","once":"1回限り","owned":"購入済み","note":"価格は目安です。最終金額は App Store で確定します。","pay_soon":"決済はまだ接続されていません","test_grant":"テスト購入：付与しました","starter":"スターターパック","supply":"補給パック","legend":"レジェンドパック","bonus":"ボーナス"},
	"ko":{"gold_car":"골드 슈퍼카","gold_car_desc":"순금 슈퍼카 · 총 없이 장애물을 뚫고 좀비를 치어버림 · 매 판 첫 1000m 자동 주행, 파손될 때까지","pay_failed":"충전 실패","pay_failed_msg":"구매가 완료되지 않아 보상이 지급되지 않았습니다. 네트워크를 확인한 뒤 다시 시도하세요.","retry":"다시 시도","close":"닫기","limited":"기간 한정","ends":"남은 시간","was":"정가","offer_supply":"보급 투하","offer_arms":"무기 특가","offer_hoard":"황금 더미","buy":"구매","characters":"캐릭터","skins":"스킨","pets":"반려견","store":"상점","bundles":"특가 패키지","coin_packs":"코인","voucher_packs":"쿠폰","once":"1회 한정","owned":"구매 완료","note":"현지 참고 가격입니다. 최종 금액은 App Store에서 결제됩니다.","pay_soon":"결제가 아직 연결되지 않았습니다","test_grant":"테스트 구매: 지급 완료","starter":"스타터 팩","supply":"보급 팩","legend":"전설 팩","bonus":"보너스"},
	"es":{"gold_car":"Superdeportivo dorado","gold_car_desc":"Superdeportivo bañado en oro · sin armas, arrasa obstáculos y embiste a la horda · primeros 1000m de cada partida, hasta romperse","pay_failed":"Error en la recarga","pay_failed_msg":"La compra no se completó y no se añadió nada. Revisa tu conexión e inténtalo de nuevo.","retry":"Reintentar","close":"Cerrar","limited":"Oferta limitada","ends":"Termina en","was":"Antes","offer_supply":"Suministros","offer_arms":"Trato de armas","offer_hoard":"Tesoro de oro","buy":"Comprar","characters":"Personajes","skins":"Aspectos","pets":"Mascotas","store":"Tienda","bundles":"Mejor valor","coin_packs":"Monedas","voucher_packs":"Vales","once":"Solo una vez","owned":"Comprado","note":"Precios locales aproximados. El App Store cobra el importe final.","pay_soon":"Los pagos aún no están conectados","test_grant":"Compra de prueba: añadido","starter":"Pack inicial","supply":"Pack de suministros","legend":"Pack legendario","bonus":"extra"},
	"fr":{"gold_car":"Supercar dorée","gold_car_desc":"Supercar plaquée or · sans armes, traverse les épaves et percute la horde · 1000 premiers mètres de chaque partie, jusqu'à la casse","pay_failed":"Échec de l'achat","pay_failed_msg":"L'achat n'a pas abouti et rien n'a été ajouté. Vérifie ta connexion et réessaie.","retry":"Réessayer","close":"Fermer","limited":"Offre limitée","ends":"Fin dans","was":"Avant","offer_supply":"Largage","offer_arms":"Offre d'armes","offer_hoard":"Trésor d'or","buy":"Acheter","characters":"Personnages","skins":"Skins","pets":"Compagnons","store":"Boutique","bundles":"Meilleures offres","coin_packs":"Pièces","voucher_packs":"Bons","once":"Une seule fois","owned":"Acheté","note":"Prix locaux indicatifs. L'App Store facture le montant final.","pay_soon":"Les paiements ne sont pas encore connectés","test_grant":"Achat test : ajouté","starter":"Pack de départ","supply":"Pack de ravitaillement","legend":"Pack légendaire","bonus":"bonus"},
	"de":{"gold_car":"Goldener Supersportwagen","gold_car_desc":"Vergoldeter Supersportwagen · keine Waffen, durchbricht Wracks und rammt die Horde · erste 1000 m jeder Runde, bis er kaputtgeht","pay_failed":"Aufladen fehlgeschlagen","pay_failed_msg":"Der Kauf wurde nicht abgeschlossen, es wurde nichts gutgeschrieben. Prüfe deine Verbindung und versuche es erneut.","retry":"Erneut","close":"Schließen","limited":"Zeitangebot","ends":"Endet in","was":"Statt","offer_supply":"Nachschub","offer_arms":"Waffendeal","offer_hoard":"Goldschatz","buy":"Kaufen","characters":"Charaktere","skins":"Skins","pets":"Haustiere","store":"Shop","bundles":"Top-Angebote","coin_packs":"Münzen","voucher_packs":"Gutscheine","once":"Nur einmal","owned":"Gekauft","note":"Ungefähre lokale Preise. Der App Store berechnet den Endbetrag.","pay_soon":"Zahlungen sind noch nicht verbunden","test_grant":"Testkauf: gutgeschrieben","starter":"Startpaket","supply":"Nachschubpaket","legend":"Legendenpaket","bonus":"Bonus"},
	"pt":{"gold_car":"Supercarro dourado","gold_car_desc":"Supercarro banhado a ouro · sem armas, atravessa destroços e atropela a horda · primeiros 1000m de cada partida, até quebrar","pay_failed":"Falha na recarga","pay_failed_msg":"A compra não foi concluída e nada foi adicionado. Verifique sua conexão e tente novamente.","retry":"Tentar de novo","close":"Fechar","limited":"Oferta limitada","ends":"Termina em","was":"Antes","offer_supply":"Suprimentos","offer_arms":"Oferta de armas","offer_hoard":"Tesouro","buy":"Comprar","characters":"Personagens","skins":"Visuais","pets":"Bichos","store":"Loja","bundles":"Melhor valor","coin_packs":"Moedas","voucher_packs":"Vales","once":"Só uma vez","owned":"Comprado","note":"Preços locais aproximados. A App Store cobra o valor final.","pay_soon":"Os pagamentos ainda não estão conectados","test_grant":"Compra de teste: adicionado","starter":"Pacote inicial","supply":"Pacote de suprimentos","legend":"Pacote lendário","bonus":"bônus"},
	"ru":{"gold_car":"Золотой суперкар","gold_car_desc":"Позолоченный суперкар · без оружия, пробивает завалы и давит орду · первые 1000 м каждого забега, пока не сломается","pay_failed":"Пополнение не удалось","pay_failed_msg":"Покупка не завершена, ничего не начислено. Проверь соединение и попробуй снова.","retry":"Повторить","close":"Закрыть","limited":"Акция","ends":"Осталось","was":"Было","offer_supply":"Сброс припасов","offer_arms":"Оружейная сделка","offer_hoard":"Золотой клад","buy":"Купить","characters":"Персонажи","skins":"Скины","pets":"Питомцы","store":"Магазин","bundles":"Выгодные наборы","coin_packs":"Монеты","voucher_packs":"Купоны","once":"Только один раз","owned":"Куплено","note":"Примерные местные цены. Итоговую сумму списывает App Store.","pay_soon":"Оплата пока не подключена","test_grant":"Тестовая покупка: начислено","starter":"Стартовый набор","supply":"Набор припасов","legend":"Легендарный набор","bonus":"бонус"},
	"ar":{"gold_car":"سيارة خارقة ذهبية","gold_car_desc":"سيارة خارقة مطلية بالذهب · بلا أسلحة، تخترق الحطام وتدهس الحشد · أول 1000 متر من كل جولة حتى تتحطم","pay_failed":"فشل الشحن","pay_failed_msg":"لم تكتمل عملية الشراء ولم تتم إضافة شيء. تحقق من اتصالك وحاول مرة أخرى.","retry":"إعادة المحاولة","close":"إغلاق","limited":"عرض محدود","ends":"ينتهي خلال","was":"كان","offer_supply":"إمدادات","offer_arms":"صفقة أسلحة","offer_hoard":"كنز ذهبي","buy":"شراء","characters":"الشخصيات","skins":"المظاهر","pets":"الرفاق","store":"المتجر","bundles":"أفضل قيمة","coin_packs":"العملات","voucher_packs":"القسائم","once":"مرة واحدة فقط","owned":"تم الشراء","note":"أسعار محلية تقريبية. يحتسب App Store المبلغ النهائي.","pay_soon":"الدفع غير متصل بعد","test_grant":"شراء تجريبي: تمت الإضافة","starter":"حزمة البداية","supply":"حزمة الإمدادات","legend":"الحزمة الأسطورية","bonus":"مكافأة"},
	"hi":{"gold_car":"गोल्डन सुपरकार","gold_car_desc":"सोने की परत वाली सुपरकार · बिना बंदूक, मलबे को तोड़ती और भीड़ को कुचलती है · हर रन के पहले 1000 मीटर, टूटने तक","pay_failed":"रीचार्ज विफल","pay_failed_msg":"खरीद पूरी नहीं हुई और कुछ नहीं जोड़ा गया। कनेक्शन जाँचें और फिर कोशिश करें।","retry":"फिर कोशिश","close":"बंद करें","limited":"सीमित ऑफ़र","ends":"खत्म होगा","was":"पहले","offer_supply":"सप्लाई ड्रॉप","offer_arms":"हथियार डील","offer_hoard":"सोने का खज़ाना","buy":"खरीदें","characters":"चरित्र","skins":"स्किन","pets":"पालतू","store":"स्टोर","bundles":"सबसे अच्छा सौदा","coin_packs":"सिक्के","voucher_packs":"वाउचर","once":"सिर्फ़ एक बार","owned":"खरीदा गया","note":"अनुमानित स्थानीय कीमतें। अंतिम राशि App Store लेता है।","pay_soon":"भुगतान अभी जुड़ा नहीं है","test_grant":"टेस्ट खरीद: जोड़ा गया","starter":"स्टार्टर पैक","supply":"सप्लाई पैक","legend":"लेजेंड पैक","bonus":"बोनस"},
	"id":{"gold_car":"Supercar Emas","gold_car_desc":"Supercar berlapis emas · tanpa senjata, menerobos reruntuhan dan menabrak gerombolan · 1000m pertama tiap permainan, sampai rusak","pay_failed":"Isi ulang gagal","pay_failed_msg":"Pembelian tidak selesai dan tidak ada yang ditambahkan. Periksa koneksi lalu coba lagi.","retry":"Coba lagi","close":"Tutup","limited":"Penawaran terbatas","ends":"Berakhir","was":"Semula","offer_supply":"Pasokan","offer_arms":"Promo senjata","offer_hoard":"Harta emas","buy":"Beli","characters":"Karakter","skins":"Skin","pets":"Peliharaan","store":"Toko","bundles":"Paling hemat","coin_packs":"Koin","voucher_packs":"Voucher","once":"Hanya sekali","owned":"Dibeli","note":"Perkiraan harga lokal. App Store menagih jumlah akhir.","pay_soon":"Pembayaran belum terhubung","test_grant":"Pembelian uji: ditambahkan","starter":"Paket pemula","supply":"Paket pasokan","legend":"Paket legenda","bonus":"bonus"},
	"it":{"gold_car":"Supercar dorata","gold_car_desc":"Supercar placcata oro · senza armi, sfonda i rottami e travolge l'orda · primi 1000m di ogni partita, finché non si rompe","pay_failed":"Ricarica non riuscita","pay_failed_msg":"L'acquisto non è andato a buon fine e non è stato aggiunto nulla. Controlla la connessione e riprova.","retry":"Riprova","close":"Chiudi","limited":"Offerta limitata","ends":"Scade tra","was":"Prima","offer_supply":"Rifornimenti","offer_arms":"Affare armi","offer_hoard":"Tesoro d'oro","buy":"Compra","characters":"Personaggi","skins":"Costumi","pets":"Animali","store":"Negozio","bundles":"Offerte migliori","coin_packs":"Monete","voucher_packs":"Buoni","once":"Una sola volta","owned":"Acquistato","note":"Prezzi locali indicativi. L'App Store addebita l'importo finale.","pay_soon":"I pagamenti non sono ancora collegati","test_grant":"Acquisto di prova: aggiunto","starter":"Pacchetto iniziale","supply":"Pacchetto rifornimenti","legend":"Pacchetto leggendario","bonus":"bonus"},
	"tr":{"gold_car":"Altın Süper Araba","gold_car_desc":"Altın kaplama süper araba · silahsız, enkazı deler ve sürüyü ezer · her oyunda ilk 1000m, kırılana kadar","pay_failed":"Yükleme başarısız","pay_failed_msg":"Satın alma tamamlanmadı ve hiçbir şey eklenmedi. Bağlantını kontrol edip tekrar dene.","retry":"Tekrar dene","close":"Kapat","limited":"Sınırlı teklif","ends":"Bitiş","was":"Önce","offer_supply":"İkmal","offer_arms":"Silah fırsatı","offer_hoard":"Altın hazinesi","buy":"Satın al","characters":"Karakterler","skins":"Kostümler","pets":"Dostlar","store":"Mağaza","bundles":"En iyi fırsat","coin_packs":"Altın","voucher_packs":"Kuponlar","once":"Yalnızca bir kez","owned":"Satın alındı","note":"Yaklaşık yerel fiyatlar. Son tutarı App Store tahsil eder.","pay_soon":"Ödemeler henüz bağlı değil","test_grant":"Test satın alma: eklendi","starter":"Başlangıç paketi","supply":"İkmal paketi","legend":"Efsane paketi","bonus":"bonus"},
	"nl":{"gold_car":"Gouden supercar","gold_car_desc":"Vergulde supercar · geen wapens, ramt wrakken en de horde · eerste 1000m van elke run, tot hij stukgaat","pay_failed":"Opwaarderen mislukt","pay_failed_msg":"De aankoop is niet gelukt en er is niets toegevoegd. Controleer je verbinding en probeer het opnieuw.","retry":"Opnieuw","close":"Sluiten","limited":"Tijdelijk aanbod","ends":"Eindigt over","was":"Was","offer_supply":"Voorraaddrop","offer_arms":"Wapendeal","offer_hoard":"Goudschat","buy":"Kopen","characters":"Personages","skins":"Skins","pets":"Huisdieren","store":"Winkel","bundles":"Beste deals","coin_packs":"Munten","voucher_packs":"Bonnen","once":"Eenmalig","owned":"Gekocht","note":"Geschatte lokale prijzen. De App Store rekent het eindbedrag af.","pay_soon":"Betalingen zijn nog niet gekoppeld","test_grant":"Testaankoop: toegevoegd","starter":"Startpakket","supply":"Voorraadpakket","legend":"Legendepakket","bonus":"bonus"},
	"pl":{"gold_car":"Złoty supersamochód","gold_car_desc":"Złoty supersamochód · bez broni, przebija wraki i tratuje hordę · pierwsze 1000 m każdego biegu, aż się zepsuje","pay_failed":"Doładowanie nieudane","pay_failed_msg":"Zakup nie został zakończony i nic nie dodano. Sprawdź połączenie i spróbuj ponownie.","retry":"Ponów","close":"Zamknij","limited":"Oferta czasowa","ends":"Koniec za","was":"Było","offer_supply":"Zrzut zapasów","offer_arms":"Okazja zbrojna","offer_hoard":"Złoty skarb","buy":"Kup","characters":"Postacie","skins":"Skiny","pets":"Zwierzaki","store":"Sklep","bundles":"Najlepsze oferty","coin_packs":"Monety","voucher_packs":"Kupony","once":"Tylko raz","owned":"Kupiono","note":"Przybliżone ceny lokalne. Ostateczną kwotę pobiera App Store.","pay_soon":"Płatności nie są jeszcze podłączone","test_grant":"Zakup testowy: dodano","starter":"Pakiet startowy","supply":"Pakiet zaopatrzenia","legend":"Pakiet legendarny","bonus":"bonus"},
	"th":{"gold_car":"ซูเปอร์คาร์สีทอง","gold_car_desc":"ซูเปอร์คาร์ชุบทอง · ไม่มีปืน ทะลุซากและชนฝูงซอมบี้ · วิ่งอัตโนมัติ 1000 เมตรแรกของทุกตา จนพัง","pay_failed":"เติมเงินไม่สำเร็จ","pay_failed_msg":"การซื้อไม่สำเร็จและยังไม่ได้รับของรางวัล ตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง","retry":"ลองอีกครั้ง","close":"ปิด","limited":"ข้อเสนอจำกัดเวลา","ends":"เหลือ","was":"ปกติ","offer_supply":"เสบียงด่วน","offer_arms":"อาวุธราคาพิเศษ","offer_hoard":"ขุมทองคำ","buy":"ซื้อ","characters":"ตัวละคร","skins":"สกิน","pets":"สัตว์เลี้ยง","store":"ร้านค้า","bundles":"แพ็กคุ้มค่า","coin_packs":"เหรียญ","voucher_packs":"คูปอง","once":"ซื้อได้ครั้งเดียว","owned":"ซื้อแล้ว","note":"ราคาท้องถิ่นโดยประมาณ ยอดสุดท้ายเรียกเก็บโดย App Store","pay_soon":"ยังไม่ได้เชื่อมต่อการชำระเงิน","test_grant":"ซื้อทดสอบ: เพิ่มแล้ว","starter":"แพ็กเริ่มต้น","supply":"แพ็กเสบียง","legend":"แพ็กตำนาน","bonus":"โบนัส"},
	"vi":{"gold_car":"Siêu xe vàng","gold_car_desc":"Siêu xe mạ vàng · không súng, xuyên qua xác xe và húc văng bầy zombie · 1000m đầu mỗi ván, cho đến khi hỏng","pay_failed":"Nạp thất bại","pay_failed_msg":"Giao dịch chưa hoàn tất và chưa nhận được gì. Hãy kiểm tra kết nối rồi thử lại.","retry":"Thử lại","close":"Đóng","limited":"Ưu đãi có hạn","ends":"Còn","was":"Giá gốc","offer_supply":"Tiếp tế","offer_arms":"Ưu đãi vũ khí","offer_hoard":"Kho vàng","buy":"Mua","characters":"Nhân vật","skins":"Trang phục","pets":"Thú cưng","store":"Cửa hàng","bundles":"Giá trị nhất","coin_packs":"Xu","voucher_packs":"Phiếu","once":"Chỉ một lần","owned":"Đã mua","note":"Giá địa phương tham khảo. App Store tính số tiền cuối cùng.","pay_soon":"Chưa kết nối thanh toán","test_grant":"Mua thử: đã cộng","starter":"Gói khởi đầu","supply":"Gói tiếp tế","legend":"Gói huyền thoại","bonus":"thưởng"},
	"uk":{"gold_car":"Золотий суперкар","gold_car_desc":"Позолочений суперкар · без зброї, пробиває завали й тисне орду · перші 1000 м кожного забігу, доки не зламається","pay_failed":"Поповнення не вдалося","pay_failed_msg":"Покупку не завершено, нічого не нараховано. Перевір з'єднання і спробуй ще раз.","retry":"Повторити","close":"Закрити","limited":"Акція","ends":"Залишилось","was":"Було","offer_supply":"Скидання припасів","offer_arms":"Збройова угода","offer_hoard":"Золотий скарб","buy":"Купити","characters":"Персонажі","skins":"Скіни","pets":"Улюбленці","store":"Крамниця","bundles":"Вигідні набори","coin_packs":"Монети","voucher_packs":"Купони","once":"Лише один раз","owned":"Придбано","note":"Орієнтовні місцеві ціни. Остаточну суму списує App Store.","pay_soon":"Оплату ще не підключено","test_grant":"Тестова покупка: зараховано","starter":"Стартовий набір","supply":"Набір припасів","legend":"Легендарний набір","bonus":"бонус"},
}

const CAN_T:={
	"en":{"gold_car":"Golden Supercar","gold_car_desc":"Gold plated supercar · no guns, ploughs through wrecks and rams the horde · first 1000m every run, until it breaks","can_packs":"Cans","no_cans":"Not enough cans. Wait for recovery or get more in the store.","watch_ad_cans":"Watch an ad · +5 cans","ads_remaining":"%d / 10 left today"},
	"zh_CN":{"gold_car":"金色跑车","gold_car_desc":"纯金涂装超跑 · 不开枪，直接冲过路障、撞飞僵尸 · 每局前1000米自动行驶，直到损坏","can_packs":"罐头","no_cans":"罐头不足，等待恢复或前往商城补充","watch_ad_cans":"看广告 · +5 罐头","ads_remaining":"今日剩余 %d/10 次"},
	"zh_TW":{"gold_car":"金色跑車","gold_car_desc":"純金塗裝超跑 · 不開槍，直接衝過路障、撞飛殭屍 · 每局前1000公尺自動行駛，直到損壞","can_packs":"罐頭","no_cans":"罐頭不足，等待恢復或前往商城補充","watch_ad_cans":"看廣告 · +5 罐頭","ads_remaining":"今日剩餘 %d/10 次"},
	"ja":{"gold_car":"ゴールドスーパーカー","gold_car_desc":"純金のスーパーカー · 銃は使わず障害物を突き破りゾンビを跳ね飛ばす · 毎回最初の1000mを自動走行、壊れるまで","can_packs":"缶詰","no_cans":"缶詰が不足しています。回復を待つか、ショップで補充してください。","watch_ad_cans":"広告を見て缶詰 +5","ads_remaining":"本日残り %d/10 回"},
	"ko":{"gold_car":"골드 슈퍼카","gold_car_desc":"순금 슈퍼카 · 총 없이 장애물을 뚫고 좀비를 치어버림 · 매 판 첫 1000m 자동 주행, 파손될 때까지","can_packs":"통조림","no_cans":"통조림이 부족합니다. 회복을 기다리거나 상점에서 보충하세요.","watch_ad_cans":"광고 보고 통조림 +5","ads_remaining":"오늘 남은 횟수 %d/10"},
	"es":{"gold_car":"Superdeportivo dorado","gold_car_desc":"Superdeportivo bañado en oro · sin armas, arrasa obstáculos y embiste a la horda · primeros 1000m de cada partida, hasta romperse","can_packs":"Latas","no_cans":"No tienes suficientes latas. Espera a que se recuperen o compra más.","watch_ad_cans":"Ver anuncio · +5 latas","ads_remaining":"Hoy quedan %d/10"},
	"fr":{"gold_car":"Supercar dorée","gold_car_desc":"Supercar plaquée or · sans armes, traverse les épaves et percute la horde · 1000 premiers mètres de chaque partie, jusqu'à la casse","can_packs":"Conserves","no_cans":"Pas assez de conserves. Attends la récupération ou achètes-en.","watch_ad_cans":"Voir une pub · +5 conserves","ads_remaining":"Restants aujourd’hui : %d/10"},
	"de":{"gold_car":"Goldener Supersportwagen","gold_car_desc":"Vergoldeter Supersportwagen · keine Waffen, durchbricht Wracks und rammt die Horde · erste 1000 m jeder Runde, bis er kaputtgeht","can_packs":"Dosen","no_cans":"Nicht genug Dosen. Warte auf Erholung oder kaufe weitere im Shop.","watch_ad_cans":"Werbung ansehen · +5 Dosen","ads_remaining":"Heute übrig: %d/10"},
	"pt":{"gold_car":"Supercarro dourado","gold_car_desc":"Supercarro banhado a ouro · sem armas, atravessa destroços e atropela a horda · primeiros 1000m de cada partida, até quebrar","can_packs":"Latas","no_cans":"Latas insuficientes. Aguarde a recuperação ou compre mais na loja.","watch_ad_cans":"Assistir anúncio · +5 latas","ads_remaining":"Restantes hoje: %d/10"},
	"ru":{"gold_car":"Золотой суперкар","gold_car_desc":"Позолоченный суперкар · без оружия, пробивает завалы и давит орду · первые 1000 м каждого забега, пока не сломается","can_packs":"Консервы","no_cans":"Недостаточно консервов. Подожди восстановления или купи ещё.","watch_ad_cans":"Реклама · +5 консервов","ads_remaining":"Сегодня осталось: %d/10"},
	"ar":{"gold_car":"سيارة خارقة ذهبية","gold_car_desc":"سيارة خارقة مطلية بالذهب · بلا أسلحة، تخترق الحطام وتدهس الحشد · أول 1000 متر من كل جولة حتى تتحطم","can_packs":"المعلبات","no_cans":"لا توجد معلبات كافية. انتظر الاستعادة أو اشترِ المزيد.","watch_ad_cans":"شاهد إعلانًا · +5 معلبات","ads_remaining":"المتبقي اليوم: %d/10"},
	"hi":{"gold_car":"गोल्डन सुपरकार","gold_car_desc":"सोने की परत वाली सुपरकार · बिना बंदूक, मलबे को तोड़ती और भीड़ को कुचलती है · हर रन के पहले 1000 मीटर, टूटने तक","can_packs":"कैन","no_cans":"पर्याप्त कैन नहीं हैं। रिकवरी की प्रतीक्षा करें या स्टोर से लें।","watch_ad_cans":"विज्ञापन देखें · +5 कैन","ads_remaining":"आज शेष: %d/10"},
	"id":{"gold_car":"Supercar Emas","gold_car_desc":"Supercar berlapis emas · tanpa senjata, menerobos reruntuhan dan menabrak gerombolan · 1000m pertama tiap permainan, sampai rusak","can_packs":"Kaleng","no_cans":"Kaleng tidak cukup. Tunggu pemulihan atau beli di toko.","watch_ad_cans":"Tonton iklan · +5 kaleng","ads_remaining":"Sisa hari ini: %d/10"},
	"it":{"gold_car":"Supercar dorata","gold_car_desc":"Supercar placcata oro · senza armi, sfonda i rottami e travolge l'orda · primi 1000m di ogni partita, finché non si rompe","can_packs":"Scatolette","no_cans":"Scatolette insufficienti. Attendi il recupero o acquistane altre.","watch_ad_cans":"Guarda un annuncio · +5 scatolette","ads_remaining":"Rimanenti oggi: %d/10"},
	"tr":{"gold_car":"Altın Süper Araba","gold_car_desc":"Altın kaplama süper araba · silahsız, enkazı deler ve sürüyü ezer · her oyunda ilk 1000m, kırılana kadar","can_packs":"Konserveler","no_cans":"Yeterli konserve yok. Yenilenmeyi bekle veya mağazadan al.","watch_ad_cans":"Reklam izle · +5 konserve","ads_remaining":"Bugün kalan: %d/10"},
	"nl":{"gold_car":"Gouden supercar","gold_car_desc":"Vergulde supercar · geen wapens, ramt wrakken en de horde · eerste 1000m van elke run, tot hij stukgaat","can_packs":"Blikjes","no_cans":"Niet genoeg blikjes. Wacht op herstel of koop meer in de winkel.","watch_ad_cans":"Advertentie kijken · +5 blikjes","ads_remaining":"Vandaag over: %d/10"},
	"pl":{"gold_car":"Złoty supersamochód","gold_car_desc":"Złoty supersamochód · bez broni, przebija wraki i tratuje hordę · pierwsze 1000 m każdego biegu, aż się zepsuje","can_packs":"Puszki","no_cans":"Za mało puszek. Poczekaj na regenerację lub kup więcej.","watch_ad_cans":"Obejrzyj reklamę · +5 puszek","ads_remaining":"Pozostało dziś: %d/10"},
	"th":{"gold_car":"ซูเปอร์คาร์สีทอง","gold_car_desc":"ซูเปอร์คาร์ชุบทอง · ไม่มีปืน ทะลุซากและชนฝูงซอมบี้ · วิ่งอัตโนมัติ 1000 เมตรแรกของทุกตา จนพัง","can_packs":"กระป๋อง","no_cans":"กระป๋องไม่พอ รอฟื้นหรือซื้อเพิ่มในร้านค้า","watch_ad_cans":"ดูโฆษณา · +5 กระป๋อง","ads_remaining":"เหลือวันนี้ %d/10 ครั้ง"},
	"vi":{"gold_car":"Siêu xe vàng","gold_car_desc":"Siêu xe mạ vàng · không súng, xuyên qua xác xe và húc văng bầy zombie · 1000m đầu mỗi ván, cho đến khi hỏng","can_packs":"Hộp","no_cans":"Không đủ hộp. Chờ hồi phục hoặc mua thêm trong cửa hàng.","watch_ad_cans":"Xem quảng cáo · +5 hộp","ads_remaining":"Còn hôm nay: %d/10"},
	"uk":{"gold_car":"Золотий суперкар","gold_car_desc":"Позолочений суперкар · без зброї, пробиває завали й тисне орду · перші 1000 м кожного забігу, доки не зламається","can_packs":"Консерви","no_cans":"Недостатньо консервів. Зачекай відновлення або купи ще.","watch_ad_cans":"Реклама · +5 консервів","ads_remaining":"Залишилось сьогодні: %d/10"},
}

static func text(code: String,key: String) -> String:
	if key in ["can_packs","no_cans","watch_ad_cans","ads_remaining"]:
		var can_table: Dictionary=CAN_T.get(code,CAN_T["en"])
		return String(can_table.get(key,CAN_T["en"].get(key,key)))
	var table: Dictionary=T.get(code,T["en"])
	return String(table.get(key,T["en"].get(key,key)))
