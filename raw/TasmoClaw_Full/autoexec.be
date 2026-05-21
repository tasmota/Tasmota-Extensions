do
import sys
var mem = tasmota.memory()
if !mem.contains("psram") && !mem.contains("psram_free")
print("TasmoClaw Full extension skipped: PSRAM is required. Install TasmoClaw Lite on this device.")
else
var wd = tasmota.wd
if size(wd) > 0
sys.path().push(wd)
load(wd + "tasmoclaw.be")
sys.path().pop()
else
load("tasmoclaw.be")
end
if global.tasmoclaw_driver != nil
tasmota.add_extension(global.tasmoclaw_driver)
end
end
end
