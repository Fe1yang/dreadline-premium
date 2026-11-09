extends Node

signal revive_rewarded
signal revive_cancelled
## Other rewarded placements (check-in double, run-coins double) share the same ad unit and
## report back with the purpose they were opened for.
signal ad_rewarded(purpose: String)
signal ad_cancelled(purpose: String)
var purpose := "revive"

# AdMob app "Dead Frontier": ca-app-pub-3341507214983966~4803691884 (set in Project Settings > admob/general/ios/app_id).
# Rewarded unit "Revival_reward" — only served in release (exported) builds.
const AD_UNIT_ID := "ca-app-pub-3341507214983966/6115727375"
# Google's official iOS rewarded TEST unit. AdMob policy forbids loading/clicking your own live
# ads while developing, so every debug build uses this instead.
const TEST_AD_UNIT_ID := "ca-app-pub-3940256099942544/1712485313"

func ad_unit_id() -> String:
	return TEST_AD_UNIT_ID if OS.is_debug_build() else AD_UNIT_ID

var status := "desktop"
var initialized := false
var loading := false
var showing := false
var reward_earned := false
var reward_sent := false
var rewarded_ad: RewardedAd
var rewarded_loader := RewardedAdLoader.new()
var consent_form: ConsentForm

func _ready() -> void:
	if OS.get_name()!="iOS":
		status="desktop"
		return
	status="loading"
	call_deferred("request_user_consent")

func request_user_consent() -> void:
	var params:=ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(
		params,
		func() -> void:
			if UserMessagingPlatform.consent_information.get_is_consent_form_available():
				UserMessagingPlatform.load_consent_form(
					func(form: ConsentForm) -> void:
						consent_form=form
						consent_form.show(func(_error: FormError) -> void: initialize_ads()),
					func(_error: FormError) -> void: initialize_ads()
				)
			else:
				initialize_ads(),
		func(_error: FormError) -> void: initialize_ads()
	)

func initialize_ads() -> void:
	var listener:=OnInitializationCompleteListener.new()
	listener.on_initialization_complete=func(_initialization_status: InitializationStatus) -> void:
		initialized=true
		load_rewarded_ad()
	MobileAds.set_ios_app_pause_on_background(true)
	MobileAds.set_request_configuration(RequestConfiguration.new())
	MobileAds.initialize(listener)

func load_rewarded_ad() -> void:
	if not initialized or loading or is_instance_valid(rewarded_ad): return
	loading=true
	status="loading"
	var callback:=RewardedAdLoadCallback.new()
	callback.on_ad_loaded=func(ad: RewardedAd) -> void:
		loading=false
		rewarded_ad=ad
		status="ready"
		setup_rewarded_callbacks()
	callback.on_ad_failed_to_load=func(error: LoadAdError) -> void:
		loading=false
		status="unavailable"
		push_warning("Revival ad failed to load: "+error.message)
	rewarded_loader.load(ad_unit_id(),AdRequest.new(),callback)

func setup_rewarded_callbacks() -> void:
	if not is_instance_valid(rewarded_ad): return
	var callbacks:=FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content=func() -> void:
		showing=false
		_destroy_rewarded_ad()
		if reward_earned and not reward_sent:
			reward_sent=true
			_emit_reward()
		else:
			_emit_cancel()
		load_rewarded_ad()
	callbacks.on_ad_failed_to_show_full_screen_content=func(error: AdError) -> void:
		showing=false
		status="unavailable"
		push_warning("Revival ad failed to show: "+error.message)
		_destroy_rewarded_ad()
		_emit_cancel()
		load_rewarded_ad()
	rewarded_ad.full_screen_content_callback=callbacks

func show_reward_ad(for_purpose: String) -> bool:
	return show_revival_ad(for_purpose)

func _emit_reward() -> void:
	if purpose=="revive": revive_rewarded.emit()
	else: ad_rewarded.emit(purpose)

func _emit_cancel() -> void:
	if purpose=="revive": revive_cancelled.emit()
	else: ad_cancelled.emit(purpose)

func show_revival_ad(for_purpose:="revive") -> bool:
	if showing: return false
	purpose=for_purpose
	if OS.get_name()!="iOS":
		_show_desktop_preview()
		return true
	if not is_instance_valid(rewarded_ad):
		load_rewarded_ad()
		return false
	showing=true
	reward_earned=false
	reward_sent=false
	status="showing"
	var listener:=OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward=func(_rewarded_item: RewardedItem) -> void:
		reward_earned=true
	rewarded_ad.show(listener)
	return true

func _show_desktop_preview() -> void:
	showing=true
	status="showing"
	reward_earned=true
	reward_sent=true
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree(): return
	showing=false
	status="desktop"
	_emit_reward()

func _destroy_rewarded_ad() -> void:
	if is_instance_valid(rewarded_ad): rewarded_ad.destroy()
	rewarded_ad=null

func _exit_tree() -> void:
	_destroy_rewarded_ad()
