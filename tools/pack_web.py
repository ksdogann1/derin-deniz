"""Web dışa aktarımını (build/web) gzip'leyip res://webapp/ içine koyar.
Kurucu (Windows/Android) bu dosyaları aynı ağdaki tarayıcılara sunar.
Kullanım: python3 tools/pack_web.py  (önce Godot'ta "Web" dışa aktarımı yapılmalı)"""
import gzip, pathlib, shutil, sys
root = pathlib.Path(__file__).resolve().parent.parent
src = root / "build" / "web"
dst = root / "webapp"
if not (src / "index.html").exists():
    sys.exit("build/web/index.html yok; önce Web dışa aktarımı yap.")
shutil.rmtree(dst, ignore_errors=True)
dst.mkdir()
total = 0
# Ev ağında sayfa http:// ile açılır (https olamaz). Tek iş parçacıklı sürüm "güvenli bağlam"
# olmadan da çalışır; Godot'un bu kontrolünü sadece kurucunun sunduğu kopyada kaldırıyoruz.
OLD = "const missing = Engine.getMissingFeatures({\n\t\tthreads: GODOT_THREADS_ENABLED,\n\t});"
NEW = ("const missing = Engine.getMissingFeatures({\n\t\tthreads: GODOT_THREADS_ENABLED,\n\t})"
       ".filter((m) => !m.startsWith('Secure Context'));")
for f in sorted(src.iterdir()):
    if f.is_file():
        raw = f.read_bytes()
        if f.name == "index.html":
            text = raw.decode("utf-8")
            if OLD not in text:
                sys.exit("index.html beklenen biçimde değil (güvenli bağlam kontrolü bulunamadı)")
            # http'de AudioWorklet yok: eski ama her yerde çalışan ses sürücüsünü seç
            ARGS_OLD = 'GODOT_CONFIG = {"args":[]'
            ARGS_NEW = 'GODOT_CONFIG = {"args":["--audio-driver","ScriptProcessor"]'
            if ARGS_OLD not in text:
                sys.exit("index.html beklenen biçimde değil (GODOT_CONFIG args bulunamadı)")
            raw = text.replace(OLD, NEW).replace(ARGS_OLD, ARGS_NEW).encode("utf-8")
        if f.name == "index.js":
            text = raw.decode("utf-8")
            JS_OLD = "GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path)"
            JS_NEW = ("GodotAudio.audioPositionWorkletPromise=(ctx.audioWorklet?"
                      "ctx.audioWorklet.addModule(path):Promise.resolve())")
            if JS_OLD not in text:
                sys.exit("index.js beklenen biçimde değil (ses başlatma bulunamadı)")
            raw = text.replace(JS_OLD, JS_NEW).encode("utf-8")
        data = gzip.compress(raw, compresslevel=9, mtime=0)
        (dst / (f.name + ".gz")).write_bytes(data)
        total += len(data)
print("webapp hazır: %.1f MB" % (total / 1e6))
