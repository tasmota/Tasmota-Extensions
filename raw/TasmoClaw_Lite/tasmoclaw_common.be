import webserver
import json
import persist
import string
import path
class TasmoClawCommon : Driver
var cfg, history, pending, variant, ui
def init(v, ui_obj)
self.variant = v
self.ui = ui_obj
self.cfg = self.load_cfg()
self.history = []
self.pending = nil
self.register()
end
def defaults()
return {
'provider':'deepseek',
'api_url':'https://api.deepseek.com/chat/completions',
'model':'deepseek-v4-flash',
'api_key':'',
'temperature':0.2,
'max_tokens':650,
'history_limit':4,
'auto_approve_tools':false,
'tested_models':[]
}
end
def cfg_file()
return '/tasmoclaw_lite_config.json'
end
def cfg_key()
return 'tasmoclaw_lite_config_json'
end
def log(msg)
try
if tasmota.loglevel(4)
tasmota.log('TCL-' + self.variant + ': ' + str(msg), 4)
end
except .. as e,m
end
end
def enc(v)
try
return json.dump(v)
except .. as e,m
return '{}'
end
end
def preview(s, n)
if s == nil return '' end
if size(s) <= n return s end
return s[0..n-1]
end
def load_cfg()
var c = self.defaults()
try
var raw = persist.find(self.cfg_key(), nil)
if raw != nil
var o = json.load(raw)
if o != nil
for k:o.keys()
c[k] = o[k]
end
end
end
except .. as e,m
self.log('load config default ' + str(m))
end
return self.normalize(c)
end
def save_cfg()
self.cfg = self.normalize(self.cfg)
try
persist.setmember(self.cfg_key(), self.enc(self.cfg))
persist.save(true)
return {'ok':true}
except .. as e,m
self.log('save config failed ' + str(m))
return {'ok':false,'error':str(m)}
end
end
def normalize(c)
var d = self.defaults()
var clean = {}
for k:d.keys()
clean[k] = c.find(k) == nil ? d[k] : c[k]
end
c = clean
var old_transport_key = 'https_' + 'transport'
if c.find(old_transport_key) != nil
try c.remove(old_transport_key) except .. as e_rm,m_rm end
end
if c['provider'] != 'local_openai'
c['provider'] = 'deepseek'
end
if c['api_url'] == nil || c['api_url'] == ''
c['api_url'] = d['api_url']
end
if c['model'] == nil || c['model'] == ''
c['model'] = c['provider'] == 'local_openai' ? 'local' : 'deepseek-v4-flash'
end
if c['max_tokens'] == nil || c['max_tokens'] < 64
c['max_tokens'] = d['max_tokens']
end
if c['history_limit'] == nil || c['history_limit'] < 0
c['history_limit'] = d['history_limit']
end
if c['auto_approve_tools'] != true
c['auto_approve_tools'] = false
end
if c.find('tested_models') == nil
c['tested_models'] = []
end
return c
end
def masked_cfg()
var c = {}
for k:self.cfg.keys()
c[k] = self.cfg[k]
end
c['api_key'] = '********'
c['prompt_mode'] = self.variant
return c
end
def register()
self.remove_cmds()
tasmota.add_cmd('TasmoClaw', /cmd,idx,payload -> self.cmd_status())
tasmota.add_cmd('TasmoClawLite', /cmd,idx,payload -> self.cmd_status())
tasmota.add_driver(self)
self.web_add_handler()
self.log('registered')
end
def remove_cmds()
try tasmota.remove_cmd('TasmoClaw') except .. as e,m end
try tasmota.remove_cmd('TasmoClawLite') except .. as e,m end
end
def unload()
self.remove_cmds()
self.remove_routes()
self.history = nil
self.pending = nil
self.cfg = nil
try
tasmota.remove_driver(self)
except .. as e,m
end
try
if global.tasmoclaw_common_driver == self
global.tasmoclaw_common_driver = nil
end
except .. as e2,m2
end
try tasmota.gc() except .. as e3,m3 end
end
def stop()
self.unload()
end
def remove_routes()
try webserver.remove_route('/tasmoclaw', webserver.HTTP_GET) except .. as e,m end
try webserver.remove_route('/tasmoclaw/config', webserver.HTTP_GET) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/status') except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/tools') except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/history') except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/pending') except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/config', webserver.HTTP_GET) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/config', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/model', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/chat', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/test', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/clear', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/approve', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/reject', webserver.HTTP_POST) except .. as e,m end
end
def web_add_handler()
webserver.on('/tasmoclaw/api/status', / -> global.tasmoclaw_common_driver.api_json(global.tasmoclaw_common_driver.status()))
webserver.on('/tasmoclaw/api/tools', / -> global.tasmoclaw_common_driver.api_json({'ok':true,'tools':global.tasmoclaw_common_driver.tool_registry()}))
webserver.on('/tasmoclaw/api/history', / -> global.tasmoclaw_common_driver.api_json({'ok':true,'history':global.tasmoclaw_common_driver.history}))
webserver.on('/tasmoclaw/api/pending', / -> global.tasmoclaw_common_driver.api_json({'ok':true,'pending':global.tasmoclaw_common_driver.pending}))
webserver.on('/tasmoclaw/api/config', / -> global.tasmoclaw_common_driver.api_json({'ok':true,'config':global.tasmoclaw_common_driver.masked_cfg()}), webserver.HTTP_GET)
webserver.on('/tasmoclaw/api/config', / -> global.tasmoclaw_common_driver.api_config_post(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/model', / -> global.tasmoclaw_common_driver.api_model_post(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/chat', / -> global.tasmoclaw_common_driver.api_chat(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/test', / -> global.tasmoclaw_common_driver.api_test(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/clear', / -> global.tasmoclaw_common_driver.api_clear(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/approve', / -> global.tasmoclaw_common_driver.api_approve(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/reject', / -> global.tasmoclaw_common_driver.api_reject(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/config', / -> global.tasmoclaw_common_driver.config_page(), webserver.HTTP_GET)
webserver.on('/tasmoclaw', / -> global.tasmoclaw_common_driver.page(), webserver.HTTP_GET)
self.log('web handlers registered')
end
def cmd_status()
tasmota.resp_cmnd(self.enc(self.status()))
end
def web_add_console_button()
end
def web_add_button()
webserver.content_send('<form action="/tasmoclaw" method="get"><button style="background:linear-gradient(135deg,#001a3a,#003eff 46%,#00a3ff);border:1px solid #00d9ff;color:#f5f5f5;box-shadow:0 0 0 1px rgba(255,45,170,.28) inset,0 0 18px rgba(0,163,255,.42),0 0 34px rgba(57,255,20,.10);text-shadow:0 0 6px #ffffff,0 0 14px #00d9ff,0 0 28px #ff2daa;font-weight:800;letter-spacing:.2px">TasmoClaw</button></form><p></p>')
end
def web_add_management_button()
end
def status()
return {
'ok':true,
'variant':self.variant,
'lite':self.variant == 'lite',
'provider':self.cfg.find('provider') == nil ? 'deepseek' : self.cfg['provider'],
'model':self.cfg['model'],
'api_url':self.cfg['api_url'],
'tested_models':self.cfg.find('tested_models') == nil ? [] : self.cfg['tested_models'],
'heap':tasmota.memory(),
'wifi':tasmota.wifi(),
'pending':self.pending != nil
}
end
def api_json(o)
webserver.content_open(200, 'application/json')
webserver.content_send(self.enc(o))
webserver.content_close()
end
def page()
if self.ui != nil
self.ui.chat_page(self.variant)
else
self.page_lite()
end
end
def page_lite()
webserver.content_start('TasmoClaw Lite')
webserver.content_send_style()
webserver.content_send('<style>.tc{max-width:760px;margin:auto;text-align:left}.bar{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px}.box{border:1px solid #345;border-radius:10px;padding:8px;margin:8px 0;background:#111b25;color:#eaf2ff;overflow-wrap:anywhere}textarea{width:100%;box-sizing:border-box;height:72px}.msg{white-space:pre-wrap}.spin{display:none;color:#7dd3fc}.spin.on{display:block}</style>')
webserver.content_send('<div class="tc"><h2>TasmoClaw Lite</h2><div class="bar"><a href="/mn"><button>Tools</button></a><a href="/tasmoclaw/config"><button>Config</button></a><button id="clr">Clear</button></div><div id="st" class="box"></div><div id="log"></div><div id="wait" class="box spin">TasmoClaw thinking...</div><textarea id="m" placeholder="Ask TasmoClaw..."></textarea><button id="send">Send</button><div id="err"></div></div>')
webserver.content_send('<script>const q=id=>document.getElementById(id),log=q("log"),err=q("err"),wait=q("wait");function row(r,t){let d=document.createElement("div");d.className="box msg";d.textContent=r.toUpperCase()+"\\n"+(t||"");log.appendChild(d);scrollTo(0,document.body.scrollHeight)}function js(u,o){return fetch(u,o).then(r=>r.json())}function stat(){js("/tasmoclaw/api/status").then(s=>q("st").textContent="Lite / "+s.model+" / heap "+JSON.stringify(s.heap))}q("send").onclick=()=>{let v=q("m").value.trim();if(!v)return;row("user",v);q("m").value="";wait.className="box spin on";js("/tasmoclaw/api/chat",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({message:v})}).then(x=>{if(x.tool_trace)row("tool",x.tool_trace);row("assistant",x.content||x.error||"");err.textContent=x.error||""}).catch(e=>err.textContent=String(e)).finally(()=>wait.className="box spin")};q("clr").onclick=()=>js("/tasmoclaw/api/clear",{method:"POST"}).then(_=>{log.textContent=""});stat()</script>')
webserver.content_stop()
end
def config_page()
webserver.content_start('TasmoClaw Lite Config')
webserver.content_send_style()
webserver.content_send('<style>.tc{max-width:680px;margin:auto;text-align:left}input,select{width:100%;box-sizing:border-box}</style>')
webserver.content_send('<div class="tc"><h2>TasmoClaw Lite Config</h2><p><a href="/tasmoclaw"><button>Back</button></a></p><label>Provider</label><select id="provider"><option value="deepseek">DeepSeek</option><option value="local_openai">Local OpenAI-compatible</option></select><label>API URL</label><input id="api_url" placeholder="https://api.deepseek.com/chat/completions or http://mac-ip:8080/v1/chat/completions"><label>Model</label><input id="model" list="model_suggestions" placeholder="deepseek-v4-flash or local model id"><datalist id="model_suggestions"><option value="deepseek-v4-flash"><option value="deepseek-v4-pro"><option value="local"></datalist><label>API Key</label><input id="api_key" type="password"><label>Max tokens</label><input id="max_tokens" type="number"><label>History limit</label><input id="history_limit" type="number"><p><label><input id="auto_approve_tools" type="checkbox" style="width:auto"> Disable permission prompts</label></p>')
webserver.content_send('<p><button id="save">Save</button> <button id="test">Test API</button></p><div id="msg"></div></div>')
webserver.content_send('<script>const ids=["provider","api_url","model","api_key","max_tokens","history_limit"],q=id=>document.getElementById(id),msg=q("msg");function pc(){q("api_key").placeholder=q("provider").value=="local_openai"?"optional for local servers":"DeepSeek API key"}q("provider").onchange=pc;fetch("/tasmoclaw/api/config").then(r=>r.json()).then(x=>{let c=x.config||{};ids.forEach(id=>{if(c[id]!=null)q(id).value=c[id]});if(q("auto_approve_tools"))q("auto_approve_tools").checked=!!c.auto_approve_tools;pc()});function body(){let c={};ids.forEach(id=>c[id]=q(id).value);c.max_tokens=parseInt(c.max_tokens);c.history_limit=parseInt(c.history_limit);if(q("auto_approve_tools"))c.auto_approve_tools=q("auto_approve_tools").checked;return c}q("save").onclick=()=>fetch("/tasmoclaw/api/config",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(body())}).then(r=>r.json()).then(x=>msg.textContent=x.ok?"Saved":x.error);q("test").onclick=()=>fetch("/tasmoclaw/api/test",{method:"POST"}).then(r=>r.json()).then(x=>msg.textContent=x.ok?x.content:x.error)</script>')
webserver.content_stop()
end
def api_config_post()
try
var old = self.cfg['api_key']
var o = json.load(webserver.arg('plain'))
for k:o.keys()
self.cfg[k] = o[k]
end
if self.cfg.find('provider') == 'local_openai' && (self.cfg.find('api_key') == nil || self.cfg['api_key'] == '' || self.cfg['api_key'] == '********')
self.cfg['api_key'] = ''
elif self.cfg.find('api_key') == nil || self.cfg['api_key'] == '' || self.cfg['api_key'] == '********'
self.cfg['api_key'] = old
end
self.api_json(self.save_cfg())
except .. as e,m
self.api_json({'ok':false,'error':str(m)})
end
end
def current_model_profile()
var provider = self.cfg.find('provider') == nil ? 'deepseek' : self.cfg['provider']
return {'label':provider + ' / ' + str(self.cfg.find('model')),'provider':provider,'api_url':self.cfg.find('api_url'),'model':self.cfg.find('model')}
end
def same_profile(a, b)
if a == nil || b == nil
return false
end
return a.find('provider') == b.find('provider') && a.find('api_url') == b.find('api_url') && a.find('model') == b.find('model')
end
def remember_tested_model()
var p = self.current_model_profile()
var profiles = self.cfg.find('tested_models')
if profiles == nil
profiles = []
end
var found = false
for old:profiles
if self.same_profile(old, p)
found = true
end
end
if !found
profiles.push(p)
end
while size(profiles) > 8
profiles.remove(0)
end
self.cfg['tested_models'] = profiles
self.save_cfg()
end
def api_model_post()
try
var req = json.load(webserver.arg('plain'))
var idx = req.find('index')
var profiles = self.cfg.find('tested_models')
var selected = nil
if profiles != nil && idx != nil
idx = int(idx)
if idx >= 0 && idx < size(profiles)
selected = profiles[idx]
end
end
if selected == nil
self.api_json({'ok':false,'error':'model has not passed Test API yet'})
return
end
for k:['provider','api_url','model']
if selected.find(k) != nil
self.cfg[k] = selected[k]
end
end
self.api_json(self.save_cfg())
except .. as e,m
self.api_json({'ok':false,'error':str(m)})
end
end
def api_clear()
self.history = []
self.pending = nil
self.api_json({'ok':true})
end
def api_reject()
self.pending = nil
self.api_json({'ok':true})
end
def api_approve()
if self.pending == nil
self.api_json({'ok':false,'error':'no pending action'})
return
end
self.api_json(self.approve_pending())
end
def approve_pending()
var p = self.pending
self.pending = nil
var r = self.run_tool(p.find('tool'), p.find('args'))
var trace = self.format_tool_trace(p.find('tool'), r)
var content = 'Approved TasmoClaw Lite tool ' + str(p.find('tool')) + ' result:\n' + self.enc(r)
self.history.push({'role':'tool','content':trace})
self.history.push({'role':'assistant','content':content})
self.trim_history()
return {'ok':true,'content':content,'result':r}
end
def api_test()
var r = self.llm([{'role':'system','content':'Reply exactly as requested.'},{'role':'user','content':'Reply with exactly: TasmoClaw online.'}], 80)
if r.find('ok') == true
self.remember_tested_model()
end
self.api_json(r)
end
def system_prompt()
var tools = 'device_read, sensor_read, power_read, light_control, timer_control, rule_control, tasmota_cmd_read, ufs_info, file_list, file_read, file_write, file_delete, memory_read, memory_search, memory_append, memory_forget, power_control, display_control, tool_sequence_run'
var cap = ' Lite keeps everyday work tools that fit no-PSRAM stock builds: status/sensors, power/light, simple timers, UFS/FlashFS, local memory, and display text. It cannot search the web, create/run Berry programs, edit SD file contents through Berry, or use Full-only programming skills. For requests like "turn the light on at night every day", choose timer_control/tool_sequence_run and hide the Tasmota command details from the user.'
return 'You are TasmoClaw Lite on Tasmota. Keep answers short and useful. For live device state or device work, call a tool first. Tools: ' + tools + '.' + cap + ' Tool format only: <<<TASMOCLAW_TOOL>>> {"tool":"name","args":{},"reason":"why"} <<<END_TASMOCLAW_TOOL>>>. If calling a tool, output only the block. Use tasmota_cmd_read only for read-only commands like Status, State, Power, Time, Uptime, Mem, Module, Template, GPIO, I2CScan, Sensor, Wifi, IPAddress, TelePeriod, Rule1, Rule2, Rule3, Rules. Actions require approval unless auto approval is enabled.'
end
def messages(user)
var m = [{'role':'system','content':self.system_prompt()}]
for h:self.history
var role = h.find('role')
if role == 'user' || role == 'assistant'
m.push(h)
end
end
m.push({'role':'user','content':user})
return m
end
def has_text(s, needle)
var p = string.find(s, needle)
return p != nil && p >= 0
end
def text_after_marker(user, markers)
var lower = string.tolower(str(user))
for marker:markers
var i = string.find(lower, marker)
if i != nil && i >= 0
return str(user)[i + size(marker) ..]
end
end
return ''
end
def text_before_later_step(s)
if s == nil return '' end
var out = str(s)
var lower = string.tolower(out)
for marker:[' then ', ' and then ', ', then ', ' after that ', ' next ']
var i = string.find(lower, marker)
if i != nil && i >= 0
out = out[0 .. i - 1]
lower = string.tolower(out)
end
end
return out
end
def first_token(s)
if s == nil return '' end
var p = string.split(str(s), ' ')
for item:p
if item != nil && item != ''
return string.replace(string.replace(str(item), ',', ''), '.', '')
end
end
return ''
end
def filename_from_text(user)
if user == nil return nil end
var lower = string.tolower(str(user))
for ext:['.txt','.md','.json','.be','.log','.csv']
var ei = string.find(lower, ext)
if ei != nil && ei >= 0
var start = ei
while start > 0
var ch = lower[start - 1 .. start - 1]
if ch == ' ' || ch == '\n' || ch == '\t' || ch == '"' || ch == '\'' || ch == '`' || ch == ',' || ch == ':'
break
end
start -= 1
end
var stop = ei + size(ext) - 1
while stop + 1 < size(user)
var ch2 = lower[stop + 1 .. stop + 1]
if ch2 == ' ' || ch2 == '\n' || ch2 == '\t' || ch2 == '"' || ch2 == '\'' || ch2 == '`' || ch2 == ',' || ch2 == ':' || ch2 == ';'
break
end
stop += 1
end
return str(user)[start .. stop]
end
end
var mentions_file = false
for marker:[' file', 'file ', 'filename', 'named ', 'called ']
var mi = string.find(lower, marker)
if mi != nil && mi >= 0
mentions_file = true
end
end
if mentions_file
var normalized = lower
for sep:['\n','\t','"','\'','`',',',':',';','(',')','[',']']
normalized = string.replace(normalized, sep, ' ')
end
var parts = string.split(normalized, ' ')
for token:parts
if token != nil && token != ''
var has_name_mark = false
if string.find(token, '_') != nil && string.find(token, '_') >= 0
has_name_mark = true
end
if string.find(token, '-') != nil && string.find(token, '-') >= 0
has_name_mark = true
end
if has_name_mark
var bad = false
for badch:['/','\\','?','&','=','%','#']
var bi = string.find(token, badch)
if bi != nil && bi >= 0
bad = true
end
end
if !bad
return token + '.txt'
end
end
end
end
end
return nil
end
def prefixed_named_path(kind, name)
var n = str(name == nil ? '' : name)
var l = string.tolower(n)
if string.find(l, 'sd:') == 0 || string.find(l, 'flash:') == 0
return n
end
if n == '' n = '/' end
if n[0..0] != '/' n = '/' + n end
return kind + ':' + n
end
def day_mask_from_text(s)
if self.has_text(s, 'weekend')
return 'S-----S'
end
if self.has_text(s, 'weekday') || self.has_text(s, 'week day')
return '-MTWTF-'
end
if self.has_text(s, 'every day') || self.has_text(s, 'daily') || self.has_text(s, 'monday to sunday') || self.has_text(s, 'mon to sun') || self.has_text(s, 'from monday') || self.has_text(s, 'all week')
return 'SMTWTFS'
end
return 'SMTWTFS'
end
def light_schedule_intent(user)
var s = string.tolower(str(user))
var target_light = self.has_text(s, 'light') || self.has_text(s, 'lamp') || self.has_text(s, 'relay') || self.has_text(s, 'power')
var time_word = self.has_text(s, 'night') || self.has_text(s, 'sunset') || self.has_text(s, 'evening') || self.has_text(s, 'dark') || self.has_text(s, 'sunrise') || self.has_text(s, 'morning')
var wants_on = self.has_text(s, 'turn on') || self.has_text(s, 'switch on') || self.has_text(s, 'power on') || self.has_text(s, 'light on')
var wants_off = self.has_text(s, 'turn off') || self.has_text(s, 'switch off') || self.has_text(s, 'power off') || self.has_text(s, 'light off')
if !target_light || !time_word || (!wants_on && !wants_off)
return nil
end
var mode = (self.has_text(s, 'sunrise') || self.has_text(s, 'morning')) ? 1 : 2
var action = wants_off ? 0 : 1
var days = self.day_mask_from_text(s)
var value = '{"Arm":1,"Mode":' + str(mode) + ',"Time":"00:00","Window":0,"Days":"' + days + '","Repeat":1,"Output":1,"Action":' + str(action) + '}'
return {
'tool':'tool_sequence_run',
'args':{
'items':[
{'tool':'timer_control','args':{'kind':'timer','slot':'1','action':'set','value':value}},
{'tool':'timer_control','args':{'kind':'timers','action':'enable'}}
]
},
'reason':'Schedule output 1 with a Tasmota Timer using sunset/sunrise mode and enable timers.'
}
end
def is_yes(user)
var s = string.tolower(str(user))
return s == 'yes' || s == 'y' || s == 'ok' || s == 'okay' || s == 'approve' || s == 'approved' || s == 'confirm' || s == 'go ahead' || s == 'do it'
end
def local_power_intent(user)
var s = string.tolower(str(user))
if !self.has_text(s, 'power')
return nil
end
var action = nil
if self.has_text(s, 'toggle')
action = 'toggle'
elif self.has_text(s, ' off') || self.has_text(s, 'power off') || self.has_text(s, 'power0')
action = 'off'
elif self.has_text(s, ' on') || self.has_text(s, 'power on') || self.has_text(s, 'power1 on')
action = 'on'
end
if action == nil
return nil
end
var slot = nil
if self.has_text(s, 'power2') || self.has_text(s, 'power 2')
slot = '2'
elif self.has_text(s, 'power1') || self.has_text(s, 'power 1')
slot = '1'
end
var args = {'action':action}
if slot != nil
args['slot'] = slot
end
return {'tool':'power_control','args':args,'reason':'User requested power ' + action}
end
def direct_intent(user)
var s = string.tolower(str(user))
var sched = self.light_schedule_intent(user)
if sched != nil
return sched
end
var readish = self.has_text(s, 'what') || self.has_text(s, 'status') || self.has_text(s, 'state') || self.has_text(s, 'alive') || self.has_text(s, 'heap') || self.has_text(s, 'wifi') || self.has_text(s, 'sensor') || self.has_text(s, 'sensors')
var mentions_sensor = self.has_text(s, 'sensor') || self.has_text(s, 'sensors') || self.has_text(s, 'temperature') || self.has_text(s, 'humidity') || self.has_text(s, 'i2c')
var mentions_power = self.has_text(s, 'power') || self.has_text(s, 'relay')
var mentions_device = self.has_text(s, 'alive') || self.has_text(s, 'heap') || self.has_text(s, 'wifi') || self.has_text(s, 'uptime') || mentions_sensor || mentions_power
if readish && mentions_device
if mentions_power && !mentions_sensor && !self.has_text(s, 'wifi') && !self.has_text(s, 'heap') && !self.has_text(s, 'alive')
return {'tool':'power_read','args':{},'reason':'Read current power state.'}
end
if mentions_sensor && !mentions_power && !self.has_text(s, 'wifi') && !self.has_text(s, 'heap') && !self.has_text(s, 'alive')
return {'tool':'sensor_read','args':{},'reason':'Read current sensor state.'}
end
return {'tool':'device_read','args':{},'reason':'Read status, Wi-Fi, heap, sensors, and power state.'}
end
var says_memory = self.has_text(s, 'remember') || self.has_text(s, 'memory')
if says_memory
if self.has_text(s, 'search')
var mq = self.text_after_marker(user, ['search memory for ', 'search for '])
if mq == '' mq = user end
return {'tool':'memory_search','args':{'query':mq},'reason':'Search Lite memory.'}
end
if self.has_text(s, 'forget') || self.has_text(s, 'delete memory')
return {'tool':'memory_forget','args':{'name':'memory.md'},'reason':'Clear Lite memory.'}
end
if self.has_text(s, 'read') || self.has_text(s, 'show') || self.has_text(s, 'what')
return {'tool':'memory_read','args':{'name':'memory.md'},'reason':'Read Lite memory.'}
end
var note = self.text_after_marker(user, ['remember that ', 'remember ', 'note that '])
if note == '' note = user end
return {'tool':'memory_append','args':{'name':'memory.md','content':note},'reason':'Append a Lite memory note.'}
end
if self.has_text(s, 'timer') || self.has_text(s, 'timers')
if self.has_text(s, 'enable')
return {'tool':'timer_control','args':{'kind':'timers','action':'enable'},'reason':'Enable Tasmota timers.'}
elif self.has_text(s, 'disable')
return {'tool':'timer_control','args':{'kind':'timers','action':'disable'},'reason':'Disable Tasmota timers.'}
end
return {'tool':'timer_control','args':{'kind':'timers','action':'read'},'reason':'Read Tasmota timers.'}
end
var named_file = self.filename_from_text(user)
if named_file != nil
var wants_write_file = self.has_text(s, 'write') || self.has_text(s, 'create') || self.has_text(s, 'make') || self.has_text(s, 'save') || self.has_text(s, 'put ')
var wants_read_file = self.has_text(s, 'read') || self.has_text(s, 'show') || self.has_text(s, 'view') || self.has_text(s, 'open') || self.has_text(s, 'cat')
var wants_delete_file = self.has_text(s, 'delete') || self.has_text(s, 'remove') || self.has_text(s, 'erase')
var kind = self.has_text(s, 'sd') ? 'sd' : 'flash'
var fpath = self.prefixed_named_path(kind, named_file)
if wants_write_file
var file_content = self.text_after_marker(user, ['with content ', 'with the content ', 'with text ', 'with the text ', 'containing '])
file_content = self.text_before_later_step(file_content)
if file_content == '' file_content = 'Hello from TasmoClaw Lite\n' end
return {'tool':'file_write','args':{'path':fpath,'content':file_content},'reason':'Write the requested file with stock filesystem tools.'}
elif wants_read_file
return {'tool':'file_read','args':{'path':fpath,'max_bytes':8192},'reason':'Read the requested file with stock filesystem tools.'}
elif wants_delete_file
return {'tool':'file_delete','args':{'path':fpath},'reason':'Delete the requested file with stock filesystem tools.'}
end
end
if self.has_text(s, 'ufs') || self.has_text(s, 'sd card') || self.has_text(s, 'filesystem') || self.has_text(s, 'file system')
if self.has_text(s, 'status') || self.has_text(s, 'info') || self.has_text(s, 'mounted') || self.has_text(s, 'mount')
return {'tool':'ufs_info','args':{},'reason':'Read UFS and SD status.'}
end
if self.has_text(s, 'list') || self.has_text(s, 'show') || self.has_text(s, 'files')
return {'tool':'file_list','args':{'path':self.has_text(s, 'sd') ? 'sd:/' : 'flash:/'},'reason':'List files with stock UFS.'}
end
end
if self.has_text(s, 'light') || self.has_text(s, 'lamp')
var action = nil
if self.has_text(s, 'toggle')
action = 'toggle'
elif self.has_text(s, 'turn on') || self.has_text(s, 'switch on') || self.has_text(s, ' on')
action = 'on'
elif self.has_text(s, 'turn off') || self.has_text(s, 'switch off') || self.has_text(s, ' off')
action = 'off'
elif self.has_text(s, 'brightness') || self.has_text(s, 'dimmer')
action = 'dimmer'
end
if action != nil
var args = {'action':action}
if action == 'dimmer'
args['value'] = '50'
end
return {'tool':'light_control','args':args,'reason':'Control the light without requiring command names.'}
end
end
var says_display = self.has_text(s, 'display') || self.has_text(s, 'screen') || self.has_text(s, 'show on screen') || self.has_text(s, 'show text') || self.has_text(s, 'message')
if says_display && !(self.has_text(s, 'not display') || self.has_text(s, 'not screen') || self.has_text(s, 'do not display') || self.has_text(s, "don't display"))
var dm = self.text_after_marker(user, ['display ', 'screen ', 'show ', 'message ', 'says ', 'say '])
if dm == '' dm = user end
return {'tool':'display_control','args':{'message':dm},'reason':'Show text on the device display.'}
end
return self.local_power_intent(user)
end
def unsupported_request(user)
var s = string.tolower(str(user))
var wants_write = self.has_text(s, 'write') || self.has_text(s, 'create') || self.has_text(s, 'make') || self.has_text(s, 'save') || self.has_text(s, 'put ') || self.has_text(s, 'run') || self.has_text(s, 'load')
var target_sd = self.has_text(s, 'sd card') || self.has_text(s, 'sdcard') || self.has_text(s, ' sd ')
var target_berry = self.has_text(s, 'berry') || self.has_text(s, 'script') || self.has_text(s, 'program')
if wants_write && target_sd
return 'This is TasmoClaw Lite on stock firmware, so I can list SD files but cannot edit SD file contents through Berry. Use the Tasmota web file manager or a host helper for SD content writes.'
end
if wants_write && target_berry
return 'This is TasmoClaw Lite, so I cannot create or run Berry programs from this build. Use the Full TasmoClaw package for Berry programming.'
end
return nil
end
def api_chat()
try
var req = json.load(webserver.arg('plain'))
var user = str(req.find('message'))
if user == nil || user == ''
self.api_json({'ok':false,'error':'missing message'})
return
end
if self.pending != nil && self.is_yes(user)
self.history.push({'role':'user','content':user})
self.api_json(self.approve_pending())
return
end
var unsupported = self.unsupported_request(user)
if unsupported != nil
self.history.push({'role':'user','content':user})
self.history.push({'role':'assistant','content':unsupported})
self.trim_history()
self.api_json({'ok':true,'content':unsupported,'limited':true})
return
end
var direct = self.direct_intent(user)
if direct != nil
if self.requires_approval(direct.find('tool'), direct.find('args')) && self.cfg['auto_approve_tools'] != true
self.pending = direct
self.history.push({'role':'user','content':user})
self.history.push({'role':'assistant','content':'Approval required for '+str(direct.find('tool'))})
self.trim_history()
self.api_json({'ok':true,'approval_required':true,'pending':self.pending,'content':'Approval required for '+str(direct.find('tool'))})
return
end
var dr = self.run_tool(direct.find('tool'), direct.find('args'))
self.history.push({'role':'user','content':user})
self.history.push({'role':'assistant','content':'Tool result: '+self.enc(dr)})
self.trim_history()
self.api_json({'ok':true,'content':'Tool result: '+self.enc(dr),'result':dr,'tool_trace':self.format_tool_trace(direct.find('tool'), dr)})
return
end
var msgs = self.messages(user)
var r = self.llm(msgs, self.cfg['max_tokens'])
if !r['ok']
self.api_json(r)
return
end
var content = r['content']
var tc = self.parse_tool(content)
var trace = ''
if tc != nil
var tool = tc.find('tool')
var args = tc.find('args')
if self.requires_approval(tool, args) && self.cfg['auto_approve_tools'] != true
self.pending = {'tool':tool,'args':args,'reason':tc.find('reason')}
self.api_json({'ok':true,'approval_required':true,'pending':self.pending,'content':'Approval required for '+str(tool)})
return
end
var tr = self.run_tool(tool, args)
trace = self.format_tool_trace(tool, tr)
msgs.push({'role':'assistant','content':content})
msgs.push({'role':'user','content':'TasmoClaw tool result for '+str(tool)+':\n'+self.enc(tr)+'\nNow answer the user briefly.'})
r = self.llm(msgs, self.cfg['max_tokens'])
if r['ok']
content = r['content']
else
content = trace
end
end
self.history.push({'role':'user','content':user})
if trace != ''
self.history.push({'role':'tool','content':trace})
end
self.history.push({'role':'assistant','content':content})
self.trim_history()
self.api_json({'ok':true,'content':content,'tool_trace':trace})
except .. as e,m
self.api_json({'ok':false,'error':str(m)})
end
end
def trim_history()
while size(self.history) > self.cfg['history_limit'] * 2
self.history.remove(0)
end
end
def llm(msgs, max_tokens)
var provider = self.cfg.find('provider') == nil ? 'deepseek' : self.cfg['provider']
if provider != 'local_openai' && (self.cfg['api_key'] == nil || self.cfg['api_key'] == '')
return {'ok':false,'error':'Missing DeepSeek API key'}
end
var payload = self.enc({'model':self.cfg['model'],'messages':msgs,'temperature':self.cfg['temperature'],'max_tokens':max_tokens,'stream':false})
self.log('payload_bytes=' + str(size(payload)))
if provider == 'local_openai' && string.find(str(self.cfg['api_url']), 'http://') == 0
var tr = self.llm_tcp_http(payload)
if tr.find('ok') == true
return tr
end
self.log('tcp local llm failed ' + str(tr.find('error')))
end
var cl = webclient()
try
cl.begin(self.cfg['api_url'])
try
cl.set_timeouts(45000, 15000)
except .. as e1,m1
end
try
cl.use_http10(true)
except .. as e2,m2
end
cl.add_header('Content-Type','application/json')
cl.add_header('Accept','application/json')
cl.add_header('Connection','close')
if provider != 'local_openai' && self.cfg['api_key'] != nil && self.cfg['api_key'] != ''
cl.add_header('Authorization','Bearer '+self.cfg['api_key'])
end
cl.add_header('User-Agent','TasmoClaw-' + self.variant + '/0.1')
var code = cl.POST(payload)
var body = ''
if code >= 0
body = cl.get_string()
end
cl.close()
self.log('http=' + str(code) + ' body=' + str(size(body)))
if code < 0
return {'ok':false,'transport':'webclient','status':code,'error':'HTTP '+str(code)+' from webclient before server response','payload_bytes':size(payload)}
end
if code < 200 || code >= 300
return {'ok':false,'transport':'webclient','status':code,'error':'HTTP '+str(code),'body':self.preview(body,400)}
end
var o = json.load(body)
var c = o['choices'][0]['message']['content']
if c == nil || c == ''
return {'ok':false,'error':'empty response','body':self.preview(body,400)}
end
return {'ok':true,'content':c,'status':code,'transport':'webclient'}
except .. as e,m
try
cl.close()
except .. as e3,m3
end
return {'ok':false,'error':str(m),'transport':'webclient'}
end
end
def http_url_parts(url)
var s = str(url)
if string.find(s, 'http://') != 0
return nil
end
var rest = s[size('http://') ..]
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
return nil
end
return {'host':host,'port':port,'path':path_q}
end
def http_status_from_raw(raw)
try
var e = string.find(raw, '\r\n')
var first = e != nil && e >= 0 ? raw[0 .. e - 1] : raw
var parts = string.split(first, ' ')
if size(parts) >= 2 return int(parts[1]) end
except .. as ex,ms
end
return 0
end
def http_body_from_raw(raw)
var i = string.find(raw, '\r\n\r\n')
if i != nil && i >= 0
return raw[i + 4 ..]
end
i = string.find(raw, '\n\n')
if i != nil && i >= 0
return raw[i + 2 ..]
end
return raw
end
def llm_tcp_http(payload)
var u = self.http_url_parts(self.cfg['api_url'])
if u == nil
return {'ok':false,'transport':'tcpclient','status':-1,'error':'tcpclient local LLM supports plain HTTP only'}
end
var cl = nil
try
cl = tcpclient()
if cl.connect(u.find('host'), u.find('port')) != true
try cl.close() except .. as e0,m0 end
try cl.deinit() except .. as e1,m1 end
return {'ok':false,'transport':'tcpclient','status':-1,'error':'tcp connect failed'}
end
var req = 'POST ' + u.find('path') + ' HTTP/1.0\r\n'
req += 'Host: ' + u.find('host') + '\r\n'
req += 'Content-Type: application/json\r\n'
req += 'Accept: application/json\r\n'
req += 'Connection: close\r\n'
req += 'User-Agent: TasmoClaw-' + self.variant + '/0.1\r\n'
req += 'Content-Length: ' + str(size(payload)) + '\r\n'
req += '\r\n'
req += payload
cl.write(req)
var raw = ''
var start = tasmota.millis()
var last = start
while tasmota.millis() - start < 90000
var chunk = cl.read()
if chunk != nil && size(chunk) > 0
raw += chunk
last = tasmota.millis()
if size(raw) > 28000 break end
elif cl.connected() == false
break
elif tasmota.millis() - last > 15000
break
end
tasmota.delay(25)
end
try cl.close() except .. as e2,m2 end
try cl.deinit() except .. as e3,m3 end
if raw == nil || raw == ''
return {'ok':false,'transport':'tcpclient','status':-1,'error':'empty response'}
end
var code = self.http_status_from_raw(raw)
var body = self.http_body_from_raw(raw)
self.log('tcp_http=' + str(code) + ' body=' + str(size(body)))
if code < 200 || code >= 300
return {'ok':false,'transport':'tcpclient','status':code,'error':'HTTP '+str(code),'body':self.preview(body,400)}
end
var o = json.load(body)
var c = o['choices'][0]['message']['content']
if c == nil || c == ''
return {'ok':false,'error':'empty response','body':self.preview(body,400),'transport':'tcpclient','status':code}
end
return {'ok':true,'content':c,'status':code,'transport':'tcpclient'}
except .. as e,m
try if cl != nil cl.close() end except .. as e4,m4 end
try if cl != nil cl.deinit() end except .. as e5,m5 end
return {'ok':false,'error':str(m),'transport':'tcpclient','status':-1}
end
end
def parse_tool(s)
if s == nil return nil end
var i = string.find(s, '{')
if i == nil || i < 0 return nil end
var e = string.find(s, '<<<END_TASMOCLAW_TOOL>>>')
if e != nil && e > i
s = s[i..e-1]
else
s = s[i..size(s)-1]
end
try
return json.load(s)
except .. as ex,ms
return nil
end
end
def read_cmd(cmd)
var c = string.toupper(str(cmd))
var ok = false
var allowed = ['STATUS','STATE','POWER','POWER1','POWER2','TIME','UPTIME','MEM','MODULE','TEMPLATE','GPIO','I2CSCAN','SENSOR','WIFI','IPADDRESS','TELEPERIOD','RULE1','RULE2','RULE3','RULES']
for a:allowed
if string.find(c, a) == 0
ok = true
end
end
if !ok
return {'ok':false,'error':'not read-only in this build'}
end
if c == 'RULES'
return {'ok':true,'Rule1':tasmota.cmd('Rule1', true),'Rule2':tasmota.cmd('Rule2', true),'Rule3':tasmota.cmd('Rule3', true)}
end
return {'ok':true,'result':tasmota.cmd(cmd, true)}
end
def rule_control(args)
var rule = args == nil ? nil : args.find('rule')
if rule == nil || rule == '' || string.toupper(str(rule)) == 'RULES'
return self.read_cmd('Rules')
end
return self.read_cmd(rule)
end
def format_tool_trace(tool, r)
return 'Tool call: ' + str(tool) + '\nStatus: ' + (r.find('ok') == true ? 'ok' : 'error') + '\nResult: ' + self.enc(r)
end
def tool_registry()
var r = {
'device_read':{'approval':false},
'sensor_read':{'approval':false},
'power_read':{'approval':false},
'light_control':{'approval':true},
'timer_control':{'approval':true},
'rule_control':{'approval':false},
'tasmota_cmd_read':{'approval':false},
'ufs_info':{'approval':false},
'memory_read':{'approval':false},
'memory_search':{'approval':false},
'tool_sequence_run':{'approval':true}
}
r['file_list'] = {'approval':false}
r['file_read'] = {'approval':false}
r['file_write'] = {'approval':true}
r['file_delete'] = {'approval':true}
r['memory_append'] = {'approval':true}
r['memory_forget'] = {'approval':true}
r['power_control'] = {'approval':true}
r['display_control'] = {'approval':true}
return r
end
def requires_approval(name, args)
return name == 'power_control' || name == 'light_control' || name == 'timer_control' || name == 'tool_sequence_run' || name == 'display_control' || name == 'file_write' || name == 'file_delete' || name == 'memory_append' || name == 'memory_forget'
end
def file_path(args)
var p = args.find('path')
if p == nil || p == '' p = args.find('file') end
if p == nil || p == '' p = args.find('name') end
if p == nil || p == '' return nil end
p = str(p)
if string.find(p, 'flash:/') == 0
p = p[6..size(p)-1]
elif string.find(p, 'sd:/') == 0
p = p[3..size(p)-1]
end
if size(p) == 0 || p[0..0] != '/'
p = '/' + p
end
return p
end
def file_fs(args)
var p = args.find('path')
if p == nil || p == '' p = args.find('file') end
if p == nil || p == '' p = args.find('name') end
if p == nil || p == '' return '' end
p = string.tolower(str(p))
if string.find(p, 'sd:/') == 0 || string.find(p, 'sd:') == 0
return 'sd'
elif string.find(p, 'flash:/') == 0 || string.find(p, 'flash:') == 0
return 'flash'
end
return ''
end
def file_read(args)
var p = self.file_path(args)
if p == nil return {'ok':false,'error':'missing path'} end
if self.file_fs(args) == 'sd'
return {'ok':false,'error':'Stock Tasmota Lite cannot read SD file contents through Berry. Use the Tasmota web file manager /ufsd endpoint from a browser or host.','path':p,'fs':'sd'}
end
try
var f = open(p, 'r')
var data = f.read()
f.close()
return {'ok':true,'path':p,'content':self.preview(data, 8192),'bytes':data == nil ? 0 : size(data)}
except .. as e,m
return {'ok':false,'error':str(m),'path':p}
end
end
def file_write(args)
var p = self.file_path(args)
if p == nil return {'ok':false,'error':'missing path'} end
if self.file_fs(args) == 'sd'
return {'ok':false,'error':'Stock Tasmota Lite cannot write SD file contents through Berry. Use the Tasmota web file manager /ufse endpoint from a browser or host.','path':p,'fs':'sd'}
end
var content = args.find('content')
if content == nil content = args.find('text') end
if content == nil content = '' end
try
var f = open(p, 'w')
f.write(str(content))
f.close()
return {'ok':true,'path':p,'bytes':size(str(content)),'fs':'flash'}
except .. as e,m
return {'ok':false,'error':str(m),'path':p}
end
end
def file_delete(args)
var p = self.file_path(args)
if p == nil return {'ok':false,'error':'missing path'} end
if self.file_fs(args) == 'sd'
return {'ok':false,'error':'Lite does not delete SD files directly. Use the stock file manager if needed.','path':p,'fs':'sd'}
end
try
if path.exists(p)
path.remove(p)
end
return {'ok':true,'path':p,'fs':'flash'}
except .. as e,m
return {'ok':false,'error':str(m),'path':p}
end
end
def file_list(args)
var p = self.file_path(args)
if p == nil p = '/' end
try
if self.file_fs(args) == 'sd'
return {'ok':true,'path':p,'fs':'sd','result':tasmota.cmd(p == '/' ? 'UfsList' : 'UfsList ' + p, true)}
elif p == '/'
return {'ok':true,'path':p,'result':tasmota.cmd('Ufs', true)}
end
return {'ok':true,'path':p,'note':'Lite can read named files with file_read; directory listing is limited without native filesystem helpers.'}
except .. as e,m
return {'ok':false,'error':str(m),'path':p}
end
end
def ufs_info(args)
return {'ok':true,'ufs':tasmota.cmd('Ufs', true),'ufstype':tasmota.cmd('UfsType', true),'root':tasmota.cmd('UfsList', true)}
end
def memory_path(args)
var name = args.find('name')
if name == nil || name == '' name = args.find('file') end
if name == nil || name == '' name = 'memory.md' end
var n = string.replace(string.replace(str(name), '/', '_'), '\\', '_')
if string.find(n, '.md') == nil || string.find(n, '.md') < 0
n += '.md'
end
return '/tasmoclaw_lite_' + n
end
def memory_read(args)
return self.file_read({'path':self.memory_path(args)})
end
def memory_append(args)
var note = args.find('content')
if note == nil note = args.find('note') end
if note == nil || note == '' return {'ok':false,'error':'missing note'} end
var existing = ''
var rr = self.memory_read(args)
if rr.find('ok') == true
existing = str(rr.find('content'))
end
var sep = existing == '' ? '' : '\n'
return self.file_write({'path':self.memory_path(args),'content':existing + sep + '- ' + str(note) + '\n'})
end
def memory_forget(args)
return self.file_delete({'path':self.memory_path(args)})
end
def memory_search(args)
var q = string.tolower(str(args.find('query') == nil ? args.find('q') : args.find('query')))
if q == nil || q == '' || q == 'nil' return {'ok':false,'error':'missing query'} end
var hits = []
try
var entries = path.listdir('/')
for item:entries
var name = type(item) == 'string' ? item : str(item[0])
if string.find(name, 'tasmoclaw_lite_') == 0 && string.find(name, '.md') != nil && string.find(name, '.md') >= 0
var r = self.file_read({'path':'/' + name})
if r.find('ok') == true
var body = str(r.find('content'))
var lower = string.tolower(body)
if string.find(lower, q) != nil && string.find(lower, q) >= 0
hits.push({'path':'/' + name,'preview':self.preview(body, 400)})
end
end
end
end
return {'ok':true,'query':q,'hits':hits,'count':size(hits)}
except .. as e,m
return {'ok':false,'error':str(m)}
end
end
def power_cmd_for_slot(slot)
if slot == nil || slot == '' || str(slot) == '1'
return 'Power'
end
return 'Power' + str(slot)
end
def power_state()
var states = tasmota.get_power()
var out = {'ok':true,'states':states,'relay_count':states == nil ? 0 : size(states)}
if states != nil && size(states) > 0
out['POWER'] = states[0] ? 'ON' : 'OFF'
out['POWER1'] = out['POWER']
end
if states != nil && size(states) > 1
out['POWER2'] = states[1] ? 'ON' : 'OFF'
end
return out
end
def power_control(args)
var slot = args.find('slot')
if slot == nil || slot == '' slot = args.find('index') end
if slot == nil || slot == '' slot = args.find('device') end
if slot == nil || slot == '' slot = args.find('channel') end
if slot == nil || slot == '' slot = args.find('relay') end
var action = args.find('action')
if action == nil || action == '' action = args.find('power') end
if action == nil || action == '' action = args.find('state') end
if action == nil || action == '' action = args.find('value') end
if action == nil || action == '' action = args.find('command') end
if action == nil || action == '' action = 'read' end
var slot_idx = 0
if slot != nil && slot != ''
slot_idx = int(slot) - 1
if slot_idx < 0 slot_idx = 0 end
end
var cmd = self.power_cmd_for_slot(slot)
var a = string.tolower(str(action))
if a == '1' || a == 'true'
a = 'on'
elif a == '0' || a == 'false'
a = 'off'
end
if a == 'read' || a == 'status' || a == 'state'
return self.power_state()
elif a == 'toggle'
var states = tasmota.get_power()
if states == nil || slot_idx >= size(states)
return {'ok':false,'error':'relay slot not available','slot':slot_idx + 1,'states':states}
end
tasmota.set_power(slot_idx, !states[slot_idx])
elif a == 'on'
tasmota.set_power(slot_idx, true)
elif a == 'off'
tasmota.set_power(slot_idx, false)
else
return {'ok':false,'error':'unsupported power action '+str(action)}
end
var result = self.power_state()
result['command'] = cmd + ' ' + a
return result
end
def light_control(args)
var action = args.find('action')
if action == nil || action == '' action = args.find('mode') end
if action == nil || action == '' action = 'read' end
var a = string.tolower(str(action))
if a == 'read' || a == 'status'
return {'ok':true,'command':'State','result':tasmota.cmd('State', true)}
elif a == 'on' || a == 'off' || a == 'toggle'
return self.power_control({'action':a,'slot':args.find('slot')})
elif a == 'dimmer' || a == 'brightness'
var value = args.find('value')
if value == nil || value == '' value = args.find('brightness') end
if value == nil || value == '' value = '50' end
var cmd = 'Dimmer ' + str(value)
return {'ok':true,'command':cmd,'result':tasmota.cmd(cmd, true)}
elif a == 'color' || a == 'colour'
var color = args.find('value')
if color == nil || color == '' color = args.find('color') end
if color == nil || color == '' color = 'FFFFFF' end
var ccmd = 'Color ' + str(color)
return {'ok':true,'command':ccmd,'result':tasmota.cmd(ccmd, true)}
end
return {'ok':false,'error':'unsupported light action '+str(action)}
end
def timer_control(args)
var kind = string.tolower(str(args.find('kind') == nil ? args.find('type') : args.find('kind')))
var action = string.tolower(str(args.find('action') == nil ? args.find('mode') : args.find('action')))
if kind == nil || kind == '' || kind == 'nil' kind = 'timers' end
if action == nil || action == '' || action == 'nil' action = 'read' end
if kind == 'timers'
if action == 'enable' || action == 'on'
return {'ok':true,'command':'Timers 1','result':tasmota.cmd('Timers 1', true)}
elif action == 'disable' || action == 'off'
return {'ok':true,'command':'Timers 0','result':tasmota.cmd('Timers 0', true)}
end
return {'ok':true,'command':'Timers','result':tasmota.cmd('Timers', true)}
end
var slot = args.find('slot')
if slot == nil || slot == '' slot = args.find('timer') end
if slot == nil || slot == '' slot = '1' end
var cmd = 'Timer' + str(slot)
if action == 'read' || action == 'status' || action == 'show'
return {'ok':true,'command':cmd,'result':tasmota.cmd(cmd, true)}
end
var value = args.find('value')
if value == nil || value == '' value = args.find('definition') end
if value == nil || value == '' value = args.find('json') end
if value == nil || value == ''
return {'ok':false,'error':'missing timer value'}
end
var full = cmd + ' ' + str(value)
return {'ok':true,'command':full,'result':tasmota.cmd(full, true)}
end
def tool_sequence_run(args)
var items = args.find('items')
if items == nil return {'ok':false,'error':'missing items'} end
var results = []
for item:items
results.push({'tool':item.find('tool'),'result':self.run_tool(item.find('tool'), item.find('args'))})
end
return {'ok':true,'results':results,'count':size(results)}
end
def display_control(args)
var msg = args.find('text')
if msg == nil || msg == '' msg = args.find('message') end
if msg == nil || msg == '' return {'ok':false,'error':'missing display text'} end
var cmd = 'DisplayText ' + str(msg)
return {'ok':true,'command':cmd,'result':tasmota.cmd(cmd, true)}
end
def run_tool(name, args)
if args == nil args = {} end
if name == 'device_read'
return {'ok':true,'status':tasmota.cmd('Status 0', true),'sensors':tasmota.cmd('Status 8', true),'power':self.power_state(),'heap':tasmota.memory(),'wifi':tasmota.wifi()}
elif name == 'sensor_read'
return {'ok':true,'sensors':tasmota.cmd('Status 8', true),'i2c':tasmota.cmd('I2CScan', true)}
elif name == 'power_read'
return self.power_state()
elif name == 'light_control'
return self.light_control(args)
elif name == 'timer_control'
return self.timer_control(args)
elif name == 'rule_control'
return self.rule_control(args)
elif name == 'tasmota_cmd_read'
return self.read_cmd(args.find('command'))
elif name == 'ufs_info'
return self.ufs_info(args)
elif name == 'file_read'
return self.file_read(args)
elif name == 'file_list'
return self.file_list(args)
elif name == 'file_write'
return self.file_write(args)
elif name == 'file_delete'
return self.file_delete(args)
elif name == 'memory_read'
return self.memory_read(args)
elif name == 'memory_search'
return self.memory_search(args)
elif name == 'memory_append'
return self.memory_append(args)
elif name == 'memory_forget'
return self.memory_forget(args)
elif name == 'tool_sequence_run'
return self.tool_sequence_run(args)
elif name == 'power_control'
return self.power_control(args)
elif name == 'display_control'
return self.display_control(args)
end
return {'ok':false,'error':'unknown tool '+str(name)+' in '+self.variant}
end
end
var tasmoclaw_common = module("tasmoclaw_common")
tasmoclaw_common.start = def(variant, ui)
try
if global.tasmoclaw_common_driver != nil
global.tasmoclaw_common_driver.unload()
end
except .. as e0,m0
end
global.tasmoclaw_common_driver = TasmoClawCommon(variant, ui)
return global.tasmoclaw_common_driver
end
return tasmoclaw_common
