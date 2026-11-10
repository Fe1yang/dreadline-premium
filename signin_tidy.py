import io

ROOT = r"C:\Users\user\Documents\kimi\tasks\2026-11-10\dreadline-premium"

# ---------------------------------------------------------------- tab geometry
M = ROOT + r"\scripts\main_3d.gd"
m = io.open(M, encoding="utf-8").read()
old = '''func signin_tab_rect(t: int) -> Rect2:
	return Rect2(56 + t * 220, 210, 208, 40)'''
new = '''func signin_tab_rect(t: int) -> Rect2:
	return Rect2(56 + t * 220, 214, 208, 46)'''
assert m.count(old) == 1, m.count(old)
m = m.replace(old, new, 1)
io.open(M, "w", encoding="utf-8", newline="\n").write(m)
print("tab buttons are 46 px tall")

# ---------------------------------------------------------------- hud: labels, no stray caption, day-7 icons
H = ROOT + r"\scripts\hud.gd"
h = io.open(H, encoding="utf-8").read()

old_caption = '''	_clean_center(font,Vector2(270,p.position.y+66),
		"SUPPLY CACHE · 30 DAYS" if game.signin_monthly else "SUPPLY CACHE · 7 DAYS",11,MUTED)
'''
assert h.count(old_caption) == 1, h.count(old_caption)
h = h.replace(old_caption, "", 1)

old_label = '''		_clean_center(bold, tr.get_center()+Vector2(0,6), tab_label, 17, WHITE if on else MUTED)'''
new_label = '''		_clean_center(bold, tr.get_center()+Vector2(0,7), tab_label, 16, WHITE if on else MUTED)'''
assert h.count(old_label) == 1, h.count(old_label)
h = h.replace(old_label, new_label, 1)

# day 7: same icon placement as every other tile, two rewards side by side
old_jack = '''			if jackpot:
				var half: float = r.size.x * 0.5
				clean_ops.append(["texture",coin_tex,Rect2(r.position+Vector2(half*0.5-24,r.position.y+38),Vector2(48,48))])
				clean_ops.append(["texture",voucher_tex,Rect2(r.position+Vector2(half*1.5-26,r.position.y+40),Vector2(52,44))])
				_clean_center(bold,Vector2(r.position.x+half*0.5,r.end.y-14),"%d"%int(reward.coins),17,BRASS_LIGHT)
				_clean_center(bold,Vector2(r.position.x+half*1.5,r.end.y-14),"×%d"%int(reward.vouchers),17,BRASS_LIGHT)'''
new_jack = '''			if jackpot:
				var half: float = r.size.x * 0.5
				var cy2: float = r.get_center().y - 4.0
				clean_ops.append(["texture",coin_tex,Rect2(Vector2(r.position.x+half*0.5-26,cy2-26),Vector2(52,52))])
				clean_ops.append(["texture",voucher_tex,Rect2(Vector2(r.position.x+half*1.5-26,cy2-22),Vector2(52,44))])
				_clean_center(bold,Vector2(r.position.x+half*0.5,r.end.y-14),"%d"%int(reward.coins),17,BRASS_LIGHT)
				_clean_center(bold,Vector2(r.position.x+half*1.5,r.end.y-14),"×%d"%int(reward.vouchers),17,BRASS_LIGHT)'''
assert h.count(old_jack) == 1, h.count(old_jack)
h = h.replace(old_jack, new_jack, 1)

io.open(H, "w", encoding="utf-8", newline="\n").write(h)
print("caption removed, labels centred, day-7 icons placed")
