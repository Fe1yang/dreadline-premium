import io

ROOT = r"C:\Users\user\Documents\kimi\tasks\2026-11-10\dreadline-premium"

# ---------------------------------------------------------------- rail: no check-in button
H = ROOT + r"\scripts\hud.gd"
h = io.open(H, encoding="utf-8").read()
old = '''		_side_button(game.SIDE_SIGNIN,"signin",ProgressCatalog.text(lang,"signin"),game.signin_available())'''
new = '''		# no daily handout in the buy-once build: coins come from playing
		if not game.premium_build():
			_side_button(game.SIDE_SIGNIN,"signin",ProgressCatalog.text(lang,"signin"),game.signin_available())'''
assert h.count(old) == 1, h.count(old)
h = h.replace(old, new, 1)
io.open(H, "w", encoding="utf-8", newline="\n").write(h)
print("check-in button hidden")

# ---------------------------------------------------------------- state unreachable
M = ROOT + r"\scripts\main_3d.gd"
m = io.open(M, encoding="utf-8").read()
old2 = "func open_signin() -> void:"
assert m.count(old2) == 1
m = m.replace(old2, '''func open_signin() -> void:
	if PREMIUM_BUILD:
		lobby_toast = 1.6
		lobby_toast_key = "coming"
		return''', 1)
io.open(M, "w", encoding="utf-8", newline="\n").write(m)
print("open_signin is a no-op in the premium build")
