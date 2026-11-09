extends Node
## R-01 cans are the run-energy currency. Natural recovery stops at CAP; purchased packs may
## deliberately overfill it so a large pack is never clipped by the natural energy limit.
signal changed

const CAP:=50
const RUN_COST:=10
const REGEN_SECONDS:=216  # 50 cans x 216s = 10800s: a full 3-hour refill from empty

var value:=CAP
var updated_at:=0

static func now() -> int:
	return int(Time.get_unix_time_from_system())

func _ready() -> void:
	if updated_at<=0: updated_at=now()
	refresh()

func _process(_delta: float) -> void:
	refresh()

## Returns how many cans were restored. The timestamp advances only by completed recovery steps,
## preserving partial progress while the app is closed. A full balance banks no recovery time.
func refresh(notify:=true) -> int:
	var current:=now()
	if updated_at<=0: updated_at=current
	if value>=CAP:
		updated_at=current
		return 0
	var elapsed:=maxi(0,current-updated_at)
	var gained: int=int(elapsed/REGEN_SECONDS)
	if gained<=0: return 0
	var before:=value
	value=mini(CAP,value+gained)
	updated_at=current if value>=CAP else updated_at+gained*REGEN_SECONDS
	if notify and value!=before: changed.emit()
	return value-before

## Spend exactly one run's energy. A failed check leaves both the balance and timer untouched.
var infinite := false   # set by main when the player owns "unlock all"


func consume() -> bool:
	refresh(false)
	if infinite:
		return true
	if value<RUN_COST: return false
	var was_full:=value>=CAP
	value-=RUN_COST
	if was_full: updated_at=now()
	changed.emit()
	return true

## Purchased cans can exceed CAP; recovery resumes only after the balance drops below it again.
func add(amount: int) -> void:
	if amount<=0: return
	refresh(false)
	value+=amount
	if value>=CAP: updated_at=now()
	changed.emit()

func seconds_to_next() -> int:
	if value>=CAP: return 0
	return maxi(0,REGEN_SECONDS-maxi(0,now()-updated_at)%REGEN_SECONDS)

## Seconds until the balance is back at CAP: the next can plus every can after it. A full (or
## overfilled) balance has nothing to wait for, so it returns 0 and the lobby hides the counter.
func seconds_to_full() -> int:
	if value>=CAP: return 0
	return seconds_to_next()+(CAP-value-1)*REGEN_SECONDS

func load_config(config: ConfigFile) -> void:
	value=maxi(0,int(config.get_value("wallet","cans",CAP)))
	updated_at=int(config.get_value("wallet","cans_updated",now()))
	refresh(false)

func save_config(config: ConfigFile) -> void:
	config.set_value("wallet","cans",value)
	config.set_value("wallet","cans_updated",updated_at)
