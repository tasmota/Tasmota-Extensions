import webserver
import json
import persist
import string
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
for k:d.keys()
if c.find(k) == nil
c[k] = d[k]
end
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
c['https_transport'] = 'webclient'
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
webserver.on('/tasmoclaw', / -> self.page(), webserver.HTTP_GET)
webserver.on('/tasmoclaw/config', / -> self.config_page(), webserver.HTTP_GET)
webserver.on('/tasmoclaw/api/status', / -> self.api_json(self.status()))
webserver.on('/tasmoclaw/api/tools', / -> self.api_json({'ok':true,'tools':self.tool_registry()}))
webserver.on('/tasmoclaw/api/history', / -> self.api_json({'ok':true,'history':self.history}))
webserver.on('/tasmoclaw/api/pending', / -> self.api_json({'ok':true,'pending':self.pending}))
webserver.on('/tasmoclaw/api/config', / -> self.api_json({'ok':true,'config':self.masked_cfg()}), webserver.HTTP_GET)
webserver.on('/tasmoclaw/api/config', / -> self.api_config_post(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/model', / -> self.api_model_post(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/chat', / -> self.api_chat(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/test', / -> self.api_test(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/clear', / -> self.api_clear(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/approve', / -> self.api_approve(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/reject', / -> self.api_reject(), webserver.HTTP_POST)
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
'https_transport':'webclient',
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
self.ui.chat_page()
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
return {'label':provider + ' / ' + str(self.cfg.find('model')),'provider':provider,'api_url':self.cfg.find('api_url'),'model':self.cfg.find('model'),'https_transport':'webclient'}
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
var tools = 'device_read, sensor_read, power_read, rule_control, tasmota_cmd_read, file_list, file_read, power_control, display_control, audio_rtttl_play'
var cap = ' Lite has the nice UI, read tools, file read/list where standard filesystem access works, and selected safe action tools. It cannot write files, create Berry programs, run Berry programs, edit SD files, or use Full-only programming skills. If the user asks for unsupported writes or Berry programming, say this Lite build cannot do that and suggest Full TasmoClaw.'
return 'You are TasmoClaw Lite on Tasmota. Keep answers short. For live device state call a tool first. Tools: ' + tools + '.' + cap + ' Tool format only: <<<TASMOCLAW_TOOL>>> {"tool":"name","args":{},"reason":"why"} <<<END_TASMOCLAW_TOOL>>>. If calling a tool, output only the block. Use tasmota_cmd_read only for read-only commands like Status, State, Power, Time, Uptime, Mem, Module, Template, GPIO, I2CScan, Sensor, Wifi, IPAddress, TelePeriod, Rule1, Rule2, Rule3, Rules. Actions require approval unless auto approval is enabled.'
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
def unsupported_request(user)
var s = string.tolower(str(user))
var wants_write = self.has_text(s, 'write') || self.has_text(s, 'create') || self.has_text(s, 'make') || self.has_text(s, 'save') || self.has_text(s, 'put ') || self.has_text(s, 'run') || self.has_text(s, 'load')
var target_file = self.has_text(s, 'file') || self.has_text(s, 'filesystem') || self.has_text(s, 'file system') || self.has_text(s, 'sd card') || self.has_text(s, 'sdcard')
var target_berry = self.has_text(s, 'berry') || self.has_text(s, 'script') || self.has_text(s, 'program')
if wants_write && (target_file || target_berry)
return 'This is TasmoClaw Lite, so I cannot write files or create/run Berry programs from this build. Use the Full TasmoClaw package for Berry programming and filesystem write tools.'
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
var direct = self.local_power_intent(user)
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
self.history.push({'role':'assistant','content':'Power command result: '+self.enc(dr)})
self.trim_history()
self.api_json({'ok':true,'content':'Power command result: '+self.enc(dr),'result':dr,'tool_trace':self.format_tool_trace(direct.find('tool'), dr)})
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
'rule_control':{'approval':false},
'tasmota_cmd_read':{'approval':false}
}
r['file_list'] = {'approval':false}
r['file_read'] = {'approval':false}
r['power_control'] = {'approval':true}
r['display_control'] = {'approval':true}
r['audio_rtttl_play'] = {'approval':true}
return r
end
def requires_approval(name, args)
return name == 'power_control' || name == 'display_control' || name == 'audio_rtttl_play'
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
def file_read(args)
var p = self.file_path(args)
if p == nil return {'ok':false,'error':'missing path'} end
try
var f = open(p, 'r')
var data = f.read()
f.close()
return {'ok':true,'path':p,'content':self.preview(data, 8192),'bytes':data == nil ? 0 : size(data)}
except .. as e,m
return {'ok':false,'error':str(m),'path':p}
end
end
def file_list(args)
var p = self.file_path(args)
if p == nil p = '/' end
try
if p == '/'
return {'ok':true,'path':p,'result':tasmota.cmd('Ufs', true)}
end
return {'ok':true,'path':p,'note':'Lite can read named files with file_read; directory listing is limited without native filesystem helpers.'}
except .. as e,m
return {'ok':false,'error':str(m),'path':p}
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
def display_control(args)
var msg = args.find('text')
if msg == nil || msg == '' msg = args.find('message') end
if msg == nil || msg == '' return {'ok':false,'error':'missing display text'} end
var cmd = 'DisplayText ' + str(msg)
return {'ok':true,'command':cmd,'result':tasmota.cmd(cmd, true)}
end
def audio_rtttl_play(args)
var tune = args.find('rtttl')
if tune == nil || tune == '' tune = args.find('tune') end
if tune == nil || tune == '' tune = args.find('preset') end
if tune == nil || tune == '' return {'ok':false,'error':'missing rtttl'} end
var cmd = 'I2SRtttl ' + str(tune)
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
elif name == 'rule_control'
return self.rule_control(args)
elif name == 'tasmota_cmd_read'
return self.read_cmd(args.find('command'))
elif name == 'file_read'
return self.file_read(args)
elif name == 'file_list'
return self.file_list(args)
elif name == 'power_control'
return self.power_control(args)
elif name == 'display_control'
return self.display_control(args)
elif name == 'audio_rtttl_play'
return self.audio_rtttl_play(args)
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
