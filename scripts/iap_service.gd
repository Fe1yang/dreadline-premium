extends Node
## Apple In-App Purchase (StoreKit 2) for Dead Frontier.
##
## Native side: hrk4649/godot_ios_plugin_iap (singleton "IOSInAppPurchase"), built for Godot 4.7.2
## with deliver-then-finish support (setAutoFinish / finishTransaction, PR #21).
##
## Rules this file enforces:
##  * Rewards are granted only for a StoreKit transaction the plugin reports as VERIFIED
##    ("result":"success" — the plugin never reports unverified ones as success).
##  * Every transaction ID is granted at most once (ledger saved with the game), and the
##    transaction is finished only AFTER the reward is saved, so a crash in between just means
##    StoreKit hands it to us again on the next launch.
##  * Prices and names come from the App Store; nothing is hard-coded on device.
##  * The development simulator exists only in the editor / debug builds without StoreKit and
##    can never run in an exported release build.

signal products_updated
## status: "purchased", "pending", "cancelled", "failed", "restored", "revoked"
signal purchase_finished(pack_id: String, status: String)

const SINGLETON:="IOSInAppPurchase"
const PREFIX:="com.deadfrontier."
## Product IDs in App Store Connect. Coins / vouchers / cans / bundles / offers are Consumable;
## removeads / characters / skins / pets are Non-Consumable (see NON_CONSUMABLE). Keep this
## table in sync with App Store Connect and docs/app-store-connect-setup.md.
const PRODUCTS:={
	"bundle_starter":"com.deadfrontier.bundle.starter",
	"bundle_supply":"com.deadfrontier.bundle.supply",
	"bundle_legend":"com.deadfrontier.bundle.legend",
	"cans_1":"com.deadfrontier.cans.10",
	"cans_2":"com.deadfrontier.cans.30",
	"cans_3":"com.deadfrontier.cans.60",
	"cans_4":"com.deadfrontier.cans.150",
	"cans_5":"com.deadfrontier.cans.300",
	"cans_6":"com.deadfrontier.cans.600",
	"coins_1":"com.deadfrontier.coins.300",
	"coins_2":"com.deadfrontier.coins.1650",
	"coins_3":"com.deadfrontier.coins.3500",
	"coins_4":"com.deadfrontier.coins.7400",
	"coins_5":"com.deadfrontier.coins.19500",
	"coins_6":"com.deadfrontier.coins.41000",
	"coins_7":"com.deadfrontier.coins.5000",
	"coins_8":"com.deadfrontier.coins.50000",
	"coins_9":"com.deadfrontier.coins.500000",
	"silver_1":"com.deadfrontier.silver.300",
	"silver_2":"com.deadfrontier.silver.1650",
	"silver_3":"com.deadfrontier.silver.3500",
	"silver_4":"com.deadfrontier.silver.7400",
	"silver_5":"com.deadfrontier.silver.19500",
	"silver_6":"com.deadfrontier.silver.41000",
	"vouchers_1":"com.deadfrontier.vouchers.1",
	"vouchers_2":"com.deadfrontier.vouchers.5",
	"vouchers_3":"com.deadfrontier.vouchers.10",
	"vouchers_4":"com.deadfrontier.vouchers.25",
	"vouchers_5":"com.deadfrontier.vouchers.50",
	"vouchers_6":"com.deadfrontier.vouchers.100",
	"offer_supply":"com.deadfrontier.offer.supply",
	"offer_arms":"com.deadfrontier.offer.arms",
	"offer_hoard":"com.deadfrontier.offer.hoard",
	"offer_cans":"com.deadfrontier.offer.cans.150",
	"removeads":"com.deadfrontier.removeads",
	# Unlockable survivors / outfits / companions: one-time (Non-Consumable) purchases.
	"char_darius":"com.deadfrontier.char.darius",
	"char_maya":"com.deadfrontier.char.maya",
	"skin_maya_tactical":"com.deadfrontier.skin.maya.tactical",
	"offer_gold_bike":"com.deadfrontier.offer.gold.bike",
	"offer_tank":"com.deadfrontier.offer.tank",
	"offer_sport_bike":"com.deadfrontier.offer.sport.bike",
	"offer_darius_bundle":"com.deadfrontier.offer.darius.bundle",
	"unlock_all":"com.deadfrontier.unlock.all",
	"offer_unlock_all":"com.deadfrontier.offer.unlock.all",
	"pass_weekly":"com.deadfrontier.pass.weekly",
	"pass_monthly":"com.deadfrontier.pass.monthly",
	"pet_0":"com.deadfrontier.pet.0",
	"pet_1":"com.deadfrontier.pet.1",
	"pet_2":"com.deadfrontier.pet.2",
	"pet_3":"com.deadfrontier.pet.3",
	"pet_4":"com.deadfrontier.pet.4",
}
## Non-Consumable ids: restore re-applies these from Transaction.currentEntitlements;
## consumables must NOT be listed here (re-granting them on restore would duplicate rewards).
const NON_CONSUMABLE:=["removeads","unlock_all","offer_unlock_all","pass_weekly","pass_monthly","char_darius","char_maya","skin_maya_tactical",
	"pet_0","pet_1","pet_2","pet_3","pet_4"]

var mode:="none"            # "storekit", "sim" (editor / debug only) or "none"
var plugin: Object
var prices:={}              # pack id -> localized display price from the App Store
var names:={}               # pack id -> localized display name from the App Store
var busy:={}                # pack id -> true while a purchase sheet is open
var products_loaded:=false
var products_error:=""
## Called with (pack_id, transaction_id) to grant a verified purchase; returns true once the
## reward is saved. Set by main_3d.
var grant: Callable
## Ledger of granted transaction IDs (shared with the save file by main_3d).
var ledger:={}
## Simulator: what the next simulated purchase returns ("purchased", "cancelled", "pending",
## "failed"); editor / debug only.
var sim_next:="purchased"

func _ready() -> void:
	if Engine.has_singleton(SINGLETON):
		mode="storekit"; plugin=Engine.get_singleton(SINGLETON)
		plugin.response.connect(_on_response)
		plugin.request("setAutoFinish",{"autoFinish":false})   # we finish after granting
		plugin.request("startUpdateTask",{})                   # Ask to Buy approvals, refunds, other devices
		plugin.request("proceedUnfinishedTransactions",{})     # anything paid but not yet delivered
		refresh_products()
	elif sim_allowed():
		mode="sim"; products_loaded=true
	else:
		mode="none"

## The simulator can only ever run where real money cannot be involved.
static func sim_allowed() -> bool:
	if OS.has_feature("template_release"): return false
	return OS.has_feature("editor") or (OS.is_debug_build() and OS.get_name()!="iOS")

func product_id(pack_id: String) -> String:
	return String(PRODUCTS.get(pack_id,""))

func pack_for(product: String) -> String:
	for k in PRODUCTS:
		if PRODUCTS[k]==product: return k
	return ""

func refresh_products() -> void:
	if mode!="storekit": return
	products_error=""
	plugin.request("products",{"productIDs":PRODUCTS.values()})

## Price text for the store button: the App Store's localized price, or "" while unknown
## (the UI then shows a placeholder and keeps the button disabled).
func price(pack_id: String) -> String:
	return String(prices.get(pack_id,""))

func available(pack_id: String) -> bool:
	if mode=="sim": return true
	return mode=="storekit" and prices.has(pack_id)

func buy(pack_id: String) -> bool:
	var pid:=product_id(pack_id)
	if pid=="" or busy.has(pack_id): return false
	match mode:
		"storekit":
			if not prices.has(pack_id): purchase_finished.emit(pack_id,"failed"); return false
			busy[pack_id]=true
			if plugin.request("purchase",{"productID":pid})!=0:
				busy.erase(pack_id); purchase_finished.emit(pack_id,"failed"); return false
			return true
		"sim":
			busy[pack_id]=true
			_sim_purchase(pack_id)
			return true
	purchase_finished.emit(pack_id,"failed")
	return false

## "Restore purchases": re-syncs with the App Store (may ask for the Apple ID password), then
## re-applies non-consumables from the current entitlements.
func restore() -> void:
	match mode:
		"storekit": plugin.request("appStoreSync",{})
		"sim":
			if ledger.has("sim-removeads"): purchase_finished.emit("removeads","restored")
			else: purchase_finished.emit("","restored")

func _sim_purchase(pack_id: String) -> void:
	busy.erase(pack_id)
	if not sim_allowed(): purchase_finished.emit(pack_id,"failed"); return
	var outcome:=sim_next; sim_next="purchased"
	if outcome!="purchased": purchase_finished.emit(pack_id,outcome); return
	var tx:="sim-"+pack_id if pack_id in NON_CONSUMABLE else "sim-%d-%d"%[Time.get_ticks_usec(),randi()]
	_deliver(pack_id,tx,false)

## Grants once per transaction ID, then (on device) finishes the transaction.
func _deliver(pack_id: String,tx: String,finish_native: bool,status:="purchased") -> void:
	if pack_id=="": return
	if ledger.has(tx):
		if finish_native: plugin.request("finishTransaction",{"transactionID":tx})
		if pack_id in NON_CONSUMABLE: purchase_finished.emit(pack_id,"restored")
		return
	var ok: bool=grant.is_valid() and bool(grant.call(pack_id,tx))
	if not ok: purchase_finished.emit(pack_id,"failed"); return  # not finished: StoreKit retries later
	ledger[tx]=true
	if finish_native: plugin.request("finishTransaction",{"transactionID":tx})
	purchase_finished.emit(pack_id,status)

func _on_response(name: String,data: Dictionary) -> void:
	var result:=String(data.get("result",""))
	match name:
		"products":
			if result=="success":
				for p in data.get("products",[]):
					var pack:=pack_for(String(p.get("id","")))
					if pack=="": continue
					prices[pack]=String(p.get("displayPrice","")); names[pack]=String(p.get("displayName",""))
				products_loaded=true
			else: products_error=String(data.get("error","error"))
			products_updated.emit()
		"purchase":
			var pack:=pack_for(String(data.get("productID","")))
			busy.erase(pack)
			match result:
				"success":
					var tx:=String(data.get("transactionID",""))
					if tx=="": purchase_finished.emit(pack,"failed"); return
					_deliver(pack,tx,true)
				"revoked":
					purchase_finished.emit(pack,"revoked")
				"pending": purchase_finished.emit(pack,"pending")
				"userCancelled": purchase_finished.emit(pack,"cancelled")
				_: purchase_finished.emit(pack,"failed")    # unverified, error, unknown, network
		"appStoreSync":
			plugin.request("transactionCurrentEntitlements",{})
		"transactionCurrentEntitlements":
			var any:=false
			for t in data.get("transactions",[]):
				var pack:=pack_for(String(t.get("productID","")))
				if pack in NON_CONSUMABLE: any=true; purchase_finished.emit(pack,"restored")
			if not any: purchase_finished.emit("","restored")
