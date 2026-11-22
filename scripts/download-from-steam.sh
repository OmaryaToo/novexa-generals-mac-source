#!/usr/bin/env bash
# Downloads YOUR OWN Steam copies of Generals / Zero Hour (Windows depots) with Valve's SteamCMD.
# Password and Steam Guard code are typed directly into SteamCMD; this script never sees them.
set -e
command -v steamcmd >/dev/null || { echo "Install first: brew install --cask steamcmd"; exit 1; }
echo "Steam account name (from Steam > Settings > Account > Account name):"
read -r USERNAME
[[ -n "$USERNAME" && "$USERNAME" != "YOUR_USERNAME" ]] || { echo "Please type your real account name."; exit 1; }
echo
echo "Downloading Zero Hour (app 2732960) and Generals (app 2229870) into ~/Games ..."
echo "SteamCMD will ask for your password, then your Steam Guard code."
steamcmd +@sSteamCmdForcePlatformType windows \
  +force_install_dir "$HOME/Games/ZeroHour" +login "$USERNAME" +app_update 2732960 validate \
  +force_install_dir "$HOME/Games/Generals" +app_update 2229870 validate +quit
echo
echo "Done. .big archives found:"
find "$HOME/Games/ZeroHour" "$HOME/Games/Generals" -maxdepth 3 -iname "*.big" | head -40
