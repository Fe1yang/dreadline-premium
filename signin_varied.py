import io

ROOT = r"C:\Users\user\Documents\kimi\tasks\2026-11-10\dreadline-premium"

# ---------------------------------------------------------------- 1) bring the check-in back
H = ROOT + r"\scripts\hud.gd"
h = io.open(H, encoding="utf-8").read()
old = '''		# no daily handout in the buy-once build: coins come from playing
		if not game.premium_build():
			_side_button(game.SIDE_SIGNIN,"signin",ProgressCatalog.text(lang,"signin"),game.signin_available())'''
new = '''		_side_button(game.SIDE_SIGNIN,"signin",ProgressCatalog.text(lang,"signin"),game.signin_available())'''
assert h.count(old) == 1, h.count(old)
h = h.replace(old, new, 1)
io.open(H, "w", encoding="utf-8", newline="\n").write(h)
print("check-in button restored")

M = ROOT + r"\scripts\main_3d.gd"
m = io.open(M, encoding="utf-8").read()
old2 = '''func open_signin() -> void:
	if PREMIUM_BUILD:
		lobby_toast = 1.6
		lobby_toast_key = "coming"
		return'''
assert m.count(old2) == 1
m = m.replace(old2, "func open_signin() -> void:", 1)

# ---------------------------------------------------------------- 2) varied rewards
PG = ROOT + r"\scripts\progress_catalog.gd"
p = io.open(PG, encoding="utf-8").read()

start = p.find("const SIGNIN:=[")
assert start > 0
end = p.find("\n\n", start)
assert end > start

weekly = '''const SIGNIN:=[
	{"silver":400,"coins":0,"vouchers":0},
	{"silver":0,"coins":0,"vouchers":1},
	{"silver":600,"coins":0,"vouchers":0},
	{"silver":0,"coins":120,"vouchers":0},
	{"silver":900,"coins":0,"vouchers":0},
	{"silver":0,"coins":0,"vouchers":2},
	{"silver":1500,"coins":300,"vouchers":1}]'''
p = p[:start] + weekly + p[end:]

# monthly: silver most days, coins on the 7/14/21 beats, vouchers spread out
if "const SIGNIN_MONTH" in p:
    mstart = p.find("const SIGNIN_MONTH:=[")
    mend = p.find("\n\n", mstart)
    rows = []
    for day in range(1, 31):
        silver = 300 + day * 45
        coins = 0
        vouchers = 0
        if day in (7, 14, 21):
            coins = 120 + day * 6
            vouchers = 1
        if day == 30:
            silver = 4000
            coins = 600
            vouchers = 3
        rows.append('{"silver":%d,"coins":%d,"vouchers":%d}' % (silver, coins, vouchers))
    p = p[:mstart] + "const SIGNIN_MONTH:=[\n\t" + ",".join(rows) + "]" + p[mend:]

io.open(PG, "w", encoding="utf-8", newline="\n").write(p)
print("weekly and monthly rewards are now mixed silver / voucher / coin days")

# ---------------------------------------------------------------- 3) silver actually pays out
old_claim = '''	_grant(int(r.coins)*times,int(r.vouchers)*times); return true'''
new_claim = '''	bank_silver += int(r.get("silver", 0)) * times
	_grant(int(r.get("coins", 0))*times,int(r.get("vouchers", 0))*times)
	return true'''
assert m.count(old_claim) == 1, m.count(old_claim)
m = m.replace(old_claim, new_claim, 1)

io.open(M, "w", encoding="utf-8", newline="\n").write(m)
print("claim pays silver as well")
