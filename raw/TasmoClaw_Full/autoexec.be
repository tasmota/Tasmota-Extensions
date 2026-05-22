do
import sys
def tcl_load_file(wd, name)
if size(wd) > 0
load(wd + name)
else
load(name)
end
end
var mem = tasmota.memory()
if !mem.contains("psram") && !mem.contains("psram_free")
print("TasmoClaw Full extension skipped: PSRAM is required. Install TasmoClaw Lite on this device.")
else
var wd = tasmota.wd
if size(wd) > 0
sys.path().push(wd)
end
tcl_load_file(wd, "tasmoclaw_util.be")
tcl_load_file(wd, "tasmoclaw_commands.be")
tcl_load_file(wd, "tasmoclaw_store.be")
tcl_load_file(wd, "tasmoclaw_tools.be")
tcl_load_file(wd, "tasmoclaw_llm.be")
tcl_load_file(wd, "tasmoclaw_ui.be")
tcl_load_file(wd, "tasmoclaw_prompt.be")
tcl_load_file(wd, "tasmoclaw.be")
if global.tasmoclaw_driver != nil
tasmota.add_extension(global.tasmoclaw_driver)
end
end
end
