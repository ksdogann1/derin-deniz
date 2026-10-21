#!/usr/bin/env bash
# Tüm otomatik testleri çalıştırır. Kullanım:
#   GODOT=/yol/godot ./tests/run_all.sh
set -u
GODOT="${GODOT:-godot}"
PORT=7799
WORLD="test_ag_$$"
cd "$(dirname "$0")/.."
LOGDIR="$(mktemp -d)"
fail=0

echo "== Envanter mantığı"
"$GODOT" --headless --path . --script res://tests/inventory_test.gd | grep -E "FAIL|kontrol geçti" || fail=1
"$GODOT" --headless --path . --script res://tests/inventory_test.gd > /dev/null 2>&1 || fail=1

echo "== Yerel oynanış testi"
"$GODOT" --headless --path . --script res://tests/local_test.gd || fail=1

echo "== Özellik testi (görevler, ekipman, ayarlar, dokunmatik)"
"$GODOT" --headless --path . --script res://tests/feature_test.gd || fail=1

echo "== Ağ testi (sunucu + observer + actor + latejoin)"
"$GODOT" --headless --path . -- --server --port $PORT --world $WORLD > "$LOGDIR/server.log" 2>&1 &
SERVER=$!
sleep 4
"$GODOT" --headless --path . --script res://tests/client_test.gd -- --role observer --port $PORT > "$LOGDIR/observer.log" 2>&1 &
OBS=$!
sleep 2
"$GODOT" --headless --path . --script res://tests/client_test.gd -- --role actor --port $PORT > "$LOGDIR/actor.log" 2>&1 || fail=1
wait $OBS || fail=1
"$GODOT" --headless --path . --script res://tests/client_test.gd -- --role latejoin --port $PORT > "$LOGDIR/late.log" 2>&1 || fail=1
echo "== Takas testi (iki istemci)"
"$GODOT" --headless --path . -- --server --port 7801 --world "takas_$$" > "$LOGDIR/trade_server.log" 2>&1 &
TSERVER=$!
sleep 4
"$GODOT" --headless --path . --script res://tests/trade_test.gd -- --role b --port 7801 > "$LOGDIR/trade_b.log" 2>&1 &
TB=$!
"$GODOT" --headless --path . --script res://tests/trade_test.gd -- --role a --port 7801 > "$LOGDIR/trade_a.log" 2>&1 || fail=1
wait $TB || fail=1
kill $TSERVER 2>/dev/null
rm -f "$HOME/.local/share/DerinDeniz/worlds/takas_$$.dds"
grep -hE "takas-.*(FAIL|kontrol geçti)" "$LOGDIR"/trade_a.log "$LOGDIR"/trade_b.log

echo "== Bağlantı testleri (yerel ağ keşfi, sürüm kontrolü, zaman aşımı)"
"$GODOT" --headless --path . --script res://tests/discovery_test.gd -- --world $WORLD 2>&1 | grep -E "OK|FAIL" || fail=1
"$GODOT" --headless --path . --script res://tests/discovery_test.gd -- --world $WORLD > /dev/null 2>&1 || fail=1
"$GODOT" --headless --path . -- --join 127.0.0.1 --port $PORT --fakeversion 0.0.1 --quitafter 4 > "$LOGDIR/ver.log" 2>&1
if grep -q "Sürüm uyuşmuyor" "$LOGDIR/ver.log" && grep -q "dünyada: false" "$LOGDIR/ver.log"; then
  echo "OK    farklı sürüm açık mesajla reddedildi"; else echo "FAIL  sürüm kontrolü"; fail=1; fi
"$GODOT" --headless --path . -- --join 127.0.0.1 --port $PORT --quitafter 4 > "$LOGDIR/same.log" 2>&1
if grep -q "dünyada: true" "$LOGDIR/same.log" && ! grep -q "Sürüm uyuşmuyor" "$LOGDIR/same.log"; then
  echo "OK    aynı sürüm normal girdi"; else echo "FAIL  aynı sürüm girişi"; fail=1; fi
"$GODOT" --headless --path . -- --join 127.0.0.1 --port 7790 --quitafter 11 > "$LOGDIR/timeout.log" 2>&1
if grep -q "bağlanılamadı" "$LOGDIR/timeout.log"; then
  echo "OK    kapalı adrese bağlanınca açıklayıcı hata"; else echo "FAIL  zaman aşımı mesajı"; fail=1; fi

kill $SERVER 2>/dev/null
rm -f "$HOME/.local/share/DerinDeniz/worlds/$WORLD.dds"
grep -hE "OK|FAIL|kontrol geçti" "$LOGDIR"/actor.log "$LOGDIR"/observer.log "$LOGDIR"/late.log

if [ $fail -eq 0 ]; then echo "TÜM TESTLER GEÇTİ"; else echo "BAZI TESTLER BAŞARISIZ (loglar: $LOGDIR)"; fi
exit $fail
