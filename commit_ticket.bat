@echo off
cd /d "%~dp0"
if not exist "Claude outputs" mkdir "Claude outputs"
(
git add scripts/main_3d.gd scripts/hud.gd scripts/lootbox_scene_3d.gd scripts/pickup_3d.gd scripts/weapon_crate_3d.gd assets/ui/currency/voucher.png
git -c user.name="Nightfall Studio" -c user.email=dev@nightfall.local commit -F "Claude outputs\commit_msg.txt"
git pull --rebase
git push
git log --oneline -3
git status --short
) > "Claude outputs\git_log.txt" 2>&1
