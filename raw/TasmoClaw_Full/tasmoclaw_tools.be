import string
import path
import json
import introspect
var tasmoclaw_util = introspect.module('tasmoclaw_util')
var tasmoclaw_commands = introspect.module('tasmoclaw_commands')
class TasmoClawTools
var tool_defs, store
def init(store)
self.store = store
self.tool_defs = {
'tasmota_status':{'approval':false,'desc':'Read memory/wifi/arch/sensors and Status 0'},
'skill_list':{'approval':false,'desc':'List TasmoClaw capability skills and the currently active compact prompt skills'},
'skill_activate':{'approval':false,'desc':'Activate one or more compact prompt skills such as memory, automation, web, berry, files, or device'},
'skill_deactivate':{'approval':false,'desc':'Deactivate one or more compact prompt skills'},
'skill_reset':{'approval':false,'desc':'Reset active compact prompt skills to the default stock-compatible set'},
'memory_read':{'approval':false,'desc':'Read TasmoClaw local memory from FlashFS'},
'memory_search':{'approval':false,'desc':'Search TasmoClaw local memory files for a term'},
'memory_write':{'approval':true,'desc':'Write a TasmoClaw local memory file on FlashFS'},
'memory_append':{'approval':true,'desc':'Append a timestamped note to a TasmoClaw local memory file on FlashFS'},
'memory_forget':{'approval':true,'desc':'Delete a TasmoClaw local memory file'},
'profile_memory':{'approval':true,'desc':'Read or update the local profile/personality memory for room names, relay names, and user preferences'},
'agent_file_list':{'approval':false,'desc':'List TasmoClaw flash agent files AGENTS.md, SOUL.md, IDENTITY.md, USER.md, and MEMORY.md'},
'agent_file_read':{'approval':false,'desc':'Read one TasmoClaw flash agent file'},
'agent_file_write':{'approval':true,'desc':'Replace one TasmoClaw flash agent file'},
'agent_file_append':{'approval':true,'desc':'Append a short note to one TasmoClaw flash agent file. For MEMORY.md, prefer rewriting a small curated summary with agent_file_write.'},
'scheduler_list':{'approval':false,'desc':'List TasmoClaw schedules and runtime state'},
'scheduler_get':{'approval':false,'desc':'Get one TasmoClaw schedule by id'},
'scheduler_add':{'approval':true,'desc':'Add a once or interval schedule that emits router events'},
'scheduler_update':{'approval':true,'desc':'Update one TasmoClaw schedule'},
'scheduler_remove':{'approval':true,'desc':'Remove one TasmoClaw schedule'},
'scheduler_enable':{'approval':true,'desc':'Enable one TasmoClaw schedule'},
'scheduler_disable':{'approval':true,'desc':'Disable one TasmoClaw schedule'},
'scheduler_trigger_now':{'approval':true,'desc':'Trigger one schedule event immediately'},
'scheduler_tick':{'approval':false,'desc':'Run due schedules now; normally called by TasmoClaw every_second'},
'router_rule_list':{'approval':false,'desc':'List TasmoClaw event router rules'},
'router_rule_get':{'approval':false,'desc':'Get one TasmoClaw router rule by id'},
'router_rule_add':{'approval':true,'desc':'Add a router rule that maps events to tool or Tasmota command actions'},
'router_rule_update':{'approval':true,'desc':'Update a router rule'},
'router_rule_delete':{'approval':true,'desc':'Delete a router rule'},
'router_emit':{'approval':true,'desc':'Emit an event into the TasmoClaw router and run matching actions'},
'web_search':{'approval':false,'desc':'Search the web through direct Brave Search API'},
'http_bridge_call':{'approval':true,'desc':'Call a local/LAN/cloud HTTP endpoint with GET or POST as an MCP-lite bridge'},
'image_inspect':{'approval':false,'desc':'Ask an OpenAI-compatible vision endpoint to inspect an image URL'},
'device_doctor':{'approval':false,'desc':'Run a friendly device health check across heap, Wi-Fi, SD/UFS, I2C, sensors, rules, timers, display, and LVGL'},
'board_bringup_wizard':{'approval':false,'desc':'Check Waveshare ESP32-S3-RLCD-4.2 bring-up status: template clues, SD pins, I2C, UFS, display, LVGL, and sensors'},
'automation_builder':{'approval':true,'desc':'Build and apply common Tasmota automations from plain language, such as sunset light timers'},
'dashboard_create':{'approval':true,'desc':'Create a simple display status dashboard from live device state'},
'rule_explain':{'approval':false,'desc':'Read Tasmota rules and explain slots, triggers, actions, and possible cleanup hints'},
'tasmota_cmd_read':{'approval':false,'desc':'Run clearly read-only Tasmota command, including Rule1/Rule2/Rule3 reads. Rules is mapped to all rule slots.'},
'device_read':{'approval':false,'desc':'Read sensors, power state, filesystem/SD status, memory, and Wi-Fi in one compact call'},
'sensor_read':{'approval':false,'desc':'Read I2C scan and Status 8 sensor data'},
'power_read':{'approval':false,'desc':'Read Power, Power1, Power2, and Status 0 power state'},
'file_read':{'approval':false,'desc':'Read text file with byte limit from FlashFS. Stock Tasmota Berry cannot read SD file contents.'},
'file_list':{'approval':false,'desc':'List files. Supports sd:/path through stock UfsList and flash:/path through Berry path.listdir.'},
'ufs_info':{'approval':false,'desc':'Read Tasmota UFS/SD card filesystem type, size, free space, and root listing'},
'sd_markdown_list':{'approval':false,'desc':'List markdown files in the mounted SD card root'},
'berry_program_read':{'approval':false,'desc':'Read a Berry program file'},
'berry_program_explain':{'approval':false,'desc':'Read a Berry program so TasmoClaw can explain it'},
'berry_check':{'approval':false,'desc':'Check berry syntax availability'},
'command_catalog_search':{'approval':false,'desc':'Search TasmoClaw command families and examples before building an unfamiliar Tasmota command'},
'command_build':{'approval':false,'desc':'Build and safety-classify a Tasmota command from structured args without executing it'},
'command_run':{'approval':true,'desc':'Execute a safety-classified Tasmota command; read-only commands run without approval, actions/writes require approval'},
'command_sequence_run':{'approval':true,'desc':'Execute a sequence of built Tasmota commands in order; read-only sequences run without approval, mixed/action sequences require one approval'},
'tool_sequence_run':{'approval':true,'desc':'Execute several TasmoClaw tools/commands in order. Use for multi-step requests such as read sensors, read power, then toggle a relay.'},
'berry_module_probe':{'approval':false,'desc':'Probe available Berry modules/globals/libraries such as lv, display, path, persist, json, webserver, webclient, and tasmota'},
'webcolor_control':{'approval':true,'desc':'Read or set Tasmota WebColor palette. Reads are safe; palette/index changes require approval.'},
'lvgl_control':{'approval':true,'desc':'Probe LVGL/display availability or create a simple LVGL label/dashboard screen when LVGL is available'},
'display_control':{'approval':true,'desc':'Show text on the display using DisplayText'},
'power_control':{'approval':true,'desc':'Read, turn on/off, or toggle Power/Power1/Power2 channels with dynamic approval'},
'rule_control':{'approval':true,'desc':'Read, enable, disable, clear, or set Tasmota rules with dynamic approval'},
'light_control':{'approval':true,'desc':'Read or control Tasmota lights: on/off/toggle, dimmer, color, CT, white, scheme, fade, speed'},
'mqtt_control':{'approval':true,'desc':'Read MQTT config or publish MQTT messages with dynamic approval'},
'telemetry_control':{'approval':true,'desc':'Read or set TelePeriod and log levels such as WebLog, SerialLog, and SysLog'},
'network_control':{'approval':true,'desc':'Read or change Wi-Fi/network/time settings with dynamic approval'},
'system_control':{'approval':true,'desc':'Read state/status or run system Event, Backlog, module/template, restart when explicitly confirmed'},
'timer_control':{'approval':true,'desc':'Read or set Timers, TimerN, RuleTimerN, and PulseTimeN'},
'filesystem_control':{'approval':true,'desc':'Read UFS status/list files or run stock UFS file actions such as delete, rename, or run with approval'},
'file_copy':{'approval':true,'desc':'Copy a FlashFS text/binary-light file; SD content copy is unavailable on stock Berry'},
'file_move':{'approval':true,'desc':'Move/rename FlashFS files or use stock UFS rename for SD/FlashFS paths'},
'file_delete':{'approval':true,'desc':'Delete a FlashFS file or use stock UFS delete for SD paths'},
'script_list':{'approval':false,'desc':'List TasmoClaw Berry scripts in /tasmoclaw/scripts and /tasmoclaw/berry'},
'script_read':{'approval':false,'desc':'Read a TasmoClaw Berry script'},
'script_create':{'approval':true,'desc':'Create a TasmoClaw Berry script from content or a template'},
'script_run':{'approval':true,'desc':'Load and run a TasmoClaw Berry script'},
'tasmota_cmd':{'approval':true,'desc':'Execute Tasmota command'},
'file_write':{'approval':true,'desc':'Write FlashFS file content. Stock Tasmota Berry cannot write SD file contents.'},
'berry_program_write':{'approval':true,'desc':'Write a Berry program to /tasmoclaw/berry/ or the workspace fallback'},
'berry_program_run':{'approval':true,'desc':'Load and run a Berry program file'},
'berry_console':{'approval':true,'desc':'Run a short Berry one-liner through the Tasmota Br command after approval'},
'berry_skill_template':{'approval':false,'desc':'Return a reusable Berry command/skill template without writing it'},
'berry_skill_create':{'approval':true,'desc':'Create a reusable Berry skill file that registers a Tasmota command'},
'berry_skill_run':{'approval':true,'desc':'Load a Berry skill file so its command becomes available'},
'berry_skill_explain':{'approval':false,'desc':'Read a Berry skill file so TasmoClaw can explain how it works'},
'berry_load':{'approval':true,'desc':'load(path)'},
'berry_compile':{'approval':true,'desc':'tasmota.compile(path)'},
'rule_apply':{'approval':true,'desc':'Apply and optionally enable rule'},
'rule_clear':{'approval':true,'desc':'Disable and clear a rule slot'},
'display_message':{'approval':true,'desc':'DisplayText message'},
'create_demo_berry':{'approval':true,'desc':'Create demo Berry command file'}
}
end
def registry()
return self.tool_defs
end
def skill_catalog()
return {
'core':{'desc':'Core status, command safety, tool sequencing, and skill activation','tools':['skill_list','skill_activate','skill_deactivate','skill_reset','tasmota_status','tasmota_cmd_read','device_read','device_doctor','board_bringup_wizard','command_catalog_search','command_build','command_run','command_sequence_run','tool_sequence_run']},
'device':{'desc':'Sensors, power, rules, timers, display, LVGL, lights, MQTT, telemetry, and network','tools':['sensor_read','power_read','power_control','rule_control','rule_explain','timer_control','automation_builder','display_control','lvgl_control','dashboard_create','light_control','mqtt_control','telemetry_control','network_control','system_control','webcolor_control','berry_module_probe']},
'files':{'desc':'FlashFS and stock UFS/SD listing, status, delete, rename, copy/move helpers','tools':['file_read','file_write','file_list','ufs_info','sd_markdown_list','filesystem_control','file_copy','file_move','file_delete']},
'berry':{'desc':'Berry programs, reusable Berry skills, and script library','tools':['berry_program_read','berry_program_write','berry_program_run','berry_program_explain','berry_check','berry_console','berry_skill_template','berry_skill_create','berry_skill_run','berry_skill_explain','berry_load','berry_compile','script_list','script_read','script_create','script_run','rule_apply','rule_clear','display_message','create_demo_berry']},
'memory':{'desc':'Local FlashFS memory files and markdown agent identity/instruction files','tools':['memory_read','memory_search','memory_write','memory_append','memory_forget','profile_memory','agent_file_list','agent_file_read','agent_file_write','agent_file_append']},
'automation':{'desc':'Interval/once scheduler and event router rules','tools':['scheduler_list','scheduler_get','scheduler_add','scheduler_update','scheduler_remove','scheduler_enable','scheduler_disable','scheduler_trigger_now','scheduler_tick','router_rule_list','router_rule_get','router_rule_add','router_rule_update','router_rule_delete','router_emit']},
'web':{'desc':'Direct Brave web search, HTTP bridge, and OpenAI-compatible image inspection','tools':['web_search','http_bridge_call','image_inspect']}
}
end
def skill_defaults()
return ['core','device','files','berry','memory','automation','web']
end
def data_file(name)
return '/tasmoclaw/' + name
end
def load_json_file(file, fallback)
try
var raw = self.store.read_file(file)
if raw != nil && size(raw) > 0
return json.load(raw)
end
except .. as e,m
tasmoclaw_util.debug('load_json_file failed file=' + str(file) + ' error=' + str(m))
end
return fallback
end
def save_json_file(file, obj)
return self.store.write_file(file, tasmoclaw_util.json_encode(obj))
end
def skill_state()
var s = self.load_json_file(self.data_file('skills.json'), nil)
if s == nil || s.find('active') == nil
s = {'active':self.skill_defaults()}
end
return s
end
def active_skills()
var s = self.skill_state()
var a = s.find('active')
if a == nil
a = self.skill_defaults()
end
return a
end
def list_has(list_value, item)
if list_value == nil
return false
end
for v:list_value
if str(v) == str(item)
return true
end
end
return false
end
def skill_active(skill)
return self.list_has(self.active_skills(), skill)
end
def normalize_skill_list(value)
if value == nil
return []
end
if type(value) == 'list'
return value
end
if type(value) == 'string'
var s = string.replace(str(value), ',', ' ')
var out = []
for part:string.split(s, ' ')
if part != nil && part != ''
out.push(part)
end
end
return out
end
return [str(value)]
end
def skill_list(args)
return {'ok':true,'active':self.active_skills(),'catalog':self.skill_catalog()}
end
def save_active_skills(active)
var catalog = self.skill_catalog()
var clean = []
for s:active
var k = string.tolower(str(s))
if catalog.find(k) != nil && !self.list_has(clean, k)
clean.push(k)
end
end
if size(clean) == 0
clean = ['core']
end
var r = self.save_json_file(self.data_file('skills.json'), {'active':clean})
if r.find('ok') == true
return {'ok':true,'active':clean}
end
return r
end
def skill_activate(args)
var active = self.active_skills()
var add = self.normalize_skill_list(args.find('skill') == nil ? args.find('skills') : args.find('skill'))
if size(add) == 0
return {'ok':false,'error':'missing skill or skills'}
end
for s:add
var k = string.tolower(str(s))
if !self.list_has(active, k)
active.push(k)
end
end
return self.save_active_skills(active)
end
def skill_deactivate(args)
var remove = self.normalize_skill_list(args.find('skill') == nil ? args.find('skills') : args.find('skill'))
if size(remove) == 0
return {'ok':false,'error':'missing skill or skills'}
end
var out = []
for s:self.active_skills()
if !self.list_has(remove, s) || str(s) == 'core'
out.push(s)
end
end
return self.save_active_skills(out)
end
def skill_reset(args)
return self.save_active_skills(self.skill_defaults())
end
def tool_enabled_by_skills(tool)
var active = self.active_skills()
var cat = self.skill_catalog()
for s:cat.keys()
if self.list_has(active, s)
var tools = cat[s].find('tools')
if self.list_has(tools, tool)
return true
end
end
end
return false
end
def tool_lines()
var out = ''
for k:self.tool_defs.keys()
if self.tool_enabled_by_skills(k)
out += '- ' + k + ': ' + self.tool_defs[k]['desc'] + '\n'
end
end
return out
end
def tool_lines_compact()
var out = ''
out += '- skill_list/activate/deactivate/reset: inspect and activate TasmoClaw skill groups. Active skills: ' + str(self.active_skills()) + '\n'
if self.skill_active('core')
out += '- device_read, tasmota_status, tasmota_cmd_read: read status; command_catalog_search/build/run and sequences for fallback commands\n'
end
if self.skill_active('device')
out += '- sensor_read: temperature/humidity/ADC/I2C; power_read/control; rule_control; timer_control; DisplayText/LVGL/WebColor; light/MQTT/telemetry/network/system\n'
end
if self.skill_active('files')
out += '- file_list: sd:/ via stock UfsList and flash:/ via FlashFS; file_read/file_write FlashFS text only; ufs_info; file_copy/move/delete; filesystem_control for UFS delete/rename/run\n'
end
if self.skill_active('berry')
out += '- berry_program_* and berry_skill_*: read/write/run/explain Berry code; script_list/read/create/run for /tasmoclaw/scripts; berry_console/load/compile for approved code\n'
end
if self.skill_active('memory')
out += '- memory_read/search/write/append/forget: local FlashFS memory files. Default memory.md maps to /tasmoclaw/MEMORY.md; agent_file_list/read/write/append manages AGENTS.md, SOUL.md, IDENTITY.md, USER.md, MEMORY.md\n'
out += '  Keep MEMORY.md tiny and curated; prefer agent_file_write to replace it with a short stable summary instead of appending endlessly.\n'
end
if self.skill_active('automation')
out += '- scheduler_*: once/interval schedules emit router events; router_rule_* and router_emit route events to tools or Tasmota commands\n'
end
if self.skill_active('web')
out += '- web_search: direct Brave Search API with conservative result count; http_bridge_call: MCP-lite HTTP GET/POST; image_inspect: OpenAI-compatible vision over image_url\n'
end
return out
end
def requires_approval(name)
if self.tool_defs.find(name) != nil
return self.tool_defs[name]['approval']
end
return true
end
def with_family(args, family)
var out = {}
if args != nil
try
for k:args.keys()
out[k] = args[k]
end
except .. as e,m
end
end
out['family'] = family
return out
end
def built_command_requires_approval(args, family)
var a = self.with_family(args, family)
var b = tasmoclaw_commands.build(a)
if b.find('ok') == true
return b.find('safety') != 'read'
end
return true
end
def requires_approval_for(name, args)
if args == nil
args = {}
end
if name == 'command_run'
var b = tasmoclaw_commands.build(args)
if b.find('ok') == true
return b.find('safety') != 'read'
end
return true
elif name == 'command_sequence_run'
return self.sequence_requires_approval(args)
elif name == 'tool_sequence_run'
return self.tool_sequence_requires_approval(args)
elif name == 'power_control'
var action = args.find('action')
if action == nil || action == ''
action = 'read'
end
action = string.tolower(str(action))
return !(action == 'read' || action == 'status' || action == 'state')
elif name == 'rule_control'
var ra = args.find('action')
if ra == nil || ra == ''
ra = 'read'
end
ra = string.tolower(str(ra))
return !(ra == 'read' || ra == 'list' || ra == 'show' || ra == 'status')
elif name == 'light_control'
return self.built_command_requires_approval(args, 'light')
elif name == 'mqtt_control'
return self.built_command_requires_approval(args, 'mqtt')
elif name == 'telemetry_control'
return self.built_command_requires_approval(args, 'telemetry')
elif name == 'network_control'
return self.built_command_requires_approval(args, 'network')
elif name == 'system_control'
return self.built_command_requires_approval(args, 'system')
elif name == 'timer_control'
return self.built_command_requires_approval(args, 'timer')
elif name == 'filesystem_control'
return self.built_command_requires_approval(args, 'filesystem')
elif name == 'webcolor_control'
var wa = args.find('action')
if wa == nil || wa == ''
wa = 'read'
end
wa = string.tolower(str(wa))
return !(wa == 'read' || wa == 'status' || wa == 'show' || wa == 'get' || wa == 'dump')
elif name == 'lvgl_control'
var la = args.find('action')
if la == nil || la == ''
la = 'status'
end
la = string.tolower(str(la))
return !(la == 'read' || la == 'status' || la == 'probe' || la == 'info')
end
return self.requires_approval(name)
end
def get_command_arg(args)
var c = args.find('command')
if c == nil || c == '' c = args.find('cmd') end
if c == nil || c == '' c = args.find('cmnd') end
return c
end
def arg_key_summary(args)
if args == nil
return ''
end
var out = ''
try
for k:args.keys()
if out != ''
out += ','
end
out += str(k)
end
except .. as e,m
end
return out
end
def run(name, args)
tasmoclaw_util.debug('tool run start name=' + str(name) + ' arg_keys=' + self.arg_key_summary(args))
var r = nil
try
r = self.run_inner(name, args)
except .. as e,m
r = {'ok':false,'error':'tool exception: '+str(m),'exception':str(e)}
tasmoclaw_util.debug('tool run exception name=' + str(name) + ' exception=' + str(e) + ' message=' + str(m))
end
var has_ok_field = false
try
has_ok_field = r.find('ok') != nil
except .. as e2,m2
has_ok_field = false
end
if r == nil
r = {'ok':false,'error':'tool returned nil'}
elif !has_ok_field
r = {'ok':true,'result':r}
end
tasmoclaw_util.debug('tool run done name=' + str(name) + ' ok=' + str(r.find('ok')) + ' error=' + str(r.find('error')) + ' command=' + str(r.find('command')))
return r
end
def run_inner(name, args)
if args == nil
args = {}
end
if name=='tasmota_status' return self.run_status(args) end
if name=='skill_list' return self.skill_list(args) end
if name=='skill_activate' return self.skill_activate(args) end
if name=='skill_deactivate' return self.skill_deactivate(args) end
if name=='skill_reset' return self.skill_reset(args) end
if name=='memory_read' return self.memory_read(args) end
if name=='memory_search' return self.memory_search(args) end
if name=='memory_write' return self.memory_write(args) end
if name=='memory_append' return self.memory_append(args) end
if name=='memory_forget' return self.memory_forget(args) end
if name=='profile_memory' return self.profile_memory(args) end
if name=='agent_file_list' return self.agent_file_list(args) end
if name=='agent_file_read' return self.agent_file_read(args) end
if name=='agent_file_write' return self.agent_file_write(args) end
if name=='agent_file_append' return self.agent_file_append(args) end
if name=='scheduler_list' return self.scheduler_list(args) end
if name=='scheduler_get' return self.scheduler_get(args) end
if name=='scheduler_add' return self.scheduler_add(args) end
if name=='scheduler_update' return self.scheduler_update(args) end
if name=='scheduler_remove' return self.scheduler_remove(args) end
if name=='scheduler_enable' return self.scheduler_enable(args) end
if name=='scheduler_disable' return self.scheduler_disable(args) end
if name=='scheduler_trigger_now' return self.scheduler_trigger_now(args) end
if name=='scheduler_tick' return self.scheduler_tick(args) end
if name=='router_rule_list' return self.router_rule_list(args) end
if name=='router_rule_get' return self.router_rule_get(args) end
if name=='router_rule_add' return self.router_rule_add(args) end
if name=='router_rule_update' return self.router_rule_update(args) end
if name=='router_rule_delete' return self.router_rule_delete(args) end
if name=='router_emit' return self.router_emit(args) end
if name=='web_search' return self.web_search(args) end
if name=='http_bridge_call' return self.http_bridge_call(args) end
if name=='image_inspect' return self.image_inspect(args) end
if name=='device_doctor' return self.device_doctor(args) end
if name=='board_bringup_wizard' return self.board_bringup_wizard(args) end
if name=='automation_builder' return self.automation_builder(args) end
if name=='dashboard_create' return self.dashboard_create(args) end
if name=='rule_explain' return self.rule_explain(args) end
if name=='tasmota_cmd_read' return self.run_cmd_read(args) end
if name=='device_read' return self.device_read(args) end
if name=='sensor_read' return self.sensor_read(args) end
if name=='power_read' return self.power_read(args) end
if name=='file_read' return self.file_read(args) end
if name=='file_list' return self.file_list(args) end
if name=='ufs_info' return self.ufs_info(args) end
if name=='sd_markdown_list' return self.sd_markdown_list(args) end
if name=='berry_program_read' return self.berry_program_read(args) end
if name=='berry_program_explain' return self.berry_program_explain(args) end
if name=='berry_check' return {'ok':true,'result':'syntax-check requires compile approval on this build'} end
if name=='command_catalog_search' return self.command_catalog_search(args) end
if name=='command_build' return self.command_build(args) end
if name=='command_run' return self.command_run(args) end
if name=='command_sequence_run' return self.command_sequence_run(args) end
if name=='tool_sequence_run' return self.tool_sequence_run(args) end
if name=='berry_module_probe' return self.berry_module_probe(args) end
if name=='webcolor_control' return self.webcolor_control(args) end
if name=='lvgl_control' return self.lvgl_control(args) end
if name=='display_control' return self.display_control(args) end
if name=='power_control' return self.power_control(args) end
if name=='rule_control' return self.rule_control(args) end
if name=='light_control' return self.light_control(args) end
if name=='mqtt_control' return self.mqtt_control(args) end
if name=='telemetry_control' return self.telemetry_control(args) end
if name=='network_control' return self.network_control(args) end
if name=='system_control' return self.system_control(args) end
if name=='timer_control' return self.timer_control(args) end
if name=='filesystem_control' return self.filesystem_control(args) end
if name=='file_copy' return self.file_copy(args) end
if name=='file_move' return self.file_move(args) end
if name=='file_delete' return self.file_delete(args) end
if name=='script_list' return self.script_list(args) end
if name=='script_read' return self.script_read(args) end
if name=='script_create' return self.script_create(args) end
if name=='script_run' return self.script_run(args) end
if name=='tasmota_cmd' return self.tasmota_cmd(args) end
if name=='file_write' return self.file_write(args) end
if name=='berry_program_write' return self.berry_program_write(args) end
if name=='berry_program_run' return self.berry_program_run(args) end
if name=='berry_console' return self.berry_console(args) end
if name=='berry_skill_template' return self.berry_skill_template(args) end
if name=='berry_skill_create' return self.berry_skill_create(args) end
if name=='berry_skill_run' return self.berry_skill_run(args) end
if name=='berry_skill_explain' return self.berry_skill_explain(args) end
if name=='berry_load' return self.berry_load(args) end
if name=='berry_compile' return self.berry_compile(args) end
if name=='rule_apply' return self.rule_apply(args) end
if name=='rule_clear' return self.rule_clear(args) end
if name=='display_message' return self.display_message(args) end
if name=='create_demo_berry' return self.create_demo_berry(args) end
return {'ok':false,'error':'Unknown tool: ' + name}
end
def normalize_name(name, ext)
if name == nil || name == ''
name = 'memory'
end
var n = str(name)
n = string.replace(n, '/', '_')
n = string.replace(n, '\\', '_')
n = string.replace(n, ' ', '_')
n = string.replace(n, '..', '_')
var has_dot = string.find(n, '.')
if ext == '.md' && has_dot != nil && has_dot >= 0
return n
end
var ei = string.find(n, ext)
if ei == nil || ei < 0 || ei != size(n) - size(ext)
n += ext
end
return n
end
def sd_mounted()
try
var r = tasmota.cmd('UfsType', true)
var t = r.find('UfsType')
if t == 1
return true
end
var ts = str(t)
if string.find(ts, '1') != nil && string.find(ts, '1') >= 0
return true
end
except .. as e,m
end
return false
end
def has_fs_prefix(p)
if p == nil
return false
end
var l = string.tolower(str(p))
var sd = string.find(l, 'sd:')
var flash = string.find(l, 'flash:')
return (sd != nil && sd == 0) || (flash != nil && flash == 0)
end
def fs_prefix_kind(p)
if p == nil
return ''
end
var l = string.tolower(str(p))
var sd = string.find(l, 'sd:')
if sd != nil && sd == 0
return 'sd'
end
var flash = string.find(l, 'flash:')
if flash != nil && flash == 0
return 'flash'
end
return ''
end
def strip_fs_prefix(p)
if p == nil || p == ''
return '/'
end
var kind = self.fs_prefix_kind(p)
if kind == ''
return p
end
var out = p
if kind == 'sd'
if size(p) <= 3
return '/'
end
out = p[3..size(p)-1]
elif kind == 'flash'
if size(p) <= 6
return '/'
end
out = p[6..size(p)-1]
end
if out == ''
out = '/'
end
if out[0..0] != '/'
out = '/' + out
end
return out
end
def stock_sd_file_error(action, p)
var fp = self.strip_fs_prefix(p)
var download = '/ufsd?fs=sd&download=' + self.url_arg(fp)
return {
'ok':false,
'error':'Stock Tasmota does not expose SD file '+action+' to Berry. TasmoClaw can use stock UFS status/list/delete/rename, but SD file content read/write needs the Tasmota web file manager from a browser or host.',
'path':fp,
'requested_path':p,
'fs':'sd',
'stock_firmware':true,
'stock_web':{
'read':'GET ' + download,
'write':'POST /ufse with form fields fs=sd, name=' + fp + ', content=<text> and a valid Referer header'
}
}
end
def url_arg(v)
if v == nil
return ''
end
try
return webclient.url_encode(str(v))
except .. as e,m
end
return str(v)
end
def now_seconds()
try
var r = tasmota.rtc()
var u = r.find('utc')
if u == nil
u = r.find('local')
end
if type(u) == 'int' || type(u) == 'real'
return int(u)
end
except .. as e,m
end
return 0
end
def first_value(args, keys, fallback)
if args != nil
for k:keys
var v = args.find(k)
if v != nil
return v
end
end
end
return fallback
end
def safe_memory_name(name)
var n = self.normalize_name(name, '.md')
n = string.replace(n, '/', '_')
n = string.replace(n, '\\', '_')
if n == '.md'
n = 'memory.md'
end
return n
end
def memory_path(args)
var name = self.first_value(args, ['name','file','path'], 'memory.md')
var n = self.safe_memory_name(name)
if string.tolower(n) == 'memory.md' && self.store != nil
var ap = self.store.agent_file_path('MEMORY.md')
if ap != nil
return ap
end
end
if self.store != nil && self.store.workspace_fallback
return '/' + n
end
return '/tasmoclaw/memory/' + n
end
def memory_read(args)
var p = self.memory_path(args)
var maxb = self.first_value(args, ['max_bytes','limit'], 8192)
return self.file_read({'path':'flash:' + p,'max_bytes':maxb})
end
def memory_write(args)
var p = self.memory_path(args)
var content = self.first_value(args, ['content','text','body'], '')
return self.file_write({'path':'flash:' + p,'content':content})
end
def memory_append(args)
var p = self.memory_path(args)
var note = self.first_value(args, ['content','text','note','body'], '')
if note == nil || note == ''
return {'ok':false,'error':'missing note/content'}
end
var existing = ''
var rr = self.file_read({'path':'flash:' + p,'max_bytes':12000})
if rr.find('ok') == true
existing = str(rr.find('result'))
end
var stamp = str(self.now_seconds())
var sep = existing == '' ? '' : '\n'
return self.file_write({'path':'flash:' + p,'content':existing + sep + '- ' + stamp + ': ' + str(note) + '\n'})
end
def memory_forget(args)
var p = self.memory_path(args)
return self.file_delete({'path':'flash:' + p})
end
def memory_search(args)
var q = string.tolower(str(self.first_value(args, ['query','q','text'], '')))
if q == ''
return {'ok':false,'error':'missing query'}
end
var base = self.store != nil && self.store.workspace_fallback ? '/' : '/tasmoclaw/memory'
var entries = []
try
entries = path.listdir(base)
except .. as e,m
return {'ok':false,'error':'memory list failed: '+str(m),'path':base}
end
var hits = []
if self.store != nil
var mp = self.store.agent_file_path('MEMORY.md')
if mp != nil
var mr = self.file_read({'path':'flash:' + mp,'max_bytes':12000})
if mr.find('ok') == true
var mbody = str(mr.find('result'))
var mlower = string.tolower(mbody)
var mpi = string.find(mlower, q)
if mpi != nil && mpi >= 0
hits.push({'path':mp,'preview':tasmoclaw_util.preview(mbody, 500)})
end
end
end
end
for item:entries
var name = type(item) == 'string' ? item : str(item[0])
if string.find(name, '.md') != nil && string.find(name, '.md') >= 0
var fp = base + '/' + name
if base == '/'
fp = '/' + name
end
var r = self.file_read({'path':'flash:' + fp,'max_bytes':12000})
if r.find('ok') == true
var body = str(r.find('result'))
var lower = string.tolower(body)
var pi = string.find(lower, q)
if pi != nil && pi >= 0
hits.push({'path':fp,'preview':tasmoclaw_util.preview(body, 500)})
end
end
end
end
return {'ok':true,'query':q,'hits':hits,'count':size(hits)}
end
def profile_memory(args)
if args == nil
args = {}
end
var action = string.tolower(str(self.first_value(args, ['action','mode'], 'read')))
var name = self.first_value(args, ['name','file'], 'profile.md')
if name == nil || name == ''
name = 'profile.md'
end
if action == 'read' || action == 'show' || action == 'get'
return self.memory_read({'name':name})
end
var content = self.first_value(args, ['content','text','note','value'], '')
if content == ''
content = 'Board profile note.'
end
if action == 'write' || action == 'set' || action == 'replace'
return self.memory_write({'name':name,'content':content})
end
if action == 'forget' || action == 'delete' || action == 'clear'
return self.memory_forget({'name':name})
end
return self.memory_append({'name':name,'content':content})
end
def agent_file_path(args)
if self.store == nil
return nil
end
var name = self.first_value(args, ['name','file','path'], 'MEMORY.md')
return self.store.agent_file_path(name)
end
def agent_file_list(args)
var files = []
if self.store == nil
return {'ok':false,'error':'store unavailable'}
end
self.store.ensure_agent_files()
for name:self.store.agent_file_names()
var p = self.store.agent_file_path(name)
var byte_count = 0
if p != nil
try
var raw = self.store.read_file(p)
if raw != nil
byte_count = size(raw)
end
except .. as e,m
end
end
files.push({'name':name,'path':p,'bytes':byte_count})
end
return {'ok':true,'files':files}
end
def agent_file_read(args)
var p = self.agent_file_path(args)
if p == nil
return {'ok':false,'error':'unknown agent file; use AGENTS.md, SOUL.md, IDENTITY.md, USER.md, or MEMORY.md'}
end
var maxb = self.first_value(args, ['max_bytes','limit'], 8192)
return self.file_read({'path':'flash:' + p,'max_bytes':maxb})
end
def agent_file_write(args)
var p = self.agent_file_path(args)
if p == nil
return {'ok':false,'error':'unknown agent file; use AGENTS.md, SOUL.md, IDENTITY.md, USER.md, or MEMORY.md'}
end
var content = self.first_value(args, ['content','text','body'], '')
return self.file_write({'path':'flash:' + p,'content':content})
end
def agent_file_append(args)
var p = self.agent_file_path(args)
if p == nil
return {'ok':false,'error':'unknown agent file; use AGENTS.md, SOUL.md, IDENTITY.md, USER.md, or MEMORY.md'}
end
var note = self.first_value(args, ['content','text','note','body'], '')
if note == nil || note == ''
return {'ok':false,'error':'missing note/content'}
end
var existing = ''
var rr = self.file_read({'path':'flash:' + p,'max_bytes':12000})
if rr.find('ok') == true
existing = str(rr.find('result'))
end
var sep = existing == '' ? '' : '\n\n'
return self.file_write({'path':'flash:' + p,'content':existing + sep + '- ' + str(self.now_seconds()) + ': ' + str(note) + '\n'})
end
def schedule_file()
return self.data_file('schedules.json')
end
def load_schedules()
var obj = self.load_json_file(self.schedule_file(), {'schedules':[]})
if obj == nil || obj.find('schedules') == nil
obj = {'schedules':[]}
end
return obj
end
def save_schedules(obj)
return self.save_json_file(self.schedule_file(), obj)
end
def find_schedule_index(obj, id)
var i = 0
for s:obj.find('schedules')
if str(s.find('id')) == str(id)
return i
end
i += 1
end
return -1
end
def normalize_schedule(args, existing)
var s = {}
if existing != nil
for k:existing.keys()
s[k] = existing[k]
end
end
for k:args.keys()
s[k] = args[k]
end
if s.find('id') == nil || s.find('id') == ''
return {'ok':false,'error':'missing id'}
end
var kind = string.tolower(str(s.find('kind') == nil ? s.find('type') : s.find('kind')))
if kind == nil || kind == '' || kind == 'nil'
kind = 'interval'
end
if kind != 'once' && kind != 'interval'
return {'ok':false,'error':'only once and interval schedules are supported in stock TasmoClaw'}
end
s['kind'] = kind
if s.find('enabled') != false
s['enabled'] = true
end
if s.find('event_type') == nil || s.find('event_type') == ''
s['event_type'] = 'schedule'
end
if s.find('event_key') == nil || s.find('event_key') == ''
s['event_key'] = s.find('id')
end
if s.find('text') == nil
s['text'] = ''
end
if s.find('payload') == nil
s['payload'] = {}
end
var now = self.now_seconds()
if kind == 'interval'
var interval = s.find('interval_s')
if interval == nil
interval = s.find('seconds')
end
if interval == nil || int(interval) < 5
return {'ok':false,'error':'interval schedules need interval_s >= 5'}
end
s['interval_s'] = int(interval)
if s.find('next_due') == nil || int(s.find('next_due')) <= now
s['next_due'] = now + int(interval)
end
else
var at = s.find('due_at')
if at == nil
at = s.find('start_at')
end
if at == nil || int(at) <= 0
return {'ok':false,'error':'once schedules need due_at epoch seconds'}
end
s['due_at'] = int(at)
s['next_due'] = int(at)
end
if s.find('run_count') == nil
s['run_count'] = 0
end
return {'ok':true,'schedule':s}
end
def scheduler_list(args)
var obj = self.load_schedules()
return {'ok':true,'schedules':obj.find('schedules'),'now':self.now_seconds()}
end
def scheduler_get(args)
var id = args.find('id')
var obj = self.load_schedules()
var idx = self.find_schedule_index(obj, id)
if idx < 0
return {'ok':false,'error':'schedule not found','id':id}
end
return {'ok':true,'schedule':obj.find('schedules')[idx],'now':self.now_seconds()}
end
def scheduler_add(args)
var obj = self.load_schedules()
if self.find_schedule_index(obj, args.find('id')) >= 0
return {'ok':false,'error':'schedule id already exists; use scheduler_update','id':args.find('id')}
end
var nr = self.normalize_schedule(args, nil)
if nr.find('ok') != true
return nr
end
obj.find('schedules').push(nr.find('schedule'))
var wr = self.save_schedules(obj)
if wr.find('ok') == true
return {'ok':true,'schedule':nr.find('schedule')}
end
return wr
end
def scheduler_update(args)
var obj = self.load_schedules()
var idx = self.find_schedule_index(obj, args.find('id'))
if idx < 0
return {'ok':false,'error':'schedule id not found; use scheduler_add','id':args.find('id')}
end
var nr = self.normalize_schedule(args, obj.find('schedules')[idx])
if nr.find('ok') != true
return nr
end
obj.find('schedules')[idx] = nr.find('schedule')
var wr = self.save_schedules(obj)
if wr.find('ok') == true
return {'ok':true,'schedule':nr.find('schedule')}
end
return wr
end
def scheduler_remove(args)
var obj = self.load_schedules()
var idx = self.find_schedule_index(obj, args.find('id'))
if idx < 0
return {'ok':false,'error':'schedule not found','id':args.find('id')}
end
var old = obj.find('schedules')[idx]
obj.find('schedules').remove(idx)
var wr = self.save_schedules(obj)
if wr.find('ok') == true
return {'ok':true,'removed':old}
end
return wr
end
def scheduler_set_enabled(args, enabled)
var obj = self.load_schedules()
var idx = self.find_schedule_index(obj, args.find('id'))
if idx < 0
return {'ok':false,'error':'schedule not found','id':args.find('id')}
end
obj.find('schedules')[idx]['enabled'] = enabled
var wr = self.save_schedules(obj)
if wr.find('ok') == true
return {'ok':true,'schedule':obj.find('schedules')[idx]}
end
return wr
end
def scheduler_enable(args)
return self.scheduler_set_enabled(args, true)
end
def scheduler_disable(args)
return self.scheduler_set_enabled(args, false)
end
def schedule_event(s)
return {
'event_type':s.find('event_type'),
'event_key':s.find('event_key'),
'source':'scheduler',
'text':s.find('text'),
'schedule_id':s.find('id'),
'payload':s.find('payload'),
'run_count':s.find('run_count')
}
end
def scheduler_trigger_now(args)
var gr = self.scheduler_get(args)
if gr.find('ok') != true
return gr
end
var ev = self.schedule_event(gr.find('schedule'))
var rr = self.router_emit(ev)
return {'ok':true,'event':ev,'router':rr}
end
def scheduler_tick(args)
var now = self.now_seconds()
if now <= 0
return {'ok':true,'fired':0,'reason':'clock not synchronized','now':now}
end
var obj = self.load_schedules()
var fired = []
var changed = false
for s:obj.find('schedules')
if s.find('enabled') == true && s.find('next_due') != nil && int(s.find('next_due')) <= now
s['run_count'] = int(s.find('run_count') == nil ? 0 : s.find('run_count')) + 1
var ev = self.schedule_event(s)
ev['planned_time'] = s.find('next_due')
ev['fire_time'] = now
var rr = self.router_emit(ev)
fired.push({'id':s.find('id'),'event':ev,'router':rr})
changed = true
if s.find('kind') == 'interval'
s['next_due'] = now + int(s.find('interval_s'))
else
s['enabled'] = false
end
end
end
if changed
self.save_schedules(obj)
end
return {'ok':true,'fired':size(fired),'results':fired,'now':now}
end
def router_file()
return self.data_file('router_rules.json')
end
def load_router_rules()
var obj = self.load_json_file(self.router_file(), {'rules':[]})
if obj == nil || obj.find('rules') == nil
obj = {'rules':[]}
end
return obj
end
def save_router_rules(obj)
return self.save_json_file(self.router_file(), obj)
end
def find_router_rule_index(obj, id)
var i = 0
for r:obj.find('rules')
if str(r.find('id')) == str(id)
return i
end
i += 1
end
return -1
end
def router_rule_list(args)
return {'ok':true,'rules':self.load_router_rules().find('rules')}
end
def router_rule_get(args)
var obj = self.load_router_rules()
var idx = self.find_router_rule_index(obj, args.find('id'))
if idx < 0
return {'ok':false,'error':'router rule not found','id':args.find('id')}
end
return {'ok':true,'rule':obj.find('rules')[idx]}
end
def normalize_router_rule(args)
var rule = args.find('rule')
if rule == nil
var rjson = args.find('rule_json')
if rjson != nil
try
rule = json.load(str(rjson))
except .. as e,m
return {'ok':false,'error':'rule_json parse failed: '+str(m)}
end
end
end
if rule == nil
rule = {}
for k:args.keys()
rule[k] = args[k]
end
end
if rule.find('id') == nil || rule.find('id') == ''
return {'ok':false,'error':'missing router rule id'}
end
if rule.find('match') == nil
rule['match'] = {'event_type':rule.find('event_type') == nil ? 'schedule' : rule.find('event_type')}
end
if rule.find('actions') == nil
return {'ok':false,'error':'missing actions'}
end
if rule.find('enabled') != false
rule['enabled'] = true
end
return {'ok':true,'rule':rule}
end
def router_rule_add(args)
var obj = self.load_router_rules()
var nr = self.normalize_router_rule(args)
if nr.find('ok') != true
return nr
end
var rule = nr.find('rule')
if self.find_router_rule_index(obj, rule.find('id')) >= 0
return {'ok':false,'error':'router rule id already exists; use router_rule_update','id':rule.find('id')}
end
obj.find('rules').push(rule)
var wr = self.save_router_rules(obj)
if wr.find('ok') == true
return {'ok':true,'rule':rule}
end
return wr
end
def router_rule_update(args)
var obj = self.load_router_rules()
var nr = self.normalize_router_rule(args)
if nr.find('ok') != true
return nr
end
var rule = nr.find('rule')
var idx = self.find_router_rule_index(obj, rule.find('id'))
if idx < 0
return {'ok':false,'error':'router rule id not found; use router_rule_add','id':rule.find('id')}
end
obj.find('rules')[idx] = rule
var wr = self.save_router_rules(obj)
if wr.find('ok') == true
return {'ok':true,'rule':rule}
end
return wr
end
def router_rule_delete(args)
var obj = self.load_router_rules()
var idx = self.find_router_rule_index(obj, args.find('id'))
if idx < 0
return {'ok':false,'error':'router rule not found','id':args.find('id')}
end
var old = obj.find('rules')[idx]
obj.find('rules').remove(idx)
var wr = self.save_router_rules(obj)
if wr.find('ok') == true
return {'ok':true,'removed':old}
end
return wr
end
def router_matches(rule, event)
if rule.find('enabled') == false
return false
end
var m = rule.find('match')
if m == nil
return true
end
for k:m.keys()
var want = m.find(k)
if want != nil && want != ''
var got = event.find(k)
if got == nil
return false
end
if str(got) != str(want)
return false
end
end
end
return true
end
def router_render(v, event)
if v == nil
return ''
end
var s = str(v)
for k:event.keys()
s = string.replace(s, '{{event.' + str(k) + '}}', str(event[k]))
end
return s
end
def router_run_action(action, event)
var t = string.tolower(str(action.find('type') == nil ? action.find('action') : action.find('type')))
if t == 'call_tool' || t == 'tool'
var tool = action.find('tool')
if tool == nil
tool = action.find('cap')
end
var tool_args = action.find('input')
if tool_args == nil
tool_args = action.find('args')
end
if tool_args == nil
tool_args = {}
end
return self.run(str(tool), tool_args)
elif t == 'command' || t == 'tasmota_cmd'
var command = self.router_render(action.find('command'), event)
return self.tasmota_cmd({'command':command})
elif t == 'display'
return self.display_control({'message':self.router_render(action.find('message'), event)})
elif t == 'memory_append'
return self.memory_append({'name':action.find('name'),'content':self.router_render(action.find('content') == nil ? action.find('message') : action.find('content'), event)})
elif t == 'emit_event'
var ev = action.find('event')
if ev == nil
ev = action.find('input')
end
if ev == nil
return {'ok':false,'error':'emit_event missing event/input'}
end
return self.router_emit(ev)
elif t == 'drop'
return {'ok':true,'dropped':true}
end
return {'ok':false,'error':'unsupported router action type: '+str(t)}
end
def router_emit(args)
var event = args.find('event')
if event == nil
event = args
end
if event.find('event_type') == nil
event['event_type'] = 'manual'
end
var obj = self.load_router_rules()
var matched = []
for rule:obj.find('rules')
if self.router_matches(rule, event)
var actions = rule.find('actions')
var results = []
if actions != nil
for a:actions
results.push(self.router_run_action(a, event))
end
end
matched.push({'id':rule.find('id'),'results':results})
end
end
return {'ok':true,'event':event,'matched':matched,'count':size(matched)}
end
def http_get(url, headers)
if string.find(str(url), 'http://') == 0
var tcp_r = self.http_get_tcp(url, headers)
if tcp_r.find('ok') == true
return tcp_r
end
tasmoclaw_util.debug('tcpclient HTTP GET fallback failed status=' + str(tcp_r.find('status')) + ' error=' + str(tcp_r.find('error')))
end
var cl = nil
try
cl = webclient()
cl.begin(url)
try cl.set_timeouts(15000, 8000) except .. as e_to,m_to end
var use_http10 = true
if headers != nil && headers.find('_http10') == false
use_http10 = false
end
if use_http10
try cl.use_http10(true) except .. as e_http,m_http end
end
var default_headers = true
if headers != nil && headers.find('_no_default_headers') == true
default_headers = false
end
if default_headers
cl.add_header('Accept','application/json,text/plain,*/*')
cl.add_header('Connection','close')
cl.add_header('User-Agent','TasmoClaw/0.1')
end
if headers != nil
for k:headers.keys()
var ks = str(k)
if size(ks) == 0 || ks[0..0] != '_'
cl.add_header(k, str(headers[k]))
end
end
end
var code = cl.GET()
var body = cl.get_string()
cl.close()
return {'ok':code >= 200 && code < 300,'status':code,'body':body}
except .. as e,m
try cl.close() except .. as e2,m2 end
return {'ok':false,'error':'HTTP GET failed: '+str(m)}
end
end
def http_get_tcp(url, headers)
var s = str(url)
var prefix = 'http://'
if string.find(s, prefix) != 0
return {'ok':false,'status':-1,'error':'tcpclient GET supports plain HTTP only','transport':'tcpclient'}
end
var rest = s[size(prefix) ..]
var slash = string.find(rest, '/')
var authority = rest
var path_q = '/'
if slash != nil && slash >= 0
authority = rest[0 .. slash - 1]
path_q = rest[slash ..]
end
var host = authority
var port = 80
var colon = string.find(authority, ':')
if colon != nil && colon >= 0
host = authority[0 .. colon - 1]
port = int(authority[colon + 1 ..])
end
if host == nil || host == ''
return {'ok':false,'status':-1,'error':'missing HTTP host','transport':'tcpclient'}
end
var cl = nil
try
cl = tcpclient()
if cl.connect(host, port) != true
try cl.close() except .. as e0,m0 end
try cl.deinit() except .. as e1,m1 end
return {'ok':false,'status':-1,'error':'tcp connect failed','transport':'tcpclient','host':host,'port':port}
end
var req = 'GET ' + path_q + ' HTTP/1.0\r\n'
req += 'Host: ' + host + '\r\n'
req += 'Connection: close\r\n'
if headers != nil
for k:headers.keys()
var ks = str(k)
if size(ks) == 0 || ks[0..0] != '_'
req += ks + ': ' + str(headers[k]) + '\r\n'
end
end
end
req += '\r\n'
cl.write(req)
var raw = ''
var start = tasmota.millis()
var last = start
while tasmota.millis() - start < 12000
var chunk = cl.read()
if chunk != nil && size(chunk) > 0
raw += chunk
last = tasmota.millis()
if size(raw) > 14000
break
end
elif cl.connected() == false
break
elif tasmota.millis() - last > 2500
break
end
tasmota.delay(20)
end
try cl.close() except .. as e2,m2 end
try cl.deinit() except .. as e3,m3 end
if raw == nil || raw == ''
return {'ok':false,'status':-1,'error':'empty TCP HTTP response','transport':'tcpclient'}
end
var body_start = string.find(raw, '\r\n\r\n')
var body = ''
var headers_s = ''
if body_start != nil && body_start >= 0
headers_s = raw[0 .. body_start - 1]
body = raw[body_start + 4 ..]
else
body_start = string.find(raw, '\n\n')
if body_start != nil && body_start >= 0
headers_s = raw[0 .. body_start - 1]
body = raw[body_start + 2 ..]
else
body = raw
end
end
var status = 0
try
var first_end = string.find(raw, '\r\n')
var first = first_end != nil && first_end >= 0 ? raw[0 .. first_end - 1] : raw
var parts = string.split(first, ' ')
if size(parts) >= 2
status = int(parts[1])
end
except .. as e4,m4
status = 0
end
return {'ok':status >= 200 && status < 300,'status':status,'body':body,'headers':headers_s,'transport':'tcpclient'}
except .. as e,m
try if cl != nil cl.close() end except .. as e5,m5 end
try if cl != nil cl.deinit() end except .. as e6,m6 end
return {'ok':false,'status':-1,'error':'tcp GET failed: '+str(m),'transport':'tcpclient'}
end
end
def http_post(url, headers, body)
var cl = nil
try
cl = webclient()
cl.begin(url)
try cl.set_timeouts(45000, 15000) except .. as e_to,m_to end
try cl.use_http10(true) except .. as e_http,m_http end
var default_headers = true
if headers != nil && headers.find('_no_default_headers') == true
default_headers = false
end
if default_headers
cl.add_header('Accept','application/json,text/plain,*/*')
cl.add_header('Connection','close')
cl.add_header('User-Agent','TasmoClaw/0.1')
end
if headers != nil
for k:headers.keys()
var ks = str(k)
if size(ks) == 0 || ks[0..0] != '_'
cl.add_header(k, str(headers[k]))
end
end
end
var code = cl.POST(body == nil ? '' : str(body))
var resp = cl.get_string()
cl.close()
return {'ok':code >= 200 && code < 300,'status':code,'body':resp}
except .. as e,m
try cl.close() except .. as e2,m2 end
return {'ok':false,'error':'HTTP POST failed: '+str(m)}
end
end
def web_search(args)
var q = self.first_value(args, ['query','q','text'], '')
if q == nil || q == ''
return {'ok':false,'error':'missing query'}
end
var cfg = self.store.load_config()
var key = cfg.find('brave_api_key')
if key == nil || key == ''
return {'ok':false,'error':'Missing Brave Search API key in TasmoClaw config'}
end
var mem = {}
try
tasmota.gc()
mem = tasmota.memory()
var heap_free = mem.find('heap_free')
if heap_free != nil && heap_free < 24
return {
'ok':false,
'provider':'brave',
'error':'Not enough free heap for direct Brave HTTPS with stock webclient',
'heap_free':heap_free,
'hint':'Direct Brave needs a small amount of internal heap for TLS. Clear history or retry after a moment. Lite intentionally has no web search.'
}
end
except .. as e_mem,m_mem
end
var base = 'https://api.search.brave.com/res/v1/web/search'
var url = base + '?q=' + self.url_arg(q) + '&count=1&result_filter=web&safesearch=moderate&search_lang=en&country=us&text_decorations=false&extra_snippets=false'
var headers = {
'_no_default_headers':true,
'_http10':false,
'Accept':'application/json',
'Accept-Encoding':'identity',
'Connection':'close',
'User-Agent':'TasmoClaw/0.1',
'X-Subscription-Token':key
}
var r = self.http_get(url, headers)
if r.find('ok') != true
return {'ok':false,'provider':'brave','status':r.find('status'),'error':r.find('error') == nil ? 'Brave search HTTP failed' : r.find('error'),'body':tasmoclaw_util.preview(r.find('body'), 700),'url':tasmoclaw_util.safe_url(url)}
end
var results = []
try
var o = json.load(r.find('body'))
var web = o.find('web')
var items = web == nil ? nil : web.find('results')
if items != nil
for item:items
results.push({'title':item.find('title'),'url':item.find('url'),'snippet':item.find('description')})
if size(results) >= 1 break end
end
end
except .. as e,m
return {'ok':false,'provider':'brave','error':'Brave JSON parse failed: '+str(m),'body':tasmoclaw_util.preview(r.find('body'), 700)}
end
return {'ok':true,'provider':'brave','query':q,'results':results,'count':size(results)}
end
def http_bridge_call(args)
var url = args.find('url')
if url == nil || url == ''
return {'ok':false,'error':'missing url'}
end
var method = string.tolower(str(args.find('method') == nil ? 'get' : args.find('method')))
var headers = args.find('headers')
var body = args.find('body')
var r = nil
if method == 'post'
if headers == nil headers = {'Content-Type':'application/json'} end
r = self.http_post(url, headers, body == nil ? '' : body)
else
if headers == nil headers = {'_no_default_headers':true} end
r = self.http_get(url, headers)
end
r['url'] = tasmoclaw_util.safe_url(url)
if r.find('body') != nil && size(r.find('body')) > 3000
r['body'] = tasmoclaw_util.preview(r.find('body'), 3000)
r['truncated'] = true
end
return r
end
def image_inspect(args)
var image_url = self.first_value(args, ['image_url','url'], '')
if image_url == nil || image_url == ''
var p = args.find('path')
if p != nil && p != ''
return {'ok':false,'error':'Stock TasmoClaw image_inspect supports image_url only. File upload/base64 from SD or FlashFS needs a host/browser helper.','path':p}
end
return {'ok':false,'error':'missing image_url'}
end
var cfg = self.store.load_config()
var api_url = cfg.find('vision_api_url')
if api_url == nil || api_url == ''
api_url = cfg.find('api_url')
end
var model = cfg.find('vision_model')
if model == nil || model == ''
model = cfg.find('model')
end
if api_url == nil || api_url == '' || model == nil || model == ''
return {'ok':false,'error':'missing vision_api_url/model or chat api_url/model'}
end
var prompt = self.first_value(args, ['prompt','question','text'], 'Describe this image and note any visible text.')
var payload = {
'model':model,
'messages':[
{'role':'user','content':[
{'type':'text','text':prompt},
{'type':'image_url','image_url':{'url':image_url}}
]}
],
'max_tokens':int(self.first_value(args, ['max_tokens'], 500)),
'stream':false
}
var headers = {'Content-Type':'application/json'}
var key = cfg.find('vision_api_key')
if key == nil || key == ''
key = cfg.find('api_key')
end
if key != nil && key != ''
headers['Authorization'] = 'Bearer ' + key
end
var r = self.http_post(api_url, headers, tasmoclaw_util.json_encode(payload))
if r.find('ok') != true
return {'ok':false,'status':r.find('status'),'error':r.find('error') == nil ? 'vision HTTP failed' : r.find('error'),'body':tasmoclaw_util.preview(r.find('body'), 800)}
end
try
var o = json.load(r.find('body'))
var msg = o.find('choices')[0].find('message')
return {'ok':true,'content':msg.find('content'),'model':model,'status':r.find('status')}
except .. as e,m
return {'ok':false,'error':'vision JSON parse failed: '+str(m),'body':tasmoclaw_util.preview(r.find('body'), 800)}
end
end
def prefixed_path(fs_name, p)
if p == nil || p == ''
p = '/'
end
if self.has_fs_prefix(p)
return p
end
if p[0..0] != '/'
p = '/' + p
end
return fs_name + ':' + p
end
def command_error(res)
if res == nil
return nil
end
try
if res.find('Command') == 'Error'
var cmd_input = res.find('Input')
if cmd_input == nil
cmd_input = ''
end
return 'Tasmota command error: ' + str(cmd_input)
end
except .. as e,m
end
return nil
end
def ufs_read_file(p, max_bytes)
if self.fs_prefix_kind(p) == 'flash'
var fp = self.strip_fs_prefix(p)
try
var f = open(fp, 'r')
var s = f.read(max_bytes)
f.close()
return {'ok':true,'path':fp,'requested_path':p,'bytes':size(s),'result':s,'fs':'flash','backend':'berry_open'}
except .. as e0,m0
return {'ok':false,'error':'flash read failed: '+str(m0),'path':fp,'requested_path':p,'fs':'flash','backend':'berry_open'}
end
end
if self.fs_prefix_kind(p) == 'sd' && !self.sd_mounted()
return {'ok':false,'error':'SD card is not mounted. Check USE_SDCARD and SDIO pins CMD=GPIO21, CLK=GPIO38, D0=GPIO39.','path':p,'fs':'sd'}
end
if self.fs_prefix_kind(p) == 'sd'
return self.stock_sd_file_error('read', p)
end
return {'ok':false,'error':'missing or unsupported filesystem prefix for read; use flash:/path on stock firmware','path':p,'fs':self.fs_prefix_kind(p)}
end
def ufs_write_file(p, content)
if self.fs_prefix_kind(p) == 'flash'
var fp = self.strip_fs_prefix(p)
try
var f = open(fp, 'w')
f.write(content)
f.close()
return {'ok':true,'path':fp,'requested_path':p,'bytes':size(content),'fs':'flash','backend':'berry_open'}
except .. as e0,m0
return {'ok':false,'error':'flash write failed: '+str(m0),'path':fp,'requested_path':p,'fs':'flash','backend':'berry_open'}
end
end
if self.fs_prefix_kind(p) == 'sd' && !self.sd_mounted()
return {'ok':false,'error':'SD card is not mounted. Check USE_SDCARD and SDIO pins CMD=GPIO21, CLK=GPIO38, D0=GPIO39.','path':p,'fs':'sd'}
end
if self.fs_prefix_kind(p) == 'sd'
return self.stock_sd_file_error('write', p)
end
return {'ok':false,'error':'missing or unsupported filesystem prefix for write; use flash:/path on stock firmware','path':p,'fs':self.fs_prefix_kind(p)}
end
def ufs_list_dir(p)
if self.fs_prefix_kind(p) == 'flash'
var fp = self.strip_fs_prefix(p)
try
var entries = path.listdir(fp)
if entries == nil
entries = []
end
return {'ok':true,'path':fp,'requested_path':p,'fs':'flash','backend':'path.listdir','entries':entries,'result':entries}
except .. as e0,m0
return {'ok':false,'error':'flash list failed: '+str(m0),'path':fp,'requested_path':p,'fs':'flash','backend':'path.listdir'}
end
end
if self.fs_prefix_kind(p) == 'sd' && !self.sd_mounted()
return {'ok':false,'error':'SD card is not mounted. Check USE_SDCARD and SDIO pins CMD=GPIO21, CLK=GPIO38, D0=GPIO39.','path':p,'fs':'sd'}
end
var fp = self.strip_fs_prefix(p)
var cmd = 'UfsList'
if fp != '/'
cmd += ' ' + str(fp)
end
try
var res = tasmota.cmd(cmd, true)
var cerr = self.command_error(res)
if cerr == nil
var entries = []
try
var listed = res.find('UfsList')
if listed != nil && str(listed) != 'Done'
entries = listed
end
except .. as e1,m1
end
return {'ok':true,'path':fp,'requested_path':p,'fs':self.fs_prefix_kind(p) == 'sd' ? 'sd' : 'ufs','backend':'UfsList','command':cmd,'entries':entries,'result':res}
end
except .. as e0,m0
return {'ok':false,'error':'UfsList failed: '+str(m0),'path':fp,'requested_path':p,'fs':self.fs_prefix_kind(p),'backend':'UfsList','command':cmd}
end
return {'ok':false,'error':'UfsList returned a Tasmota command error','path':fp,'requested_path':p,'fs':self.fs_prefix_kind(p),'backend':'UfsList','command':cmd}
end
def merge_power_result(out, slot, res)
if res == nil
return
end
if res.find('Command') == 'Error'
if slot != nil && slot != ''
out['POWER' + str(slot) + '_error'] = str(res.find('Input'))
end
return
end
var value = res.find('POWER')
if value == nil
value = res.find('Power')
end
if value == nil && slot != nil && slot != ''
value = res.find('POWER' + str(slot))
end
if value == nil
return
end
if slot == nil || slot == ''
out['POWER'] = value
if out.find('POWER1') == nil
out['POWER1'] = value
end
else
out['POWER' + str(slot)] = value
if str(slot) == '1' && out.find('POWER') == nil
out['POWER'] = value
end
end
end
def power_snapshot()
var out = {}
try
var status0 = tasmota.cmd('Status 0', true)
out['status0'] = status0
var sts = status0.find('StatusSTS')
if sts != nil
if sts.find('POWER') != nil
out['POWER'] = sts.find('POWER')
out['POWER1'] = sts.find('POWER')
end
if sts.find('POWER1') != nil
out['POWER1'] = sts.find('POWER1')
end
if sts.find('POWER2') != nil
out['POWER2'] = sts.find('POWER2')
end
if sts.find('Power') != nil
out['Power'] = sts.find('Power')
end
end
except .. as e,m
out['status0_error'] = str(m)
end
try
self.merge_power_result(out, '', tasmota.cmd('Power', true))
except .. as e1,m1
out['POWER_error'] = str(m1)
end
try
self.merge_power_result(out, '1', tasmota.cmd('Power1', true))
except .. as e2,m2
out['POWER1_error'] = str(m2)
end
try
self.merge_power_result(out, '2', tasmota.cmd('Power2', true))
except .. as e3,m3
out['POWER2_error'] = str(m3)
end
if out.find('Power') == nil && (out.find('POWER1') != nil || out.find('POWER2') != nil)
var summary = ''
if out.find('POWER1') != nil
summary += 'POWER1=' + str(out.find('POWER1'))
end
if out.find('POWER2') != nil
if summary != ''
summary += ', '
end
summary += 'POWER2=' + str(out.find('POWER2'))
end
out['Power'] = summary
end
return out
end
def berry_path(name)
var n = self.normalize_name(name, '.be')
if self.store != nil && self.store.workspace_fallback
return '/tasmoclaw_demo_' + n
end
return '/tasmoclaw/berry/' + n
end
def markdown_path(name)
return '/' + self.normalize_name(name, '.md')
end
def run_status(args)
var out = {
'memory':tasmota.memory(),
'wifi':tasmota.wifi(),
'arch':tasmota.arch()
}
try
out['sensors']=tasmota.read_sensors(false)
except .. as e,m
end
try
out['status0']=tasmota.cmd('Status 0', true)
except .. as e,m
end
return {'ok':true, 'result':out}
end
def run_cmd_read(args)
var c = self.get_command_arg(args)
if c == nil || c == ''
return {'ok':false,'error':'missing command'}
end
var lower = string.tolower(c)
var first_space = string.find(lower, ' ')
var first = lower
var rest = ''
if first_space != nil && first_space >= 0
first = lower[0..first_space-1]
rest = lower[first_space+1..size(lower)-1]
end
var cls = tasmoclaw_commands.classify_command(c)
if cls.find('ok') != true || cls.find('safety') != 'read'
return {'ok':false,'error':'command is not clearly read-only; request command_run or tasmota_cmd with approval','classification':cls}
end
try
if first == 'rules'
return {
'ok':true,
'result':{
'Rule1':tasmota.cmd('Rule1', true),
'Rule2':tasmota.cmd('Rule2', true),
'Rule3':tasmota.cmd('Rule3', true)
}
}
end
return {'ok':true,'result':tasmota.cmd(c, true)}
except .. as e,m
return {'ok':false,'error':'command failed: '+str(m)}
end
end
def sensor_read(args)
var out = {}
try
out['i2cscan'] = tasmota.cmd('I2CScan', true)
except .. as e,m
out['i2cscan_error'] = str(m)
end
try
out['status8'] = tasmota.cmd('Status 8', true)
except .. as e2,m2
out['status8_error'] = str(m2)
end
try
out['sensors'] = tasmota.read_sensors(false)
except .. as e4,m4
out['sensors_error'] = str(m4)
end
return {'ok':true,'result':out}
end
def device_read(args)
var out = {
'memory':tasmota.memory(),
'wifi':tasmota.wifi(),
'sd_mounted':self.sd_mounted()
}
try
out['i2cscan'] = tasmota.cmd('I2CScan', true)
except .. as e,m
out['i2cscan_error'] = str(m)
end
try
out['status8'] = tasmota.cmd('Status 8', true)
except .. as e1,m1
out['status8_error'] = str(m1)
end
try
out['power'] = self.power_snapshot()
except .. as e2,m2
out['power_error'] = str(m2)
end
try
out['ufs'] = tasmota.cmd('Ufs', true)
except .. as e5,m5
out['ufs_error'] = str(m5)
end
return {
'ok':true,
'result':out
}
end
def add_check(checks, name, ok, detail)
checks.push({'name':name,'ok':ok,'detail':detail})
end
def device_doctor(args)
var d = self.device_read({})
var result = d.find('result')
if result == nil
result = {}
end
var checks = []
var mem = result.find('memory')
var heap = mem == nil ? nil : mem.find('heap_free')
self.add_check(checks, 'Heap', heap == nil || heap >= 60, 'heap_free=' + str(heap))
var psram = mem == nil ? nil : mem.find('psram_free')
self.add_check(checks, 'PSRAM', psram != nil && psram > 0, 'psram_free=' + str(psram))
var wifi = result.find('wifi')
var ip = wifi == nil ? nil : wifi.find('ip')
self.add_check(checks, 'Wi-Fi', ip != nil && str(ip) != '', 'ip=' + str(ip))
self.add_check(checks, 'SD/UFS', result.find('sd_mounted') == true, 'sd_mounted=' + str(result.find('sd_mounted')) + ' ufs=' + tasmoclaw_util.preview(str(result.find('ufs')), 240))
self.add_check(checks, 'I2C', result.find('i2cscan_error') == nil, tasmoclaw_util.preview(str(result.find('i2cscan')), 240))
self.add_check(checks, 'Sensors', result.find('status8_error') == nil, tasmoclaw_util.preview(str(result.find('status8')), 240))
var rules = {
'Rule1':tasmota.cmd('Rule1', true),
'Rule2':tasmota.cmd('Rule2', true),
'Rule3':tasmota.cmd('Rule3', true)
}
self.add_check(checks, 'Rules', true, tasmoclaw_util.preview(str(rules), 300))
self.add_check(checks, 'Timers', true, tasmoclaw_util.preview(str(tasmota.cmd('Timers', true)), 220))
var lv = self.berry_module_probe({'modules':['display','lv_tasmota','lvgl_panel','webclient','path','persist']})
self.add_check(checks, 'Display/LVGL modules', lv.find('ok') == true, tasmoclaw_util.preview(tasmoclaw_util.json_encode(lv.find('result')), 350))
var warnings = []
for c:checks
if c.find('ok') != true
warnings.push(c.find('name') + ': ' + str(c.find('detail')))
end
end
return {'ok':true,'summary':size(warnings) == 0 ? 'Board looks healthy.' : 'Board has ' + str(size(warnings)) + ' warning(s).','checks':checks,'warnings':warnings,'device':result}
end
def board_bringup_wizard(args)
var checks = []
var dev = self.device_read({}).find('result')
if dev == nil
dev = {}
end
self.add_check(checks, 'Expected SD SPI pins', true, 'GPIO21 MOSI, GPIO38 SCK, GPIO39 MISO; chip-select must match the board/template wiring.')
self.add_check(checks, 'SD mounted', dev.find('sd_mounted') == true, tasmoclaw_util.preview(str(dev.find('ufs')), 280))
self.add_check(checks, 'I2C bus', dev.find('i2cscan_error') == nil, tasmoclaw_util.preview(str(dev.find('i2cscan')), 280))
self.add_check(checks, 'Sensor status', dev.find('status8_error') == nil, tasmoclaw_util.preview(str(dev.find('status8')), 280))
self.add_check(checks, 'LVGL/display', self.lvgl_control({'action':'status'}).find('ok') == true, 'LVGL/display module probe ran.')
var template = nil
try template = tasmota.cmd('Template', true) except .. as e_t,m_t template = {'error':str(m_t)} end
var module_status = nil
try module_status = tasmota.cmd('Module', true) except .. as e_m,m_m module_status = {'error':str(m_m)} end
return {
'ok':true,
'board':'Waveshare ESP32-S3-RLCD-4.2',
'checks':checks,
'template':template,
'module':module_status,
'next_steps':['Confirm SD CS GPIO in the active template.','Run UfsType and Ufs if SD is not mounted.','Run I2CScan if RTC/touch/sensor devices are missing.','Use dashboard_create after LVGL/display is available.']
}
end
def rule_explain(args)
var rules = {
'Rule1':tasmota.cmd('Rule1', true),
'Rule2':tasmota.cmd('Rule2', true),
'Rule3':tasmota.cmd('Rule3', true)
}
var notes = []
for k:rules.keys()
var raw = rules[k]
var inner = raw == nil ? nil : raw.find(k)
var state = inner == nil ? '' : string.tolower(str(inner.find('State')))
var body = inner == nil ? '' : str(inner.find('Rules'))
var txt = string.tolower(body)
var enabled = state == 'on' || body != ''
var triggers = []
var idx = string.find(txt, 'system#boot')
if idx != nil && idx >= 0 triggers.push('System#Boot') end
idx = string.find(txt, 'time#minute')
if idx != nil && idx >= 0 triggers.push('Time#Minute') end
idx = string.find(txt, 'rules#timer')
var idx2 = string.find(txt, 'ruletimer')
if (idx != nil && idx >= 0) || (idx2 != nil && idx2 >= 0) triggers.push('RuleTimer') end
idx = string.find(txt, 'power')
if idx != nil && idx >= 0 triggers.push('Power event/action') end
var actions = []
idx = string.find(txt, 'backlog')
if idx != nil && idx >= 0 actions.push('Backlog') end
idx = string.find(txt, 'br load')
if idx != nil && idx >= 0 actions.push('Berry load') end
idx = string.find(txt, 'power')
if idx != nil && idx >= 0 actions.push('Power command') end
idx = string.find(txt, 'displaytext')
if idx != nil && idx >= 0 actions.push('DisplayText') end
notes.push({'slot':k,'enabled_or_present':enabled,'state':state,'rule':body,'triggers':triggers,'actions':actions,'raw':raw})
end
return {'ok':true,'rules':rules,'explanation':notes,'cleanup_hints':['Keep startup auto-load rules short.','Prefer one purpose per rule slot.','Use RuleTimer/PulseTime through timer_control, not ad-hoc rule edits, when possible.']}
end
def automation_builder(args)
if args == nil
args = {}
end
var goal = string.tolower(str(self.first_value(args, ['goal','text','request'], '')))
var slot = int(self.first_value(args, ['slot','timer'], 1))
if slot < 1
slot = 1
end
var output = int(self.first_value(args, ['output','relay','power'], 1))
if output < 1
output = 1
end
var wants_off = string.find(goal, 'off') != nil && string.find(goal, 'off') >= 0
var mode = (string.find(goal, 'sunrise') != nil && string.find(goal, 'sunrise') >= 0) || (string.find(goal, 'morning') != nil && string.find(goal, 'morning') >= 0) ? 1 : 2
var action = wants_off ? 0 : 1
var days = 'SMTWTFS'
if string.find(goal, 'weekend') != nil && string.find(goal, 'weekend') >= 0
days = 'S-----S'
elif string.find(goal, 'weekday') != nil && string.find(goal, 'weekday') >= 0
days = '-MTWTF-'
end
var value = '{"Arm":1,"Mode":' + str(mode) + ',"Time":"00:00","Window":0,"Days":"' + days + '","Repeat":1,"Output":' + str(output) + ',"Action":' + str(action) + '}'
var commands = [
'Timer' + str(slot) + ' ' + value,
'Timers 1'
]
var res = self.command_sequence_run({'commands':commands,'confirm':true})
return {'ok':res.find('ok'),'goal':goal,'plan':'Timer' + str(slot) + ' uses ' + (mode == 2 ? 'sunset' : 'sunrise') + ' every selected day and enables Timers.','commands':commands,'result':res}
end
def dashboard_create(args)
var dev = self.device_read({}).find('result')
var title = self.first_value(args, ['title','name'], 'TasmoClaw Board')
var pmap = dev == nil ? nil : dev.find('power')
var wmap = dev == nil ? nil : dev.find('wifi')
var power = pmap == nil ? '' : 'P1=' + str(pmap.find('POWER1')) + ' P2=' + str(pmap.find('POWER2'))
var wifi = wmap == nil ? '' : str(wmap.find('ip')) + ' RSSI=' + str(wmap.find('rssi'))
var sd = dev == nil ? '' : str(dev.find('sd_mounted'))
var text = str(title) + ' | Wi-Fi ' + wifi + ' | SD ' + sd + ' | ' + power + ' | Heap ' + str(tasmota.memory().find('heap_free')) + ' KB'
var r = self.display_control({'text':text})
r['dashboard_text'] = text
r['display_backend'] = 'DisplayText'
return r
end
def power_read(args)
var out = self.power_snapshot()
return {'ok':true,'result':out}
end
def command_catalog_search(args)
return tasmoclaw_commands.search(args)
end
def command_build(args)
return tasmoclaw_commands.build(args)
end
def run_built_command(args, allow_dangerous)
var built = tasmoclaw_commands.build(args)
if built.find('ok') != true
return built
end
var c = built.find('command')
if c == nil || c == ''
return {'ok':false,'error':'missing built command'}
end
var safety = built.find('safety')
if safety == 'dangerous' && allow_dangerous != true
return {
'ok':false,
'error':'Refusing high-impact command without explicit confirm:true',
'command':c,
'safety':safety,
'reason':built.find('reason')
}
end
try
var read_only = safety == 'read'
return {
'ok':true,
'command':c,
'safety':safety,
'reason':built.find('reason'),
'result':tasmota.cmd(c, read_only)
}
except .. as e,m
return {'ok':false,'error':'command failed: '+str(m),'command':c,'safety':safety}
end
end
def command_run(args)
return self.run_built_command(args, args.find('confirm') == true)
end
def sequence_items(args)
if args == nil
return nil
end
var items = args.find('items')
if items == nil
items = args.find('steps')
end
if items == nil
items = args.find('commands')
end
if type(items) == 'string'
items = [items]
end
return items
end
def sequence_item_args(item)
try
if item.find('command') != nil || item.find('cmd') != nil || item.find('family') != nil || item.find('tool') != nil
return item
end
except .. as e,m
end
return {'command':str(item)}
end
def sequence_requires_approval(args)
var items = self.sequence_items(args)
if items == nil
return true
end
for item:items
var step = self.sequence_item_args(item)
if step == nil
return true
end
try
var built = tasmoclaw_commands.build(step)
if built.find('ok') != true
return true
end
if built.find('safety') != 'read'
return true
end
except .. as e,m
return true
end
end
return false
end
def command_sequence_run(args)
var items = self.sequence_items(args)
if items == nil
return {'ok':false,'error':'missing items/steps/commands'}
end
var results = []
var idx = 0
var continue_on_error = args.find('continue_on_error') == true
var sequence_confirm = args.find('confirm') == true
for item:items
var step = self.sequence_item_args(item)
if step == nil
var bad = {'ok':false,'error':'invalid sequence item','index':idx,'item':str(item)}
results.push(bad)
return {'ok':false,'results':results,'stopped_at':idx,'error':'invalid sequence item'}
end
var r = nil
try
r = self.run_built_command(step, sequence_confirm || step.find('confirm') == true)
except .. as e,m
var bad2 = {'ok':false,'error':'invalid sequence item: '+str(m),'index':idx,'item':str(item)}
results.push(bad2)
return {'ok':false,'results':results,'stopped_at':idx,'error':bad2.find('error')}
end
r['index'] = idx
results.push(r)
if r.find('ok') != true && !continue_on_error
return {'ok':false,'results':results,'stopped_at':idx,'error':r.find('error')}
end
idx += 1
end
return {'ok':true,'results':results,'count':idx}
end
def tool_sequence_items(args)
if args == nil
return nil
end
var items = args.find('items')
if items == nil
items = args.find('steps')
end
if items == nil
items = args.find('tools')
end
if items == nil
items = args.find('commands')
end
if type(items) == 'string'
items = [items]
end
return items
end
def tool_step_info(item)
if item == nil
return {'ok':false,'error':'empty step'}
end
try
var tool = item.find('tool')
if tool != nil && tool != ''
var args = item.find('args')
if args == nil
args = {}
for k:item.keys()
if k != 'tool' && k != 'reason'
args[k] = item[k]
end
end
end
return {'ok':true,'kind':'tool','tool':str(tool),'args':args}
end
except .. as e,m
end
return {'ok':true,'kind':'command','args':self.sequence_item_args(item)}
end
def tool_sequence_requires_approval(args)
var items = self.tool_sequence_items(args)
if items == nil
return true
end
for item:items
var info = self.tool_step_info(item)
if info.find('ok') != true
return true
end
if info.find('kind') == 'tool'
var tool = info.find('tool')
if tool == 'tool_sequence_run'
return true
end
if self.requires_approval_for(tool, info.find('args'))
return true
end
else
var built = tasmoclaw_commands.build(info.find('args'))
if built.find('ok') != true || built.find('safety') != 'read'
return true
end
end
end
return false
end
def tool_sequence_run(args)
var items = self.tool_sequence_items(args)
if items == nil
return {'ok':false,'error':'missing items/steps/tools/commands'}
end
var results = []
var idx = 0
var continue_on_error = args.find('continue_on_error') == true
var sequence_confirm = args.find('confirm') == true
for item:items
var info = self.tool_step_info(item)
if info.find('ok') != true
results.push({'ok':false,'index':idx,'error':info.find('error')})
return {'ok':false,'results':results,'stopped_at':idx,'error':info.find('error')}
end
var r = nil
if info.find('kind') == 'tool'
var tool = info.find('tool')
if tool == 'tool_sequence_run'
r = {'ok':false,'error':'nested tool_sequence_run is not allowed'}
else
r = self.run(tool, info.find('args'))
end
r['tool'] = tool
else
var step = info.find('args')
if sequence_confirm
step['confirm'] = true
end
r = self.run_built_command(step, sequence_confirm || step.find('confirm') == true)
r['tool'] = 'command_run'
end
r['index'] = idx
results.push(r)
if r.find('ok') != true && !continue_on_error
return {'ok':false,'results':results,'stopped_at':idx,'error':r.find('error')}
end
idx += 1
end
return {'ok':true,'results':results,'count':idx}
end
def escape_berry_string(s)
if s == nil
s = ''
end
var out = str(s)
out = string.replace(out, '\\', '\\\\')
out = string.replace(out, '"', '\\"')
out = string.replace(out, '\n', '\\n')
out = string.replace(out, '\r', '\\r')
return out
end
def berry_module_probe(args)
var modules = args.find('modules')
if modules == nil
modules = ['path','persist','json','string','webserver','webclient','display','lv_tasmota','lvgl_panel','gpio','introspect']
end
if type(modules) == 'string'
modules = [modules]
end
var out = {'modules':[],'globals':{},'commands':{}}
for mn:modules
var item = {'module':str(mn)}
try
var mod = introspect.module(str(mn))
item['available'] = mod != nil
item['type'] = str(type(mod))
except .. as e,m
item['available'] = false
item['error'] = str(m)
end
out['modules'].push(item)
end
for g:['tasmota','webserver','webclient','lv','display','gpio','persist','path','json','string']
try
out['globals'][g] = global.contains(g)
except .. as e2,m2
out['globals'][g] = false
end
end
for c:['Display','DisplayModel','DisplayWidth','DisplayHeight','DisplayDimmer','DisplaySize','DisplayFont','DisplayRotate','WebColor','Ufs','UfsType']
try
out['commands'][c] = tasmota.cmd(c, true)
except .. as e3,m3
out['commands'][c] = {'error':str(m3)}
end
end
return {'ok':true,'result':out}
end
def webcolor_control(args)
if args == nil
args = {}
end
var action = string.tolower(str(args.find('action') == nil ? 'read' : args.find('action')))
var idx = args.find('index')
var value = args.find('value')
var palette = args.find('palette')
if palette == nil
palette = args.find('colors')
end
if action == 'read' || action == 'status' || action == 'show' || action == 'get' || action == 'dump'
var out = {}
try
if idx != nil
out['index'] = idx
out['color'] = tasmota.webcolor(idx)
else
out['colors'] = tasmota.webcolor()
end
except .. as e,m
try
out['colors'] = tasmota.cmd('WebColor', true)
except .. as e2,m2
return {'ok':false,'error':'WebColor read failed: '+str(m2)}
end
end
return {'ok':true,'result':out}
end
var cmd = nil
if palette != nil
cmd = 'WebColor ' + tasmoclaw_util.json_encode({'WebColor':palette})
elif idx != nil && value != nil
cmd = 'WebColor' + str(int(idx) + 1) + ' ' + str(value)
elif value != nil
cmd = 'WebColor ' + str(value)
end
if cmd == nil
return {'ok':false,'error':'missing palette/colors or index/value'}
end
try
return {'ok':true,'command':cmd,'safety':'write','result':tasmota.cmd(cmd, false)}
except .. as e3,m3
return {'ok':false,'error':'WebColor command failed: '+str(m3),'command':cmd}
end
end
def lvgl_control(args)
if args == nil
args = {}
end
var action = string.tolower(str(args.find('action') == nil ? 'status' : args.find('action')))
if action == 'read' || action == 'status' || action == 'probe' || action == 'info'
var p = self.berry_module_probe({'modules':['display','lv_tasmota','lvgl_panel']})
if p.find('ok') == true
p['result']['lv_available'] = global.contains('lv')
end
return p
end
if !global.contains('lv')
return {'ok':false,'error':'LVGL global lv is not available in this firmware'}
end
if action == 'start'
try
lv.start()
return {'ok':true,'result':{'started':true,'width':lv.get_hor_res(),'height':lv.get_ver_res()}}
except .. as e,m
return {'ok':false,'error':'LVGL start failed: '+str(m)}
end
elif action == 'splash'
try
lv.splash()
return {'ok':true,'result':'LVGL splash requested'}
except .. as e2,m2
return {'ok':false,'error':'LVGL splash failed: '+str(m2)}
end
elif action == 'label' || action == 'message' || action == 'dashboard'
var text = args.find('text')
if text == nil
text = args.find('message')
end
if text == nil
text = 'TasmoClaw'
end
var pth = '/tasmoclaw/berry/lvgl_tasmoclaw.be'
if self.store != nil && self.store.workspace_fallback
pth = '/tasmoclaw_demo_lvgl_tasmoclaw.be'
end
var c = "lv.start()\n"
c += "var scr = lv.obj(0)\n"
c += "scr.set_style_bg_color(lv.color(0x05050A), 0)\n"
c += "var title = lv.label(scr)\n"
c += "title.set_text(\"" + self.escape_berry_string(text) + "\")\n"
if action == 'dashboard'
c += "title.set_style_text_color(lv.color(0xEAF2FF), 0)\n"
c += "title.align(lv.ALIGN_TOP_LEFT, 18, 18)\n"
else
c += "title.set_style_text_color(lv.color(0x39FF14), 0)\n"
c += "title.align(lv.ALIGN_CENTER, 0, 0)\n"
end
c += "lv.scr_load(scr)\n"
c += "lv.refr_now(0)\n"
var wr = self.file_write({'path':pth,'content':c})
if wr.find('ok') != true
return wr
end
var lr = self.berry_load({'path':pth})
return {'ok':lr.find('ok'),'path':pth,'bytes':wr.find('bytes'),'load':lr,'result':lr.find('result'),'error':lr.find('error')}
end
return {'ok':false,'error':'unknown LVGL action: '+action}
end
def display_control(args)
if args == nil
args = {}
end
args['family'] = 'display'
return self.run_built_command(args, true)
end
def power_control(args)
if args == nil
args = {}
end
args['family'] = 'power'
var action = args.find('action')
if action == nil || action == ''
action = 'read'
end
args['action'] = action
return self.run_built_command(args, true)
end
def rule_control(args)
if args == nil
args = {}
end
var action = args.find('action')
if action == nil || action == ''
action = 'read'
end
action = string.tolower(str(action))
if (args.find('rule') == nil || args.find('rule') == '') && args.find('slot') != nil
args['rule'] = args.find('slot')
end
if action == 'clear' || action == 'delete' || action == 'remove'
return self.rule_clear(args)
elif action == 'set' || action == 'apply' || action == 'write'
return self.rule_apply(args)
end
var rule_name = args.find('rule')
if rule_name == nil || rule_name == ''
rule_name = args.find('slot')
end
if rule_name == nil || rule_name == ''
rule_name = 'Rules'
end
if string.tolower(str(rule_name)) == 'rules'
return self.run_cmd_read({'command':'Rules'})
end
args['family'] = 'rules'
args['action'] = action
return self.run_built_command(args, true)
end
def light_control(args)
return self.run_built_command(self.with_family(args, 'light'), true)
end
def mqtt_control(args)
return self.run_built_command(self.with_family(args, 'mqtt'), true)
end
def telemetry_control(args)
return self.run_built_command(self.with_family(args, 'telemetry'), true)
end
def network_control(args)
return self.run_built_command(self.with_family(args, 'network'), args != nil && args.find('confirm') == true)
end
def system_control(args)
return self.run_built_command(self.with_family(args, 'system'), args != nil && args.find('confirm') == true)
end
def timer_control(args)
return self.run_built_command(self.with_family(args, 'timer'), true)
end
def filesystem_control(args)
return self.run_built_command(self.with_family(args, 'filesystem'), true)
end
def file_copy(args)
var src = self.first_value(args, ['src','source','from','path'], nil)
var dest = self.first_value(args, ['dest','destination','to'], nil)
if src == nil || src == '' || dest == nil || dest == ''
return {'ok':false,'error':'missing src/from/path or dest/to'}
end
if self.fs_prefix_kind(src) == 'sd' || self.fs_prefix_kind(dest) == 'sd'
return self.stock_sd_file_error('copy', src)
end
if !self.has_fs_prefix(src)
src = self.prefixed_path('flash', src)
end
if !self.has_fs_prefix(dest)
dest = self.prefixed_path('flash', dest)
end
var r = self.file_read({'path':src,'max_bytes':16384})
if r.find('ok') != true
return r
end
var body = r.find('result')
if body == nil
body = ''
end
var wr = self.file_write({'path':dest,'content':body})
if wr.find('ok') == true
wr['copied_from'] = src
end
return wr
end
def file_move(args)
var src = self.first_value(args, ['src','source','from','path'], nil)
var dest = self.first_value(args, ['dest','destination','to'], nil)
if src == nil || src == '' || dest == nil || dest == ''
return {'ok':false,'error':'missing src/from/path or dest/to'}
end
if self.has_fs_prefix(src) || self.has_fs_prefix(dest)
return self.filesystem_control({'action':'rename','path':src,'dest':dest,'confirm':true})
end
var cp = self.file_copy({'src':src,'dest':dest})
if cp.find('ok') != true
return cp
end
var del = self.file_delete({'path':src})
cp['delete_source'] = del
cp['moved_from'] = src
return cp
end
def file_delete(args)
var p = self.first_value(args, ['path','file','filename'], nil)
if p == nil || p == ''
return {'ok':false,'error':'missing path'}
end
var kind = self.fs_prefix_kind(p)
if kind == 'sd'
return self.filesystem_control({'action':'delete','path':p,'confirm':true})
end
if kind == 'flash'
p = self.strip_fs_prefix(p)
end
try
if path.exists(p) == true
path.remove(p)
end
return {'ok':true,'path':p,'fs':'flash'}
except .. as e,m
return {'ok':false,'error':'delete failed: '+str(m),'path':p}
end
end
def script_path(args)
var p = self.first_value(args, ['path','file','filename'], nil)
if p == nil || p == ''
p = self.first_value(args, ['name'], 'script')
p = self.normalize_name(p, '.be')
p = '/tasmoclaw/scripts/' + p
end
if self.has_fs_prefix(p)
return p
end
if string.find(str(p), '/') == nil || string.find(str(p), '/') < 0
p = '/tasmoclaw/scripts/' + self.normalize_name(p, '.be')
end
return 'flash:' + p
end
def script_list(args)
var out = {'scripts':[]}
var r1 = self.file_list({'path':'flash:/tasmoclaw/scripts'})
out['scripts_dir'] = r1
var r2 = self.file_list({'path':'flash:/tasmoclaw/berry'})
out['berry_dir'] = r2
return {'ok':true,'result':out}
end
def script_read(args)
return self.file_read({'path':self.script_path(args),'max_bytes':self.first_value(args, ['max_bytes'], 8192)})
end
def script_create(args)
var content = self.first_value(args, ['content','code','body'], nil)
if content == nil || content == ''
var name = self.first_value(args, ['name','command'], 'tasmo_script')
content = "# TasmoClaw Berry script\n"
content += "print('TasmoClaw script " + str(name) + " ran')\n"
end
return self.file_write({'path':self.script_path(args),'content':content})
end
def script_run(args)
return self.berry_load({'path':self.strip_fs_prefix(self.script_path(args))})
end
def tasmota_cmd(args)
var c = self.get_command_arg(args)
if c == nil || c == ''
return {'ok':false,'error':'missing command'}
end
try
return {'ok':true,'result':tasmota.cmd(c, false)}
except .. as e,m
return {'ok':false,'error':'command failed: '+str(m)}
end
end
def file_read(args)
var p=args.find('path')
var m=args.find('max_bytes')
if p == nil || p == ''
return {'ok':false,'error':'missing path'}
end
if m==nil
m=4096
end
if m<1
m=4096
end
if m>16384
return {'ok':false,'error':'max_bytes too large'}
end
if self.has_fs_prefix(p)
return self.ufs_read_file(p, m)
end
var berry_error = nil
try
if path.exists(p) == true
var f=open(p,'r')
var s=f.read(m)
f.close()
return {'ok':true,'path':p,'bytes':size(s),'result':s,'fs':'flash'}
end
except .. as e,msg
berry_error = str(msg)
end
var r = self.ufs_read_file(p, m)
if r['ok']
return r
end
if berry_error != nil
r['flash_error'] = berry_error
end
return r
end
def file_write(args)
var p=args.find('path')
var c=args.find('content')
if p == nil || p == ''
return {'ok':false,'error':'missing path'}
end
if c == nil
c = ''
end
if self.has_fs_prefix(p)
return self.ufs_write_file(p, c)
end
var berry_error = nil
try
var f=open(p,'w')
f.write(c)
f.close()
return {'ok':true,'path':p,'bytes':size(c),'fs':'flash'}
except .. as e,msg
berry_error = str(msg)
end
var r = self.ufs_write_file(p, c)
if r['ok']
return r
end
r['flash_error'] = berry_error
return r
end
def file_list(args)
var p = args.find('path')
if p == nil || p == ''
p = '/'
end
if self.has_fs_prefix(p)
return self.ufs_list_dir(p)
end
try
return {'ok':true,'path':p,'result':tasmota.cmd('UfsList ' + p, true)}
except .. as e,m
var r = self.ufs_list_dir(p)
if r['ok']
return r
end
return {'ok':false,'error':'file list failed: '+str(m),'native':r}
end
end
def ufs_info(args)
var out = {}
try
out['ufs'] = tasmota.cmd('Ufs', true)
except .. as e,m
out['ufs_error'] = str(m)
end
try
out['type'] = tasmota.cmd('UfsType', true)
except .. as e1,m1
out['type_error'] = str(m1)
end
try
out['size'] = tasmota.cmd('UfsSize', true)
except .. as e2,m2
out['size_error'] = str(m2)
end
try
out['free'] = tasmota.cmd('UfsFree', true)
except .. as e3,m3
out['free_error'] = str(m3)
end
try
out['list'] = tasmota.cmd('UfsList', true)
except .. as e4,m4
out['list_error'] = str(m4)
end
out['sd_mounted'] = self.sd_mounted()
if out['sd_mounted']
out['sd_list'] = self.ufs_list_dir('sd:/')
end
out['flash_list'] = self.ufs_list_dir('flash:/')
return {'ok':true,'result':out}
end
def sd_markdown_list(args)
if !self.sd_mounted()
return {'ok':false,'error':'SD card is not mounted. Check USE_SDCARD and SDIO pins CMD=GPIO21, CLK=GPIO38, D0=GPIO39.'}
end
try
return self.ufs_list_dir('sd:/')
except .. as e,m
return {'ok':false,'error':'SD markdown list failed: '+str(m)}
end
end
def berry_program_write(args)
var p = args.find('path')
if p == nil || p == ''
p = self.berry_path(args.find('name'))
end
var c = args.find('content')
if c == nil || c == ''
c = "def hello_world_cmd(cmd, idx, payload, payload_json)\n"
c += "  tasmota.resp_cmnd('{\"HelloWorld\":\"ok\"}')\n"
c += "end\n\n"
c += "tasmota.add_cmd('HelloWorld', hello_world_cmd)\n"
c += "print('Hello World from TasmoClaw')\n"
end
var r = self.file_write({'path':p,'content':c})
if r['ok']
r['berry_program'] = true
end
return r
end
def berry_program_read(args)
var p = args.find('path')
if p == nil || p == ''
p = self.berry_path(args.find('name'))
end
return self.file_read({'path':p,'max_bytes':args.find('max_bytes') == nil ? 8192 : args.find('max_bytes')})
end
def berry_program_explain(args)
var r = self.berry_program_read(args)
if r['ok']
r['instruction'] = 'Explain this Berry source to the user, including commands it registers, filesystem side effects, and how to run it.'
end
return r
end
def berry_program_run(args)
var p = args.find('path')
if p == nil || p == ''
p = self.berry_path(args.find('name'))
end
return self.berry_load({'path':p})
end
def berry_console(args)
if args == nil
args = {}
end
var code = args.find('code')
if code == nil || code == ''
code = args.find('expr')
end
if code == nil || code == ''
code = args.find('command')
end
if code == nil || code == ''
return {'ok':false,'error':'missing Berry code'}
end
if size(str(code)) > 512
return {'ok':false,'error':'Berry console snippets are limited to 512 bytes; write a .be file for larger programs'}
end
var cmd = 'Br ' + str(code)
try
return {'ok':true,'command':cmd,'safety':'action','result':tasmota.cmd(cmd, false)}
except .. as e,m
return {'ok':false,'error':'Berry console command failed: '+str(m),'command':cmd}
end
end
def safe_skill_token(value, fallback)
if value == nil || value == ''
value = fallback
end
var s = str(value)
for bad:['/','\\',' ','-','.',':',';','; ',',','"','\'','`','(',')','[',']','{','}','=','+','*','&','?','!','#']
s = string.replace(s, bad, '_')
end
while string.find(s, '__') != nil && string.find(s, '__') >= 0
s = string.replace(s, '__', '_')
end
if s == nil || s == '' || s == '_'
s = fallback
end
return s
end
def berry_skill_source(args)
var name = self.safe_skill_token(args.find('name'), 'tasmo_skill')
var command = self.safe_skill_token(args.find('command'), name)
var fn = string.tolower(command) + '_cmd'
fn = self.safe_skill_token(fn, 'tasmo_skill_cmd')
var desc = args.find('description')
if desc == nil
desc = 'TasmoClaw generated Berry skill'
end
var c = "import string\n\n"
c += "# " + str(desc) + "\n"
c += "def _tc_escape(v)\n"
c += "  var s = str(v)\n"
c += "  s = string.replace(s, '\\\\', '\\\\\\\\')\n"
c += "  s = string.replace(s, '\"', '\\\\\"')\n"
c += "  s = string.replace(s, '\\n', '\\\\n')\n"
c += "  s = string.replace(s, '\\r', '\\\\r')\n"
c += "  return s\n"
c += "end\n\n"
c += "def " + fn + "(cmd, idx, payload, payload_json)\n"
c += "  var p = _tc_escape(payload)\n"
c += "  tasmota.resp_cmnd('{\"" + command + "\":{\"ok\":true,\"payload\":\"' + p + '\"}}')\n"
c += "end\n\n"
c += "tasmota.add_cmd('" + command + "', " + fn + ")\n"
c += "print('TasmoClaw Berry skill " + command + " loaded')\n"
return {'name':name,'command':command,'source':c}
end
def berry_skill_template(args)
if args == nil
args = {}
end
var t = self.berry_skill_source(args)
return {
'ok':true,
'name':t.find('name'),
'command':t.find('command'),
'content':t.find('source'),
'usage':'Save with berry_skill_create, load with berry_skill_run, then call the registered Tasmota command from console or TasmoClaw.'
}
end
def berry_skill_create(args)
if args == nil
args = {}
end
var p = args.find('path')
var content = args.find('content')
var t = self.berry_skill_source(args)
if p == nil || p == ''
p = self.berry_path(t.find('name'))
end
if content == nil || content == ''
content = args.find('code')
end
if content == nil || content == ''
content = t.find('source')
end
var r = self.file_write({'path':p,'content':content})
if r.find('ok') == true
r['berry_skill'] = true
r['command'] = t.find('command')
if args.find('autoload') == true || args.find('load') == true
r['load'] = self.berry_load({'path':p})
end
end
return r
end
def berry_skill_run(args)
if args == nil
args = {}
end
return self.berry_program_run(args)
end
def berry_skill_explain(args)
if args == nil
args = {}
end
var r = self.berry_program_read(args)
if r.find('ok') == true
r['instruction'] = 'Explain this reusable Berry skill, including the Tasmota command it registers, how to load it, and how to call it.'
r['berry_skill'] = true
end
return r
end
def berry_load(args)
var p=args.find('path')
if p == nil || p == ''
return {'ok':false,'error':'missing path'}
end
try
var r = load(p)
return {'ok':true,'result':str(r)}
except .. as e,m
return {'ok':false,'error':'load failed: '+str(m)}
end
end
def berry_compile(args)
var p=args.find('path')
if p == nil || p == ''
return {'ok':false,'error':'missing path'}
end
try
var r = tasmota.compile(p)
return {'ok':true,'result':str(r)}
except .. as e,m
return {'ok':false,'error':'compile failed: '+str(m)}
end
end
def rule_apply(args)
var r=args.find('rule')
var d=args.find('definition')
if r == nil || r == ''
r = 'Rule1'
end
if r == '1' || r == '2' || r == '3'
r = 'Rule' + str(r)
end
if d == nil || d == ''
return {'ok':false,'error':'missing definition'}
end
try
var cmd1 = r + ' ' + d
var r1 = tasmota.cmd(cmd1, false)
var result = {
'set_command':cmd1,
'set':r1
}
if args.find('enable') == true
var cmd2 = r + ' 1'
var r2 = tasmota.cmd(cmd2, false)
result['enable_command'] = cmd2
result['enable'] = r2
end
if args.find('start_timer1') == true
var seconds = args.find('timer1_seconds')
if seconds == nil || seconds < 1
seconds = 5
end
var cmd3 = 'RuleTimer1 ' + str(seconds)
var r3 = tasmota.cmd(cmd3, false)
result['start_timer_command'] = cmd3
result['start_timer'] = r3
end
return {'ok':true,'result':result}
except .. as e,m
return {'ok':false,'error':'rule apply failed: '+str(m)}
end
end
def rule_clear(args)
var r=args.find('rule')
if r == nil || r == ''
r = 'Rule3'
end
if r == '1' || r == '2' || r == '3'
r = 'Rule' + str(r)
end
try
var cmd1 = r + ' 0'
var r1 = tasmota.cmd(cmd1, false)
var result = {
'disable_command':cmd1,
'disable':r1
}
if args.find('stop_timer1') == true
var cmd_timer = 'RuleTimer1 0'
result['timer_command'] = cmd_timer
result['timer'] = tasmota.cmd(cmd_timer, false)
end
var cmd2 = r + ' "'
var r2 = tasmota.cmd(cmd2, false)
result['clear_command'] = cmd2
result['clear'] = r2
return {'ok':true,'result':result}
except .. as e,m
return {'ok':false,'error':'rule clear failed: '+str(m)}
end
end
def display_message(args)
var msg=args.find('message')
if msg == nil
msg = ''
end
try
var r = tasmota.cmd('DisplayText ' + msg, false)
return {'ok':true,'result':r}
except .. as e,m
return {'ok':false,'error':'DisplayText failed; display may not be configured: '+str(m)}
end
end
def create_demo_berry(args)
var n=args.find('name')
if n == nil || n == ''
n = 'ai_status'
end
n = string.replace(n, '/', '_')
n = string.replace(n, '\\', '_')
n = string.replace(n, ' ', '_')
var p = self.berry_path(n)
var c = "import string\n\n"
c += "def ai_status_cmd(cmd, idx, payload)\n"
c += "  var mem = str(tasmota.memory())\n"
c += "  var wifi = str(tasmota.wifi())\n"
c += "  mem = string.replace(mem, '\"', '\\\\\"')\n"
c += "  wifi = string.replace(wifi, '\"', '\\\\\"')\n"
c += "  var out = '{\"AIStatus\":{\"memory\":\"' + mem + '\",\"wifi\":\"' + wifi + '\"}}'\n"
c += "  tasmota.resp_cmnd(out)\n"
c += "end\n\n"
c += "tasmota.add_cmd('AIStatus', ai_status_cmd)\n"
var r = self.file_write({'path':p,'content':c})
if r['ok']
r['fallback_workspace'] = self.store != nil ? self.store.workspace_fallback : false
end
return r
end
end
var tasmoclaw_tools = module("tasmoclaw_tools")
tasmoclaw_tools.create = def(store)
return TasmoClawTools(store)
end
global.tasmoclaw_tools_mod = tasmoclaw_tools
return tasmoclaw_tools
