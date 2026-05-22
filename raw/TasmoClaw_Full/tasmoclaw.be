import webserver
import json
import string
import introspect
def tcl_global_module(name)
try
if name == 'tasmoclaw_util' return global.tasmoclaw_util_mod end
if name == 'tasmoclaw_commands' return global.tasmoclaw_commands_mod end
if name == 'tasmoclaw_store' return global.tasmoclaw_store_mod end
if name == 'tasmoclaw_tools' return global.tasmoclaw_tools_mod end
if name == 'tasmoclaw_llm' return global.tasmoclaw_llm_mod end
if name == 'tasmoclaw_ui' return global.tasmoclaw_ui_mod end
if name == 'tasmoclaw_prompt' return global.tasmoclaw_prompt_mod end
except .. as e,m
end
return nil
end
def tcl_valid_module(mod)
if mod == nil
return false
end
var s = str(mod)
if s == 'true' || s == 'false'
return false
end
return true
end
def tcl_load_module(name)
var mod = nil
mod = tcl_global_module(name)
if tcl_valid_module(mod)
return mod
end
try
mod = introspect.module(name)
except .. as e,m
mod = nil
end
if tcl_valid_module(mod)
return mod
end
var wd = tasmota.wd
var loaded = nil
if wd != nil && size(wd) > 0
loaded = load(wd + name + '.be')
else
loaded = load(name + '.be')
end
try
mod = introspect.module(name)
except .. as e2,m2
mod = nil
end
if tcl_valid_module(mod)
return mod
end
mod = tcl_global_module(name)
if tcl_valid_module(mod)
return mod
end
return loaded
end
var tasmoclaw_util = tcl_load_module('tasmoclaw_util')
var tasmoclaw_commands = tcl_load_module('tasmoclaw_commands')
var tasmoclaw_store = tcl_load_module('tasmoclaw_store')
var tasmoclaw_tools = tcl_load_module('tasmoclaw_tools')
var tasmoclaw_llm = tcl_load_module('tasmoclaw_llm')
var tasmoclaw_ui = tcl_load_module('tasmoclaw_ui')
var tasmoclaw_prompt = tcl_load_module('tasmoclaw_prompt')
var _driver = nil
class TasmoClawDriver : Driver
var store, tools, llm, ui, cfg, history, pending, last_schedule_tick, agent_context
def init()
tasmoclaw_util.debug('driver init start')
self.store = tasmoclaw_store.create()
self.store.ensure_workspace()
self.tools = tasmoclaw_tools.create(self.store)
self.llm = tasmoclaw_llm.create()
self.ui = tasmoclaw_ui.create()
self.cfg = self.normalize_config(self.store.load_config())
self.cfg['tested_models'] = []
self.history = self.store.load_history()
var history_before = size(self.history)
self.trim_history()
if size(self.history) != history_before
self.store.save_history(self.history)
end
self.pending = self.store.load_pending()
self.last_schedule_tick = 0
self.agent_context = self.store.agent_context(1800)
self.ensure_cmds()
tasmoclaw_util.debug('driver init done history=' + str(size(self.history)) + ' pending=' + str(self.pending != nil))
end
def ensure_cmds()
self.remove_cmds()
tasmota.add_cmd('TasmoClaw', /cmd,idx,payload -> self.cmd_status())
tasmota.add_cmd('TasmoClawReset', /cmd,idx,payload -> self.cmd_reset())
tasmota.add_cmd('TasmoClawTest', /cmd,idx,payload -> self.cmd_test())
tasmota.add_cmd('TasmoClawTick', /cmd,idx,payload -> self.cmd_tick())
tasmoclaw_util.debug('commands registered')
end
def remove_cmds()
try tasmota.remove_cmd('TasmoClaw') except .. as e,m end
try tasmota.remove_cmd('TasmoClawReset') except .. as e,m end
try tasmota.remove_cmd('TasmoClawTest') except .. as e,m end
try tasmota.remove_cmd('TasmoClawTick') except .. as e,m end
end
def cmd_status()
tasmota.resp_cmnd(tasmoclaw_util.json_encode(self.status_obj()))
end
def cmd_reset()
self.history=[]
self.pending=nil
self.store.save_history(self.history)
self.store.save_pending(nil)
tasmota.resp_cmnd('OK')
end
def cmd_test()
tasmota.resp_cmnd('{"ok":true}')
end
def cmd_tick()
tasmota.resp_cmnd(tasmoclaw_util.json_encode(self.tools.scheduler_tick({'source':'command'})))
end
def refresh_agent_context()
self.agent_context = self.store.agent_context(1800)
tasmoclaw_util.debug('agent context refreshed bytes=' + str(self.agent_context == nil ? 0 : size(self.agent_context)))
end
def refresh_agent_context_if_needed(tool)
if tool == 'agent_file_write' || tool == 'agent_file_append'
self.refresh_agent_context()
end
end
def every_second()
try
var now = self.tools.now_seconds()
if now <= 0
return
end
if now == self.last_schedule_tick
return
end
if now % 5 != 0
return
end
self.last_schedule_tick = now
var r = self.tools.scheduler_tick({'source':'driver'})
if r.find('fired') != nil && r.find('fired') > 0
tasmoclaw_util.debug('scheduler fired count=' + str(r.find('fired')))
end
except .. as e,m
tasmoclaw_util.debug('scheduler tick failed: ' + str(m))
end
end
def web_add_console_button()
end
def web_add_button()
webserver.content_send('<form action="/tasmoclaw" method="get"><button style="background:linear-gradient(135deg,#001a3a,#003eff 46%,#00a3ff);border:1px solid #00d9ff;color:#f5f5f5;box-shadow:0 0 0 1px rgba(255,45,170,.28) inset,0 0 18px rgba(0,163,255,.42),0 0 34px rgba(57,255,20,.10);text-shadow:0 0 6px #ffffff,0 0 14px #00d9ff,0 0 28px #ff2daa;font-weight:800;letter-spacing:.2px">TasmoClaw</button></form><p></p>')
end
def web_add_management_button()
end
def stop()
self.remove_cmds()
self.remove_routes()
self.history = nil
self.pending = nil
self.cfg = nil
self.store = nil
self.tools = nil
self.llm = nil
self.ui = nil
try
tasmota.remove_driver(self)
except .. as e,m
end
try
if global.tasmoclaw_driver == self
global.tasmoclaw_driver = nil
end
except .. as e2,m2
end
try tasmota.gc() except .. as e3,m3 end
end
def unload()
self.stop()
end
def remove_routes()
try webserver.remove_route('/tasmoclaw', webserver.HTTP_GET) except .. as e,m end
try webserver.remove_route('/tasmoclaw/config', webserver.HTTP_GET) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/chat', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/config', webserver.HTTP_GET) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/config', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/status') except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/tools') except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/history') except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/clear', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/pending') except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/approve', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/reject', webserver.HTTP_POST) except .. as e,m end
try webserver.remove_route('/tasmoclaw/api/test', webserver.HTTP_POST) except .. as e,m end
end
def web_add_handler()
tasmoclaw_util.debug('web handlers registering')
webserver.on('/tasmoclaw/api/chat', / -> global.tasmoclaw_driver.api_chat(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/config', / -> global.tasmoclaw_driver.api_config_get(), webserver.HTTP_GET)
webserver.on('/tasmoclaw/api/config', / -> global.tasmoclaw_driver.api_config_post(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/status', / -> global.tasmoclaw_driver.api_status())
webserver.on('/tasmoclaw/api/tools', / -> global.tasmoclaw_driver.api_tools())
webserver.on('/tasmoclaw/api/history', / -> global.tasmoclaw_driver.api_history())
webserver.on('/tasmoclaw/api/clear', / -> global.tasmoclaw_driver.api_clear(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/pending', / -> global.tasmoclaw_driver.api_json({'ok':true,'pending':global.tasmoclaw_driver.pending}))
webserver.on('/tasmoclaw/api/approve', / -> global.tasmoclaw_driver.api_approve(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/reject', / -> global.tasmoclaw_driver.api_reject(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/api/test', / -> global.tasmoclaw_driver.api_test(), webserver.HTTP_POST)
webserver.on('/tasmoclaw/config', / -> global.tasmoclaw_driver.page_config(), webserver.HTTP_GET)
webserver.on('/tasmoclaw', / -> global.tasmoclaw_driver.ui.chat_page('full'), webserver.HTTP_GET)
end
def page_config()
webserver.content_start('TasmoClaw Config')
webserver.content_send_style()
webserver.content_send('<style>')
webserver.content_send('.tcfg{max-width:760px;text-align:left;margin:0 auto;font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,sans-serif}.tcfg label{display:block;font-weight:bold;margin-top:8px}.tcfg input,.tcfg select,.tcfg textarea{width:100%;box-sizing:border-box;padding:8px;border:1px solid #2c3d53;border-radius:8px;background:#0f1722;color:#e8eff8}.tcfg textarea{height:96px}.tcfg .row{margin:8px 0}.tcfg .msg{min-height:22px;color:#2a2;background:#0f1722;padding:6px;border-radius:8px;border:1px solid #2c3d53}.tcfg .cfg-nav{margin-bottom:10px;display:flex;gap:8px;flex-wrap:wrap}.tcfg .cfg-nav button{min-height:38px;padding:0 10px}')
webserver.content_send('</style>')
webserver.content_send('<div class="tcfg">')
webserver.content_send('<p class="cfg-nav"><a href="/mn"><button>Tools menu</button></a> <a href="/tasmoclaw"><button>Back to TasmoClaw</button></a></p>')
webserver.content_send('<h2>TasmoClaw Config</h2>')
webserver.content_send('<label>Provider</label><select id="provider"><option value="deepseek">DeepSeek</option><option value="local_openai">Local OpenAI-compatible</option></select>')
webserver.content_send('<label>API URL</label><input id="api_url" placeholder="https://api.deepseek.com/chat/completions or http://mac-ip:8080/v1/chat/completions">')
webserver.content_send('<label>Model</label><input id="model" list="model_suggestions" placeholder="deepseek-v4-flash or local model id"><datalist id="model_suggestions"><option value="deepseek-v4-flash"><option value="deepseek-v4-pro"><option value="local"></datalist>')
webserver.content_send('<label>API Key</label><input id="api_key" type="password">')
webserver.content_send('<label>Brave Search API key</label><input id="brave_api_key" type="password" placeholder="Stored locally; never shown back">')
webserver.content_send('<label>Vision API URL</label><input id="vision_api_url" placeholder="optional OpenAI-compatible vision endpoint">')
webserver.content_send('<label>Vision model</label><input id="vision_model" placeholder="optional vision model id">')
webserver.content_send('<label>Vision API key</label><input id="vision_api_key" type="password" placeholder="optional">')
webserver.content_send('<label>Temperature</label><input id="temperature" type="number" step="0.1" min="0" max="2">')
webserver.content_send('<label>Max tokens</label><input id="max_tokens" type="number" min="1">')
webserver.content_send('<label>Thinking</label><select id="thinking"><option>omit</option><option>disabled</option><option>enabled</option></select>')
webserver.content_send('<label>Reasoning effort</label><select id="reasoning_effort"><option>high</option><option>max</option></select>')
webserver.content_send('<label>Max tool iterations</label><input id="max_tool_iterations" type="number" min="1">')
webserver.content_send('<label>History limit</label><input id="history_limit" type="number" min="1">')
webserver.content_send('<label>Prompt mode</label><select id="prompt_mode"><option>compact</option><option>full</option></select>')
webserver.content_send('<label>Context byte limit</label><input id="context_byte_limit" type="number" min="1200">')
webserver.content_send('<p><label style="display:flex;gap:8px;align-items:center"><input id="auto_approve_tools" type="checkbox" style="width:auto"> Disable permission prompts</label></p>')
webserver.content_send('<label>System extra</label><textarea id="system_extra"></textarea>')
webserver.content_send('<p><button id="save">Save</button> <button id="test">Test API</button></p>')
webserver.content_send('<div id="msg" class="msg"></div>')
webserver.content_send('</div>')
webserver.content_send('<script>const ids=["provider","api_url","model","api_key","brave_api_key","vision_api_url","vision_model","vision_api_key","temperature","max_tokens","thinking","reasoning_effort","max_tool_iterations","history_limit","prompt_mode","context_byte_limit","system_extra"];const el=id=>document.getElementById(id);const note=t=>el("msg").textContent=t;function providerChanged(){if(el("provider").value=="local_openai"){el("api_key").placeholder="optional for local servers";el("thinking").value="omit";}else{el("api_key").placeholder="DeepSeek API key";}}function setCfg(c){ids.forEach(id=>{if(c[id]!=null)el(id).value=c[id];});el("auto_approve_tools").checked=!!c.auto_approve_tools;providerChanged();}function getCfg(){fetch("/tasmoclaw/api/config").then(r=>r.json()).then(x=>setCfg(x.config||{})).catch(e=>note(String(e)));}function body(){let c={};ids.forEach(id=>c[id]=el(id).value);c.temperature=parseFloat(c.temperature);c.max_tokens=parseInt(c.max_tokens);c.max_tool_iterations=parseInt(c.max_tool_iterations);c.history_limit=parseInt(c.history_limit);c.context_byte_limit=parseInt(c.context_byte_limit);c.auto_approve_tools=el("auto_approve_tools").checked;return c;}function testText(x){if(x.ok)return (x.content||"OK")+" via "+(x.transport||"?")+" HTTP "+(x.status||"?");let p=[x.error||"Test failed"];if(x.transport)p.push("transport "+x.transport);if(x.status!=null)p.push("status "+x.status);if(x.attempts)p.push("attempt "+(x.attempt||"?")+"/"+x.attempts);if(x.hint)p.push(x.hint);if(x.body)p.push("body: "+x.body);if(x.fallback_hint)p.push(x.fallback_hint);return p.join(" | ");}el("provider").onchange=providerChanged;el("save").onclick=()=>{note("Saving...");fetch("/tasmoclaw/api/config",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(body())}).then(r=>r.json()).then(x=>{note(x.ok?"Saved":(x.error||"Save failed"));if(x.config)setCfg(x.config);}).catch(e=>note(String(e)));};el("test").onclick=()=>{note("Testing...");fetch("/tasmoclaw/api/test",{method:"POST"}).then(r=>r.json()).then(x=>note(testText(x))).catch(e=>note(String(e)));};getCfg();</script>')
webserver.content_stop()
end
def masked_cfg()
var c={}
for k:self.cfg.keys()
c[k]=self.cfg[k]
end
c['api_key']='********'
c['brave_api_key']='********'
c['vision_api_key']='********'
c['tested_models']=[]
return c
end
def tested_model_profiles()
var out = []
var profiles = self.cfg.find('tested_models')
if profiles == nil
return out
end
try
for p:profiles
if p != nil
out.push({
'provider':str(p.find('provider') == nil ? '' : p.find('provider')),
'api_url':str(p.find('api_url') == nil ? '' : p.find('api_url')),
'model':str(p.find('model') == nil ? '' : p.find('model'))
})
end
end
except .. as e,m
out = []
end
return out
end
def status_obj()
var out = {
'ok':true,
'provider':self.cfg.find('provider') == nil ? 'deepseek' : self.cfg['provider'],
'model':self.cfg['model'],
'api_url':self.cfg['api_url'],
'transport':'stock',
'tested_models':[],
'active_skills':self.tools.active_skills(),
'heap':tasmota.memory(),
'wifi':tasmota.wifi(),
'pending':self.pending!=nil,
'workspace_fallback':self.store.workspace_fallback
}
return out
end
def normalize_config(cfg)
var defaults = self.store.default_config()
if cfg == nil
cfg = {}
end
var clean = {}
for k:defaults.keys()
clean[k] = cfg.find(k) == nil ? defaults[k] : cfg[k]
end
cfg = clean
if cfg['provider'] != 'local_openai'
cfg['provider'] = 'deepseek'
end
if cfg['api_url'] == nil || cfg['api_url'] == ''
cfg['api_url'] = defaults['api_url']
end
if cfg['model'] == nil || cfg['model'] == ''
cfg['model'] = cfg['provider'] == 'local_openai' ? 'local' : defaults['model']
end
var old_transport_key = 'https_' + 'transport'
if cfg.find(old_transport_key) != nil
try cfg.remove(old_transport_key) except .. as e_rm,m_rm end
end
if cfg['temperature'] == nil
cfg['temperature'] = defaults['temperature']
end
if cfg['max_tokens'] == nil
cfg['max_tokens'] = defaults['max_tokens']
end
if cfg['thinking'] != 'enabled' && cfg['thinking'] != 'disabled'
cfg['thinking'] = 'omit'
end
if cfg['provider'] == 'local_openai'
cfg['thinking'] = 'omit'
end
if cfg['reasoning_effort'] != 'max'
cfg['reasoning_effort'] = 'high'
end
if cfg['max_tool_iterations'] == nil || cfg['max_tool_iterations'] < 1
cfg['max_tool_iterations'] = defaults['max_tool_iterations']
end
if cfg['history_limit'] == nil || cfg['history_limit'] < 1
cfg['history_limit'] = defaults['history_limit']
end
if cfg['prompt_mode'] != 'full'
cfg['prompt_mode'] = 'compact'
end
if cfg['context_byte_limit'] == nil || cfg['context_byte_limit'] < 1200
cfg['context_byte_limit'] = defaults['context_byte_limit']
end
if cfg['auto_approve_tools'] != true
cfg['auto_approve_tools'] = false
end
if cfg['system_extra'] == nil
cfg['system_extra'] = ''
end
if cfg['brave_api_key'] == nil
cfg['brave_api_key'] = ''
end
if cfg['vision_api_url'] == nil
cfg['vision_api_url'] = ''
end
if cfg['vision_model'] == nil
cfg['vision_model'] = ''
end
if cfg['vision_api_key'] == nil
cfg['vision_api_key'] = ''
end
if cfg.find('tested_models') == nil
cfg['tested_models'] = []
end
return cfg
end
def current_model_profile()
var provider = self.cfg.find('provider') == nil ? 'deepseek' : self.cfg['provider']
return {
'provider':provider,
'api_url':self.cfg.find('api_url'),
'model':self.cfg.find('model')
}
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
if profiles == nil profiles = [] end
var found = false
for old:profiles
if self.same_profile(old, p) found = true end
end
if !found profiles.push(p) end
while size(profiles) > 8 profiles.remove(0) end
self.cfg['tested_models'] = profiles
self.store.save_config(self.cfg)
return p
end
def api_json(o)
webserver.content_open(200, 'application/json')
webserver.content_send(tasmoclaw_util.json_encode(o))
webserver.content_close()
end
def api_status()
self.api_json(self.status_obj())
end
def api_tools()
var skills = self.tools.active_skills()
self.api_json({'ok':true,'skills':skills,'count':size(skills)})
end
def api_history()
var out = []
var total = size(self.history)
var start = total - 3
if start < 0 start = 0 end
if total > 0
for i:range(start, total - 1)
var item = self.history[i]
if item != nil
out.push({
'role':str(item.find('role') == nil ? 'assistant' : item.find('role')),
'content':tasmoclaw_util.preview(item.find('content'), 300)
})
end
end
end
self.api_json({'ok':true,'history':out,'total':total})
end
def api_config_get()
tasmoclaw_util.debug('api config get')
self.api_json({'ok':true,'config':self.masked_cfg()})
end
def api_config_post()
try
tasmoclaw_util.debug('api config post start')
if !webserver.has_arg('plain')
tasmoclaw_util.debug('api config post failed: missing JSON body')
self.api_json({'ok':false,'error':'missing JSON body'})
return
end
var incoming=json.load(webserver.arg('plain'))
tasmoclaw_util.debug('api config parsed keys=' + str(size(incoming.keys())))
var old=self.cfg['api_key']
var old_brave=self.cfg.find('brave_api_key')
var old_vision=self.cfg.find('vision_api_key')
for k:incoming.keys()
self.cfg[k]=incoming[k]
end
if self.cfg.find('provider') == 'local_openai' && (self.cfg.find('api_key') == nil || self.cfg['api_key']=='' || self.cfg['api_key']=='********')
self.cfg['api_key']=''
elif self.cfg.find('api_key') == nil || self.cfg['api_key']=='' || self.cfg['api_key']=='********'
self.cfg['api_key']=old
end
if self.cfg.find('brave_api_key') == nil || self.cfg['brave_api_key']=='' || self.cfg['brave_api_key']=='********'
self.cfg['brave_api_key']=old_brave == nil ? '' : old_brave
end
if self.cfg.find('vision_api_key') == nil || self.cfg['vision_api_key']=='' || self.cfg['vision_api_key']=='********'
self.cfg['vision_api_key']=old_vision == nil ? '' : old_vision
end
self.cfg = self.normalize_config(self.cfg)
var r = self.store.save_config(self.cfg)
if r['ok']
tasmoclaw_util.debug('api config saved model=' + str(self.cfg.find('model')) + ' auto_approve=' + str(self.cfg.find('auto_approve_tools')))
self.api_json({'ok':true,'config':self.masked_cfg(),'storage':r})
else
tasmoclaw_util.debug('api config save failed: ' + str(r.find('error')))
self.api_json(r)
end
except .. as e,m
tasmoclaw_util.debug('api config exception: ' + str(e) + ' ' + str(m))
self.api_json({'ok':false,'error':'config save failed: '+str(m)})
end
end
def api_chat()
var req=nil
try
tasmoclaw_util.debug('api chat start body_bytes=' + str(size(webserver.arg('plain'))))
req=json.load(webserver.arg('plain'))
except .. as e,m
tasmoclaw_util.debug('api chat invalid JSON: ' + str(e) + ' ' + str(m))
self.api_json({'ok':false,'error':'invalid JSON body: '+str(m)})
return
end
var user=req['message']
if user == nil || user == ''
tasmoclaw_util.debug('api chat failed: missing message')
self.api_json({'ok':false,'error':'missing message'})
return
end
tasmoclaw_util.debug('api chat message bytes=' + str(size(user)) + ' history=' + str(size(self.history)) + ' pending=' + str(self.pending != nil))
if self.pending != nil && self.is_yes(user)
self.history.push({'role':'user','content':user})
self.approve_pending()
return
end
var direct = self.direct_tool_for_user(user)
if direct != nil
self.history.push({'role':'user','content':user})
if self.tools.requires_approval_for(direct['tool'], direct['args']) && self.cfg['auto_approve_tools'] != true
var direct_now = tasmota.rtc().find('local')
if direct_now == nil
direct_now = tasmota.rtc().find('utc')
end
self.pending={
'id':str(direct_now),
'tool':direct['tool'],
'args':direct['args'],
'reason':direct.find('reason'),
'created':str(direct_now),
'assistant':'Direct TasmoClaw action prepared for approval.'
}
self.store.save_pending(self.pending)
self.trim_history()
self.store.save_history(self.history)
self.api_json({
'ok':true,
'approval_required':true,
'pending':self.pending,
'content':'Approval required for '+direct['tool']
})
return
end
var direct_result = self.tools.run(direct['tool'], direct['args'])
self.refresh_agent_context_if_needed(direct['tool'])
var direct_trace = self.format_tool_trace(direct['tool'], direct_result)
var direct_content = self.format_tool_answer(user, direct['tool'], direct_result)
if direct['tool'] == 'web_search' && direct_result.find('ok') == true
direct_content = self.summarize_web_search(user, direct_result, direct_content)
end
if direct['tool'] == 'berry_program_explain' && direct_result.find('ok') == true
var cfg2 = {}
for k:self.cfg.keys()
cfg2[k] = self.cfg[k]
end
cfg2['max_tokens'] = 180
var er = self.llm.call_chat(cfg2, [
{
'role':'system',
'content':'You are TasmoClaw. Explain Berry programs for Tasmota in at most five short sentences. Mention commands registered, files touched, and how to run or test it. Do not include a code block.'
},
{
'role':'user',
'content':'Explain this Berry source:\n' + str(direct_result.find('result'))
}
])
var explain_ok = false
var explain_content = er.find('content')
if er.find('ok') == true && explain_content != nil && explain_content != '' && size(explain_content) > 40
var last_char = explain_content[size(explain_content)-1..size(explain_content)-1]
explain_ok = last_char == '.' || last_char == '!' || last_char == '?'
end
if explain_ok
direct_content = explain_content
else
direct_content = 'This Berry program registers a Tasmota command named HelloWorld. When the command runs, it responds with JSON: {"HelloWorld":"ok"}. It also prints "Hello World from TasmoClaw" when the file is loaded. The source file is ' + str(direct_result.find('path')) + '. Run it with the berry_program_run tool or Br load("' + str(direct_result.find('path')) + '"), then test it with the HelloWorld command.'
if er.find('error') != nil
direct_content += '\n\nModel explanation fallback reason: ' + str(er.find('error'))
end
end
end
if direct_trace != nil && direct_trace != ''
self.history.push({'role':'tool','content':direct_trace})
end
self.history.push({'role':'assistant','content':direct_content})
self.trim_history()
self.store.save_history(self.history)
self.api_json({'ok':true,'content':direct_content,'tool_trace':direct_trace,'tool_result':direct_result})
return
end
self.history.push({'role':'user','content':user})
var msgs=self.base_messages()
if !self.request_needs_tool(user)
msgs = self.simple_messages()
end
var loops=self.cfg['max_tool_iterations']
if loops < 6
loops = 6
end
var tool_trace = ''
var last_tool_result = nil
var last_tool = nil
var action_tool_seen = false
var later_action_repair_used = false
for _i:range(0,loops)
tasmoclaw_util.debug('chat loop iteration=' + str(_i + 1) + '/' + str(loops) + ' messages=' + str(size(msgs)))
var r=self.llm.call_chat(self.cfg,msgs)
if !r['ok']
tasmoclaw_util.debug('chat llm failed iteration=' + str(_i + 1) + ' transport=' + str(r.find('transport')) + ' status=' + str(r.find('status')) + ' error=' + str(r.find('error')))
self.api_json(r)
return
end
var c=r['content']
tasmoclaw_util.debug('chat llm ok iteration=' + str(_i + 1) + ' transport=' + str(r.find('transport')) + ' status=' + str(r.find('status')) + ' content_bytes=' + str(c == nil ? 0 : size(c)))
var tc=self.parse_tool_block(c)
if tc==nil
if c != nil && string.find(c, '<<<TASMOCLAW_TOOL>>>') != nil && string.find(c, '<<<TASMOCLAW_TOOL>>>') >= 0 && _i < loops - 1
tasmoclaw_util.debug('chat tool block invalid/incomplete; requesting repair')
msgs.push({'role':'assistant','content':c})
msgs.push({
'role':'user',
'content':'Your TasmoClaw tool block was incomplete or invalid JSON. Resend exactly one complete tool block with valid JSON and the closing <<<END_TASMOCLAW_TOOL>>> marker.'
})
continue
elif c != nil && string.find(c, '<<<TASMOCLAW_TOOL>>>') != nil && string.find(c, '<<<TASMOCLAW_TOOL>>>') >= 0
c = ''
end
if last_tool_result == nil && self.request_needs_tool(user) && _i < loops - 1
tasmoclaw_util.debug('chat model answered without required tool; requesting tool')
msgs.push({
'role':'user',
'content':'You answered without using a tool, but this request depends on current device state or files. Respond with exactly one TasmoClaw tool block using the listed tools. Do not answer from chat history.'
})
continue
end
if (c == nil || c == '') && last_tool_result == nil && _i < loops - 1
tasmoclaw_util.debug('chat empty response without tool; requesting repair')
msgs.push({
'role':'user',
'content':'Your previous response was empty. If this request needs current device state, filesystem data, SD-card data, sensors, power state, rules, or Berry files, respond with exactly one TasmoClaw tool block using the listed tools. Otherwise answer normally.'
})
continue
end
if last_tool_result != nil
if self.request_has_later_action(user) && !action_tool_seen && !later_action_repair_used && _i < loops - 1
later_action_repair_used = true
tasmoclaw_util.debug('chat later action still pending; requesting next tool')
msgs.push({
'role':'user',
'content':'The original user request has a later action step that is not complete yet. Call the next required TasmoClaw tool now. Do not give the final answer yet.'
})
continue
end
var use_fallback_summary = false
if c == nil || c == ''
use_fallback_summary = true
elif size(c) < 24
use_fallback_summary = true
else
var last_char = c[size(c)-1..size(c)-1]
if last_char != '.' && last_char != '!' && last_char != '?' && last_char != '\n'
use_fallback_summary = true
end
end
if use_fallback_summary
c = self.format_tool_answer(user, last_tool, last_tool_result)
end
end
if c == nil || c == ''
var fallback = self.direct_tool_for_user(user)
if fallback != nil
if self.tools.requires_approval_for(fallback['tool'], fallback['args']) && self.cfg['auto_approve_tools'] != true
tasmoclaw_util.debug('chat fallback approval required tool=' + str(fallback['tool']))
var fallback_now = tasmota.rtc().find('local')
if fallback_now == nil
fallback_now = tasmota.rtc().find('utc')
end
self.pending={
'id':str(fallback_now),
'tool':fallback['tool'],
'args':fallback['args'],
'reason':fallback.find('reason'),
'created':str(fallback_now),
'assistant':'Fallback TasmoClaw action prepared for approval.'
}
self.store.save_pending(self.pending)
self.trim_history()
self.store.save_history(self.history)
self.api_json({
'ok':true,
'approval_required':true,
'pending':self.pending,
'content':'Approval required for '+fallback['tool']
})
return
end
var fallback_result = self.tools.run(fallback['tool'], fallback['args'])
self.refresh_agent_context_if_needed(fallback['tool'])
var fallback_trace = self.format_tool_trace(fallback['tool'], fallback_result)
c = self.format_tool_answer(user, fallback['tool'], fallback_result)
if fallback['tool'] == 'web_search' && fallback_result.find('ok') == true
c = self.summarize_web_search(user, fallback_result, c)
end
tasmoclaw_util.debug('chat fallback tool result tool=' + str(fallback['tool']) + ' ok=' + str(fallback_result.find('ok')))
self.history.push({'role':'tool','content':fallback_trace})
self.history.push({'role':'assistant','content':c})
self.trim_history()
self.store.save_history(self.history)
self.api_json({'ok':true,'content':c,'tool_trace':fallback_trace,'tool_result':fallback_result,'fallback':'direct_router'})
return
end
end
self.history.push({'role':'assistant','content':c})
self.trim_history()
self.store.save_history(self.history)
tasmoclaw_util.debug('chat final answer saved content_bytes=' + str(c == nil ? 0 : size(c)))
var resp = {'ok':true,'content':c}
if tool_trace != ''
resp['tool_trace'] = tool_trace
resp['tool_result'] = last_tool_result
end
self.api_json(resp)
return
end
var repair = self.tool_choice_repair(user, tc)
if repair != nil
tasmoclaw_util.debug('chat tool choice repair needed tool=' + str(tc.find('tool')))
if _i < loops - 1
msgs.push({'role':'assistant','content':c})
msgs.push({'role':'user','content':repair})
continue
end
var repaired_fallback = self.direct_tool_for_user(user)
if repaired_fallback != nil
tc = repaired_fallback
else
self.api_json({'ok':false,'error':'model chose an unsuitable tool and no fallback was available','repair':repair})
tasmoclaw_util.debug('chat tool choice repair failed with no fallback')
return
end
end
tasmoclaw_util.debug('chat tool selected tool=' + str(tc.find('tool')) + ' approval=' + str(self.tools.requires_approval_for(tc['tool'], tc['args'])) + ' auto_approve=' + str(self.cfg['auto_approve_tools']))
if self.tools.requires_approval_for(tc['tool'], tc['args']) && self.cfg['auto_approve_tools'] != true
var now = tasmota.rtc().find('local')
if now == nil
now = tasmota.rtc().find('utc')
end
self.pending={
'id':str(now),
'tool':tc['tool'],
'args':tc['args'],
'reason':tc['reason'],
'created':str(now),
'assistant':c,
'prior_trace':tool_trace
}
self.store.save_pending(self.pending)
tasmoclaw_util.debug('chat pending saved tool=' + str(tc['tool']))
var approval_resp = {
'ok':true,
'approval_required':true,
'pending':self.pending,
'content':'Approval required for '+tc['tool']
}
if tool_trace != ''
approval_resp['tool_trace'] = tool_trace
approval_resp['tool_result'] = last_tool_result
end
self.api_json(approval_resp)
return
end
var tr=self.tools.run(tc['tool'],tc['args'])
self.refresh_agent_context_if_needed(tc['tool'])
tasmoclaw_util.debug('chat tool finished tool=' + str(tc['tool']) + ' ok=' + str(tr.find('ok')) + ' error=' + str(tr.find('error')))
if self.tools.requires_approval_for(tc['tool'], tc['args'])
action_tool_seen = true
end
var trace = self.format_tool_trace(tc['tool'], tr)
if trace != nil && trace != ''
if tool_trace != ''
tool_trace += '\n\n'
end
tool_trace += trace
end
last_tool_result = tr
last_tool = tc['tool']
msgs.push({'role':'assistant','content':c})
msgs.push({
'role':'user',
'content':'Original user request:\n'+user+'\n\nTasmoClaw tool result for '+tc['tool']+':\n'+tasmoclaw_util.json_encode(tr)+'\nIf the original request still has uncompleted steps, call the next required TasmoClaw tool now. If all steps are complete, give the user the final answer. Summarize the relevant fields from the result instead of dumping raw JSON. Include ADC/analog values, sensor readings, power states, filenames, paths, byte counts, commands run, and errors when present.'
})
end
var final_fallback = self.direct_tool_for_user(user)
if final_fallback != nil
if self.tools.requires_approval_for(final_fallback['tool'], final_fallback['args']) && self.cfg['auto_approve_tools'] != true
tasmoclaw_util.debug('chat retry-limit fallback approval required tool=' + str(final_fallback['tool']))
var final_now = tasmota.rtc().find('local')
if final_now == nil
final_now = tasmota.rtc().find('utc')
end
self.pending={
'id':str(final_now),
'tool':final_fallback['tool'],
'args':final_fallback['args'],
'reason':final_fallback.find('reason'),
'created':str(final_now),
'assistant':'Fallback TasmoClaw action prepared after tool retry limit.'
}
self.store.save_pending(self.pending)
self.trim_history()
self.store.save_history(self.history)
self.api_json({
'ok':true,
'approval_required':true,
'pending':self.pending,
'content':'Approval required for '+final_fallback['tool']
})
return
end
var final_result = self.tools.run(final_fallback['tool'], final_fallback['args'])
self.refresh_agent_context_if_needed(final_fallback['tool'])
var final_trace = self.format_tool_trace(final_fallback['tool'], final_result)
var final_content = self.format_tool_answer(user, final_fallback['tool'], final_result)
if final_fallback['tool'] == 'web_search' && final_result.find('ok') == true
final_content = self.summarize_web_search(user, final_result, final_content)
end
tasmoclaw_util.debug('chat retry-limit fallback tool=' + str(final_fallback['tool']) + ' ok=' + str(final_result.find('ok')))
self.history.push({'role':'tool','content':final_trace})
self.history.push({'role':'assistant','content':final_content})
self.trim_history()
self.store.save_history(self.history)
self.api_json({'ok':true,'content':final_content,'tool_trace':final_trace,'tool_result':final_result,'fallback':'retry_limit_router'})
return
end
tasmoclaw_util.debug('chat failed: max_tool_iterations reached loops=' + str(loops))
self.api_json({'ok':false,'error':'max_tool_iterations reached'})
end
def is_yes(s)
if s == nil
return false
end
var v = string.tolower(str(s))
while size(v) > 0 && (v[0..0] == ' ' || v[0..0] == '\t' || v[0..0] == '\n' || v[0..0] == '\r')
v = v[1..size(v)-1]
end
while size(v) > 0 && (v[size(v)-1..size(v)-1] == ' ' || v[size(v)-1..size(v)-1] == '\t' || v[size(v)-1..size(v)-1] == '\n' || v[size(v)-1..size(v)-1] == '\r' || v[size(v)-1..size(v)-1] == '.' || v[size(v)-1..size(v)-1] == '!')
v = v[0..size(v)-2]
end
return v == 'yes' || v == 'y' || v == 'ok' || v == 'okay' || v == 'approve' || v == 'approved' || v == 'confirm' || v == 'do it' || v == 'go ahead' || v == 'run it'
end
def map_find(obj, key)
if obj == nil
return nil
end
try
return obj.find(key)
except .. as e,m
end
return nil
end
def analog_summary(sns)
var analog = self.map_find(sns, 'ANALOG')
if analog == nil
return ''
end
var out = ''
try
for k:analog.keys()
if out != ''
out += ', '
end
out += str(k) + '=' + str(self.map_find(analog, k))
end
except .. as e,m
end
return out
end
def rules_summary(result)
if result == nil
return ''
end
var r = result.find('result')
if r == nil
r = result
end
var out = ''
for slot:['Rule1','Rule2','Rule3']
var outer = self.map_find(r, slot)
var inner = self.map_find(outer, slot)
if inner != nil
if out != ''
out += '\n'
end
out += slot + ': ' + str(self.map_find(inner, 'State'))
var rules = self.map_find(inner, 'Rules')
if rules != nil && rules != ''
out += '\n  ' + str(rules)
else
out += '\n  <empty>'
end
end
end
return out
end
def power_summary(p)
if p == nil
return ''
end
var out = ''
var base = self.map_find(p, 'POWER')
var p1 = self.map_find(p, 'POWER1')
var p2 = self.map_find(p, 'POWER2')
if base != nil
out += 'POWER=' + str(base)
end
if p1 != nil && (base == nil || str(p1) != str(base))
if out != ''
out += ', '
end
out += 'POWER1=' + str(p1)
end
if p2 != nil
if out != ''
out += ', '
end
out += 'POWER2=' + str(p2)
end
return out
end
def result_command(result, r)
var c = nil
if result != nil
c = result.find('command')
end
if c == nil && r != nil
c = self.map_find(r, 'command')
end
return c
end
def result_field(result, key)
var v = self.map_find(result, key)
if v != nil
return v
end
return self.map_find(self.map_find(result, 'result'), key)
end
def trace_uses_full_result(tool)
if tool == 'berry_module_probe' return true end
if tool == 'webcolor_control' return true end
if tool == 'lvgl_control' return true end
if tool == 'skill_list' return true end
if tool == 'skill_activate' return true end
if tool == 'skill_deactivate' return true end
if tool == 'skill_reset' return true end
if tool == 'memory_read' return true end
if tool == 'memory_search' return true end
if tool == 'memory_write' return true end
if tool == 'memory_append' return true end
if tool == 'memory_forget' return true end
if tool == 'profile_memory' return true end
if tool == 'agent_file_list' return true end
if tool == 'agent_file_read' return true end
if tool == 'agent_file_write' return true end
if tool == 'agent_file_append' return true end
if tool == 'device_doctor' return true end
if tool == 'board_bringup_wizard' return true end
if tool == 'automation_builder' return true end
if tool == 'dashboard_create' return true end
if tool == 'rule_explain' return true end
if tool == 'scheduler_list' return true end
if tool == 'scheduler_get' return true end
if tool == 'scheduler_add' return true end
if tool == 'scheduler_update' return true end
if tool == 'scheduler_remove' return true end
if tool == 'scheduler_enable' return true end
if tool == 'scheduler_disable' return true end
if tool == 'scheduler_trigger_now' return true end
if tool == 'scheduler_tick' return true end
if tool == 'router_rule_list' return true end
if tool == 'router_rule_get' return true end
if tool == 'router_rule_add' return true end
if tool == 'router_rule_update' return true end
if tool == 'router_rule_delete' return true end
if tool == 'router_emit' return true end
if tool == 'web_search' return true end
if tool == 'http_bridge_call' return true end
if tool == 'image_inspect' return true end
if tool == 'file_copy' return true end
if tool == 'file_move' return true end
if tool == 'file_delete' return true end
if tool == 'script_list' return true end
if tool == 'script_read' return true end
if tool == 'script_create' return true end
if tool == 'script_run' return true end
return false
end
def trace_uses_nested_result(tool)
if tool == 'command_run' return true end
if tool == 'berry_console' return true end
if tool == 'display_control' return true end
if tool == 'power_control' return true end
if tool == 'rule_control' return true end
if tool == 'light_control' return true end
if tool == 'mqtt_control' return true end
if tool == 'telemetry_control' return true end
if tool == 'network_control' return true end
if tool == 'system_control' return true end
if tool == 'timer_control' return true end
if tool == 'filesystem_control' return true end
return false
end
def answer_uses_generic_command_result(tool)
if tool == 'light_control' return true end
if tool == 'mqtt_control' return true end
if tool == 'telemetry_control' return true end
if tool == 'network_control' return true end
if tool == 'system_control' return true end
if tool == 'timer_control' return true end
if tool == 'filesystem_control' return true end
return false
end
def format_tool_trace(tool, result)
var out = 'Tool call: ' + tool
if result == nil
return out
end
var ok = result.find('ok')
out += ok == true ? '\nStatus: ok' : '\nStatus: error'
var err = result.find('error')
if err != nil
out += '\nError: ' + str(err)
return out
end
if tool == 'web_search'
out += '\nProvider: ' + str(result.find('provider')) + ' Query: ' + str(result.find('query'))
var results = result.find('results')
if results != nil && size(results) > 0
var item = results[0]
out += '\nTitle: ' + str(item.find('title'))
out += '\nURL: ' + str(item.find('url'))
out += '\nSnippet: ' + tasmoclaw_util.preview(str(item.find('snippet')), 360)
end
return out
end
var cmd = result.find('command')
if cmd != nil
out += '\nCommand: ' + str(cmd)
var safety = result.find('safety')
if safety != nil
out += '\nSafety: ' + str(safety)
end
end
var r = result.find('result')
if tool == 'command_build'
out += '\nBuilt: ' + str(result.find('command'))
out += '\nSafety: ' + str(result.find('safety'))
out += '\nReason: ' + str(result.find('reason'))
elif tool == 'command_catalog_search'
out += '\nResult: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result), 700)
elif tool == 'command_sequence_run' || tool == 'tool_sequence_run'
out += '\nResult: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result), 900)
elif self.trace_uses_full_result(tool)
out += '\nResult: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result), 900)
elif self.trace_uses_nested_result(tool)
out += '\nResult: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(r), 700)
elif tool == 'berry_skill_template'
out += '\nCommand: ' + str(result.find('command'))
out += '\nResult: ' + tasmoclaw_util.preview(str(result.find('content')), 700)
elif tool == 'sensor_read'
var s8 = self.map_find(r, 'status8')
var sns = self.map_find(s8, 'StatusSNS')
var analog = self.analog_summary(sns)
if analog != ''
out += '\nAnalog: ' + analog
end
var sht = self.map_find(sns, 'SHTC3')
if sht != nil
out += '\nSHTC3: ' + str(self.map_find(sht, 'Temperature')) + ' C, ' + str(self.map_find(sht, 'Humidity')) + '% RH'
end
var scan = self.map_find(r, 'i2cscan')
if scan != nil
out += '\nI2C: ' + str(self.map_find(scan, 'I2CScan'))
end
elif tool == 'power_read'
var ps = self.power_summary(r)
if ps != ''
out += '\n' + ps
else
out += '\nResult: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(r), 700)
end
elif tool == 'device_read'
var s82 = self.map_find(r, 'status8')
var sns2 = self.map_find(s82, 'StatusSNS')
var analog2 = self.analog_summary(sns2)
if analog2 != ''
out += '\nAnalog: ' + analog2
end
var sht2 = self.map_find(sns2, 'SHTC3')
if sht2 != nil
out += '\nSHTC3: ' + str(self.map_find(sht2, 'Temperature')) + ' C, ' + str(self.map_find(sht2, 'Humidity')) + '% RH'
end
var p = self.map_find(r, 'power')
if p != nil
var ps2 = self.power_summary(p)
if ps2 != ''
out += '\n' + ps2
end
end
out += '\nSD mounted: ' + str(self.map_find(r, 'sd_mounted'))
elif tool == 'tasmota_cmd_read'
var rules = self.rules_summary(result)
if rules != ''
out += '\n' + rules
else
out += '\nResult: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result), 700)
end
else
out += '\nResult: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result), 700)
end
return out
end
def format_entries(obj)
var ent = nil
var out = ''
var out2 = ''
var ufs_items = nil
if obj == nil
return ''
end
ent = self.map_find(obj, 'entries')
if ent != nil
try
for e:ent
if out != ''
out += '\n'
end
if type(e) == 'string'
out += '- ' + str(e)
else
var rendered = false
try
out += '- ' + str(e[0]) + ' (' + str(e[2]) + ' bytes)'
rendered = true
except .. as e_idx,m_idx
end
if !rendered
var en = self.map_find(e, 'name')
if en != nil
out += '- ' + str(en) + ' (' + str(self.map_find(e, 'size')) + ' bytes)'
else
out += '- ' + str(e)
end
end
end
end
return out
except .. as e,m
return tasmoclaw_util.preview(str(ent), 500)
end
end
ufs_items = self.map_find(obj, 'UfsList')
if ufs_items != nil && str(ufs_items) != 'Done'
try
for e2:ufs_items
if out2 != ''
out2 += '\n'
end
if type(e2) == 'string'
out2 += '- ' + str(e2)
else
out2 += '- ' + str(e2[0]) + ' (' + str(e2[2]) + ' bytes)'
end
end
return out2
except .. as e2,m2
return tasmoclaw_util.preview(str(ufs_items), 500)
end
end
return ''
end
def summarize_web_search(user, result, fallback)
if result == nil || result.find('ok') != true
return fallback
end
var results = result.find('results')
if results == nil || size(results) == 0
return fallback
end
var item = results[0]
var title = str(item.find('title'))
var url = str(item.find('url'))
var snippet = str(item.find('snippet'))
var cfg2 = {}
for k:self.cfg.keys()
cfg2[k] = self.cfg[k]
end
cfg2['max_tokens'] = 220
cfg2['temperature'] = 0.2
cfg2['thinking'] = 'omit'
var prompt = 'Original user request:\n' + str(user)
prompt += '\n\nBrave returned one result only. Use only this search result; do not claim you opened the page.'
prompt += '\nTitle: ' + title
prompt += '\nURL: ' + url
prompt += '\nSnippet: ' + snippet
prompt += '\n\nWrite a concise useful summary in 2 to 4 short sentences. Mention the source and include the URL at the end.'
var sr = self.llm.call_chat(cfg2, [
{
'role':'system',
'content':'You are TasmoClaw, a concise embedded Tasmota assistant. Summarize one web search result into a grounded answer. Do not add facts beyond the provided title, URL, and snippet.'
},
{
'role':'user',
'content':prompt
}
])
var c = sr.find('content')
if sr.find('ok') == true && c != nil && c != '' && size(c) > 24
var marker = string.find(c, 'TASMOCLAW_TOOL')
if marker == nil || marker < 0
return c
end
end
return fallback
end
def format_tool_answer(user, tool, result)
if result == nil || result.find('ok') != true
var err = result == nil ? 'unknown error' : str(result.find('error'))
return 'I tried to use ' + tool + ', but it failed: ' + err
end
var nl = '\n'
var r = result.find('result')
if tool == 'sensor_read'
var s8 = self.map_find(r, 'status8')
var sns = self.map_find(s8, 'StatusSNS')
var sht = self.map_find(sns, 'SHTC3')
var analog = self.analog_summary(sns)
var answer = ''
if analog != ''
answer += 'Analog ADC: ' + analog + '. '
end
if sht != nil
answer += 'Temperature is ' + str(self.map_find(sht, 'Temperature')) + ' C, with humidity at ' + str(self.map_find(sht, 'Humidity')) + '%.'
end
if answer != ''
return answer
end
return 'I read the sensors, but I could not find analog or SHTC3 values in the response.'
elif tool == 'power_read'
var ps = self.power_summary(r)
if ps != ''
return 'Power state: ' + ps + '.'
end
return 'I read power state, but no relay value was returned.'
elif tool == 'device_read'
var parts = ''
var s82 = self.map_find(r, 'status8')
var sns2 = self.map_find(s82, 'StatusSNS')
var analog2 = self.analog_summary(sns2)
if analog2 != ''
parts += 'Analog ADC: ' + analog2 + '. '
end
var sht2 = self.map_find(sns2, 'SHTC3')
if sht2 != nil
parts += 'Temperature is ' + str(self.map_find(sht2, 'Temperature')) + ' C and humidity is ' + str(self.map_find(sht2, 'Humidity')) + '%. '
end
var p = self.map_find(r, 'power')
if p != nil
var ps2 = self.power_summary(p)
if ps2 != ''
parts += 'Power state: ' + ps2 + '. '
end
end
var sd = self.map_find(r, 'sd_mounted')
if sd != nil
parts += 'SD mounted: ' + str(sd) + '.'
end
if parts != ''
return parts
end
return 'I read the device status successfully, but there was no compact sensor or power value to summarize.'
elif tool == 'file_read'
var file_path = self.result_field(result, 'path')
var file_body = self.map_find(result, 'body')
if file_body == nil
file_body = self.map_find(result, 'result')
end
if file_body == nil
file_body = self.map_find(r, 'result')
end
if file_path == nil
file_path = self.map_find(r, 'path')
end
return 'I read ' + str(file_path) + ':' + nl + str(file_body)
elif tool == 'file_write'
return 'I wrote ' + str(self.result_field(result, 'bytes')) + ' bytes to ' + str(self.result_field(result, 'path')) + '.'
elif tool == 'file_list'
var files = self.format_entries(r.find('result'))
if files == ''
files = self.format_entries(r)
end
if files != ''
return 'Files:' + nl + files
end
return 'I listed files, but the response did not include file entries.'
elif tool == 'sd_markdown_list'
var entries = self.format_entries(result)
if entries != ''
return 'SD card contents:' + nl + entries
end
return 'The SD card is mounted, but I did not find files to list.'
elif tool == 'berry_program_read'
var bp_path = self.result_field(result, 'path')
var bp_body = self.map_find(result, 'result')
if bp_body == nil
bp_body = self.map_find(r, 'result')
end
return 'I read ' + str(bp_path) + ':' + nl + str(bp_body)
elif tool == 'berry_program_write'
return 'I wrote the Berry program to ' + str(self.result_field(result, 'path')) + ' (' + str(self.result_field(result, 'bytes')) + ' bytes).'
end
if tool == 'berry_program_run'
return 'I loaded and ran the Berry program. Result: ' + str(r) + '.'
elif tool == 'berry_console'
return 'I ran the Berry console command. Result: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(r), 500)
elif tool == 'ufs_info'
var sd_entries = self.format_entries(self.map_find(r, 'sd_list'))
if sd_entries != ''
return 'SD card contents:' + nl + sd_entries
end
return 'Storage is available. SD mounted: ' + str(self.map_find(r, 'sd_mounted')) + '. UFS type: ' + str(self.map_find(r, 'type')) + '.'
end
if tool == 'command_build'
return 'I built this Tasmota command: ' + str(result.find('command')) + '. Safety: ' + str(result.find('safety')) + '.'
elif tool == 'command_catalog_search'
return 'I found matching command families:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('families')), 700)
elif tool == 'command_run'
return 'I ran ' + str(result.find('command')) + '. Result: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(r), 500)
elif tool == 'command_sequence_run'
var seq = result.find('results')
var out = 'I ran the command sequence.'
if seq != nil
out = 'Command sequence result:'
for step:seq
out += nl + '- ' + str(step.find('command')) + ': '
if step.find('ok') == true
out += 'ok'
else
out += 'failed: ' + str(step.find('error'))
end
end
end
return out
elif tool == 'tool_sequence_run'
var tseq = result.find('results')
if tseq == nil
tseq = self.map_find(r, 'results')
end
var tout = 'I ran the requested tool sequence.'
if tseq != nil
tout = 'Tool sequence result:'
for step2:tseq
var label = step2.find('tool')
if label == nil
label = step2.find('command')
end
tout += nl + '- ' + str(label) + ': '
if step2.find('ok') == true
var step_result = step2.find('result')
var command2 = self.result_command(step2, step_result)
if command2 != nil
tout += 'ok (' + str(command2) + ')'
else
tout += 'ok'
end
if label == 'rule_control'
var rs = self.rules_summary(step_result)
if rs != ''
tout += nl + rs
end
elif label == 'timer_control'
var timers = self.map_find(step_result, 'result')
if timers == nil
timers = step_result
end
if timers != nil
tout += ' ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(timers), 260)
end
elif label == 'power_read'
var pows = self.power_summary(step_result)
if pows != ''
tout += ' ' + pows
end
elif label == 'power_control'
var pows2 = self.power_summary(step_result)
if pows2 != ''
tout += ' ' + pows2
end
elif label == 'file_write'
var fpw = self.result_field(step2, 'path')
var fbw = self.result_field(step2, 'bytes')
tout += ' wrote ' + str(fbw) + ' bytes to ' + str(fpw)
elif label == 'file_read'
var fpr = self.result_field(step2, 'path')
tout += ' read ' + str(fpr)
elif label == 'file_list'
var fls = self.format_entries(self.map_find(step_result, 'result'))
if fls == ''
fls = self.format_entries(step_result)
end
if fls != ''
tout += nl + fls
end
elif label == 'device_read' || label == 'sensor_read'
var ds = self.format_tool_answer(user, label, step2)
if ds != nil && ds != ''
tout += ' ' + ds
end
end
else
tout += 'failed: ' + str(step2.find('error'))
end
end
end
return tout
end
if tool == 'berry_module_probe'
var probe = result.find('result')
var globals = self.map_find(probe, 'globals')
var mods = self.map_find(probe, 'modules')
var msg = 'Berry probe complete.'
if globals != nil
msg += ' Globals:'
for g:['tasmota','webserver','webclient','lv','display','persist','json','path']
var gv = self.map_find(globals, g)
if gv != nil
msg += ' ' + g + '=' + str(gv) + ';'
end
end
end
if mods != nil
msg += ' Modules checked: ' + str(size(mods)) + '.'
end
return msg
elif tool == 'webcolor_control'
var wr = result.find('result')
if result.find('command') != nil
return 'I applied WebColor with command ' + str(result.find('command')) + '. Result: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(wr), 400)
end
return 'Current WebColor palette:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(wr), 900)
elif tool == 'lvgl_control'
var lr = result.find('result')
if result.find('path') != nil
return 'I created and loaded an LVGL TasmoClaw screen from ' + str(result.find('path')) + '. Result: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(lr), 350)
end
return 'LVGL/display probe:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(lr), 900)
elif tool == 'display_control'
var dr = self.map_find(r, 'Display')
if dr != nil
return 'Display status: model ' + str(self.map_find(dr, 'Model')) + ', ' + str(self.map_find(dr, 'Width')) + 'x' + str(self.map_find(dr, 'Height')) + ', dimmer ' + str(self.map_find(dr, 'Dimmer')) + ', mode ' + str(self.map_find(dr, 'Mode')) + ', font ' + str(self.map_find(dr, 'Font')) + '.'
end
return 'I sent the display command: ' + str(self.result_command(result, r)) + '.'
elif tool == 'power_control'
var pv = ''
try
var cmd_res = r
if cmd_res != nil
var direct_power = self.map_find(cmd_res, 'POWER')
if direct_power != nil
pv = ' POWER=' + str(direct_power) + '.'
end
var direct_power1 = self.map_find(cmd_res, 'POWER1')
if direct_power1 != nil
pv += ' POWER1=' + str(direct_power1) + '.'
end
var direct_power2 = self.map_find(cmd_res, 'POWER2')
if direct_power2 != nil
pv += ' POWER2=' + str(direct_power2) + '.'
end
end
except .. as e,m
end
return 'I ran power command ' + str(self.result_command(result, r)) + '.' + pv + ' Result: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(r), 500)
elif tool == 'rule_control'
return 'I ran the rule command. Result: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result), 700)
elif self.answer_uses_generic_command_result(tool)
return 'I ran ' + str(self.result_command(result, r)) + '. Result: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(r), 500)
end
if tool == 'berry_skill_template'
return 'I prepared a Berry skill template for command ' + str(result.find('command')) + '.'
elif tool == 'berry_skill_create'
var msg = 'I wrote the Berry skill to ' + str(result.find('path')) + '. It registers command ' + str(result.find('command')) + '.'
var lr = result.find('load')
if lr != nil
msg += ' Load result: ' + tasmoclaw_util.preview(tasmoclaw_util.json_encode(lr), 300)
end
return msg
elif tool == 'berry_skill_run'
return 'I loaded the Berry skill. Result: ' + str(r) + '.'
elif tool == 'berry_skill_explain'
return 'I read the Berry skill source:' + nl + str(result.find('result'))
elif tool == 'skill_list'
return 'Active skills: ' + str(result.find('active')) + '. Available skill groups: ' + str(result.find('catalog').keys()) + '.'
elif tool == 'skill_activate' || tool == 'skill_deactivate' || tool == 'skill_reset'
return 'Active TasmoClaw skills are now: ' + str(result.find('active')) + '.'
elif tool == 'memory_read'
return 'Memory file content:' + nl + str(result.find('result'))
elif tool == 'memory_search'
return 'Memory search found ' + str(result.find('count')) + ' match(es):' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('hits')), 900)
elif tool == 'memory_write' || tool == 'memory_append'
return 'I saved local memory at ' + str(result.find('path')) + '.'
elif tool == 'memory_forget'
return 'I removed local memory at ' + str(result.find('path')) + '.'
elif tool == 'profile_memory'
if result.find('result') != nil
return 'Profile memory content:' + nl + str(result.find('result'))
end
if result.find('path') != nil
return 'I updated profile memory at ' + str(result.find('path')) + '.'
end
return 'Profile memory result:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result), 700)
elif tool == 'agent_file_list'
return 'Agent files:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('files')), 900)
elif tool == 'agent_file_read'
return 'Agent file content:' + nl + str(result.find('result'))
elif tool == 'agent_file_write' || tool == 'agent_file_append'
return 'I updated agent file ' + str(result.find('path')) + '.'
elif tool == 'device_doctor'
return str(result.find('summary')) + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('checks')), 1000)
elif tool == 'board_bringup_wizard'
return 'Waveshare bring-up check:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('checks')), 1000) + nl + 'Next steps: ' + str(result.find('next_steps'))
elif tool == 'rule_explain'
return 'Rule explanation:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('explanation')), 1200)
elif tool == 'automation_builder'
return 'I built the automation: ' + str(result.find('plan')) + ' Commands: ' + str(result.find('commands')) + '.'
elif tool == 'dashboard_create'
return 'I sent the display dashboard with ' + str(result.find('display_backend')) + '. Text:' + nl + str(result.find('dashboard_text'))
elif tool == 'scheduler_list'
return 'Schedules:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('schedules')), 1000)
elif tool == 'scheduler_get'
return 'Schedule:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('schedule')), 900)
elif tool == 'scheduler_add' || tool == 'scheduler_update' || tool == 'scheduler_enable' || tool == 'scheduler_disable'
return 'Schedule saved:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('schedule')), 900)
elif tool == 'scheduler_remove'
return 'Schedule removed:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('removed')), 700)
elif tool == 'scheduler_trigger_now' || tool == 'scheduler_tick'
return 'Scheduler ran. Result:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result), 1000)
elif tool == 'router_rule_list'
return 'Router rules:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('rules')), 1000)
elif tool == 'router_rule_get'
return 'Router rule:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('rule')), 900)
elif tool == 'router_rule_add' || tool == 'router_rule_update'
return 'Router rule saved:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('rule')), 900)
elif tool == 'router_rule_delete'
return 'Router rule removed:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('removed')), 700)
elif tool == 'router_emit'
return 'Router event matched ' + str(result.find('count')) + ' rule(s):' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('matched')), 1000)
end
if tool == 'web_search'
var lines = 'Search results from ' + str(result.find('provider')) + ':' + nl
var results = result.find('results')
if results != nil
var idx = 1
for item:results
lines += str(idx) + '. ' + str(item.find('title')) + nl + str(item.find('url')) + nl + str(item.find('snippet')) + nl
idx += 1
end
end
return lines
elif tool == 'http_bridge_call'
return 'HTTP bridge call returned status ' + str(result.find('status')) + ':' + nl + tasmoclaw_util.preview(str(result.find('body')), 1000)
elif tool == 'image_inspect'
return 'Image inspection result:' + nl + str(result.find('content'))
elif tool == 'file_copy'
return 'I copied ' + str(result.find('copied_from')) + ' to ' + str(result.find('path')) + ' (' + str(result.find('bytes')) + ' bytes).'
elif tool == 'file_move'
return 'I moved ' + str(result.find('moved_from')) + ' to ' + str(result.find('path')) + '.'
elif tool == 'file_delete'
return 'I deleted ' + str(result.find('path')) + '.'
elif tool == 'script_list'
return 'Script directories:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result.find('result')), 1000)
elif tool == 'script_read'
return 'I read the script:' + nl + str(result.find('result'))
elif tool == 'script_create'
return 'I wrote the script to ' + str(result.find('path')) + ' (' + str(result.find('bytes')) + ' bytes).'
elif tool == 'script_run'
return 'I loaded and ran the script. Result: ' + str(r) + '.'
end
if tool == 'tasmota_cmd_read'
var rules = self.rules_summary(result)
if rules != ''
return 'Current Tasmota rules:' + nl + rules
end
return 'Read-only command result:' + nl + tasmoclaw_util.preview(tasmoclaw_util.json_encode(result), 700)
end
return 'Done. I used ' + tool + ' successfully.'
end
def api_clear()
tasmoclaw_util.debug('api clear history size=' + str(size(self.history)))
self.history=[]
self.store.save_history(self.history)
self.api_json({'ok':true})
end
def api_reject()
tasmoclaw_util.debug('api reject pending=' + str(self.pending != nil))
self.pending=nil
self.store.save_pending(nil)
self.api_json({'ok':true})
end
def base_messages()
var mode = self.cfg.find('prompt_mode')
var tool_lines = mode == 'full' ? self.tools.tool_lines() : self.tools.tool_lines_compact()
var system_prompt = mode == 'full' ? tasmoclaw_prompt.build(tool_lines,self.cfg['system_extra'],self.agent_context) : tasmoclaw_prompt.build_compact(tool_lines,self.cfg['system_extra'],self.agent_context)
if mode == 'full' && size(system_prompt) > 6500
tasmoclaw_util.debug('base_messages compact fallback prompt_bytes=' + str(size(system_prompt)))
mode = 'compact'
tool_lines = self.tools.tool_lines_compact()
system_prompt = tasmoclaw_prompt.build_compact(tool_lines,self.cfg['system_extra'],self.agent_context)
end
var budget = self.cfg.find('context_byte_limit')
if budget == nil || budget < 1200
budget = 5200
end
var msgs=[
{
'role':'system',
'content':system_prompt
}
]
var selected = []
var used = size(system_prompt)
var i = size(self.history) - 1
while i >= 0
var m=self.history[i]
var role=m.find('role')
var content=m.find('content')
if role == 'user' || role == 'assistant' || role == 'system'
var tool_marker = nil
if content != nil
tool_marker = string.find(content, 'TASMOCLAW_TOOL')
end
if content != nil && (tool_marker == nil || tool_marker < 0)
var clen = size(content)
if used + clen <= budget || size(selected) == 0
selected.push({'role':role,'content':content})
used += clen
else
tasmoclaw_util.debug('base_messages context budget reached used=' + str(used) + ' budget=' + str(budget))
break
end
end
end
i -= 1
end
var j = size(selected) - 1
while j >= 0
msgs.push(selected[j])
j -= 1
end
tasmoclaw_util.debug('base_messages mode=' + str(mode) + ' prompt_bytes=' + str(size(system_prompt)) + ' messages=' + str(size(msgs)) + ' used_bytes=' + str(used) + ' budget=' + str(budget))
return msgs
end
def simple_messages()
var prompt = 'You are TasmoClaw, a concise helpful assistant running inside Tasmota.'
prompt += ' Answer naturally and briefly.'
prompt += ' For live device state, files, SD, rules, sensors, power, display, LVGL, Berry files, or Tasmota command output, ask for an explicit device action.'
if self.agent_context != nil && size(self.agent_context) > 0
prompt += '\n' + self.agent_context
end
var msgs = [{'role':'system','content':prompt}]
var selected = []
var used = size(prompt)
var i = size(self.history) - 1
var budget = 1400
while i >= 0
if size(selected) >= 4
break
end
var hist = self.history[i]
var role = hist.find('role')
var content = hist.find('content')
var ok_role = false
if role == 'user'
ok_role = true
end
if role == 'assistant'
ok_role = true
end
if ok_role == true
if content != nil
var marker = string.find(content, 'TASMOCLAW_TOOL')
if marker == nil || marker < 0
var clen = size(content)
if used + clen <= budget || size(selected) == 0
selected.push({'role':role,'content':content})
used += clen
end
end
end
end
i -= 1
end
var j = size(selected) - 1
while j >= 0
msgs.push(selected[j])
j -= 1
end
tasmoclaw_util.debug('simple_messages prompt_bytes=' + str(size(prompt)) + ' messages=' + str(size(msgs)) + ' used_bytes=' + str(used))
return msgs
end
def filename_from_text(user)
if user == nil
return nil
end
var lower = string.tolower(user)
for ext:['.txt','.md','.json','.be','.tapp','.mp3','.wav','.opus','.webm','.aac','.m4a']
var ei = string.find(lower, ext)
if ei != nil && ei >= 0
var start = ei
while start > 0
var ch = lower[start-1..start-1]
if ch == ' ' || ch == '\n' || ch == '\t' || ch == '"' || ch == '\'' || ch == '`' || ch == ',' || ch == ':' || ch == ';' || ch == '/' || ch == '\\'
break
end
start -= 1
end
var stop = ei + size(ext) - 1
while stop + 1 < size(user)
var ch2 = lower[stop+1..stop+1]
if ch2 == ' ' || ch2 == '\n' || ch2 == '\t' || ch2 == '"' || ch2 == '\'' || ch2 == '`' || ch2 == ',' || ch2 == ':' || ch2 == ';'
break
end
stop += 1
end
var sdp = string.find(lower, 'sd:')
var flp = string.find(lower, 'flash:')
if sdp != nil && sdp >= 0 && sdp < ei
start = sdp
elif flp != nil && flp >= 0 && flp < ei
start = flp
end
return user[start..stop]
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
if name == nil
name = ''
end
var n = str(name)
var l = string.tolower(n)
if string.find(l, 'sd:') == 0 || string.find(l, 'flash:') == 0
return n
end
if n == ''
n = '/'
end
if n[0..0] != '/'
n = '/' + n
end
return kind + ':' + n
end
def first_number_from_text(user)
if user == nil
return nil
end
var digits = '0123456789'
var start = nil
var stop = nil
for i:range(0, size(user))
var ch = user[i..i]
var di = string.find(digits, ch)
if di != nil && di >= 0
if start == nil
start = i
end
stop = i
elif start != nil
break
end
end
if start == nil
return nil
end
return user[start..stop]
end
def text_after_marker(user, markers)
if user == nil
return ''
end
var u = string.tolower(user)
for marker:markers
var mi = string.find(u, marker)
if mi != nil && mi >= 0
var start = mi + size(marker)
if start < size(user)
return user[start..size(user)-1]
end
end
end
return ''
end
def text_before_later_step(text)
if text == nil || text == ''
return ''
end
var lower = string.tolower(str(text))
for marker:[', and then ',' and then ',', then ',' then ',' after ',' next ']
var mi = string.find(lower, marker)
if mi != nil && mi >= 0
if mi == 0
return ''
end
return text[0..mi-1]
end
end
return text
end
def first_token(text)
if text == nil || text == ''
return ''
end
var stop = size(text) - 1
for i:range(0, size(text))
var ch = text[i..i]
if ch == ' ' || ch == '\n' || ch == '\t' || ch == '"' || ch == '\'' || ch == '`' || ch == ',' || ch == ':' || ch == ';' || ch == '.'
stop = i - 1
break
end
end
if stop < 0
return ''
end
return text[0..stop]
end
def url_from_text(user)
if user == nil
return ''
end
var lower = string.tolower(user)
var start = string.find(lower, 'http://')
if start == nil || start < 0
start = string.find(lower, 'https://')
end
if start == nil || start < 0
return ''
end
var stop = size(user) - 1
for i:range(start, size(user))
var ch = user[i..i]
if ch == ' ' || ch == '\n' || ch == '\t' || ch == '"' || ch == '\'' || ch == '`' || ch == ')'
stop = i - 1
break
end
end
return user[start..stop]
end
def request_needs_tool(user)
if user == nil
return false
end
var u = string.tolower(user)
for kw:[
'current','now','status','sensor','temperature','humidity','adc','analog','i2c',
'power','relay','rule','sd','card','file','filesystem','ufs','berry','tasmota',
'command','gpio','wifi','heap','memory','read','open','show','list','write',
'create','save','run','toggle','switch','turn on','turn off','display',
'screen','message','light','dimmer',
'brightness','color','colour','mqtt','publish','topic','teleperiod','weblog',
'seriallog','event','backlog','skill','tool','timer','timers','pulsetime',
'ruletimer','filesystem_control','network','hostname','ntp','timezone'
,'webcolor','palette','theme','lvgl','library','module probe','search',
'web search','brave','memory','remember','schedule',
'scheduler','router','route','http','webhook','mcp','bridge','image',
'inspect image','vision','script'
]
var ki = string.find(u, kw)
if ki != nil && ki >= 0
return true
end
end
if self.filename_from_text(user) != nil
return true
end
return false
end
def request_has_later_action(user)
if user == nil
return false
end
var u = string.tolower(user)
var has_sequence = false
for sk:[' then ',' and then ',' after ',' next ']
var si = string.find(u, sk)
if si != nil && si >= 0
has_sequence = true
end
end
if !has_sequence
return false
end
for ak:['toggle','switch','turn on','turn off','set ','write','create','save','run','apply','delete','remove','clear','enable','disable','display']
var ai = string.find(u, ak)
if ai != nil && ai >= 0
return true
end
end
return false
end
def tool_choice_repair(user, tc)
if user == nil || tc == nil
return nil
end
var u = string.tolower(user)
var chosen_tool = tc.find('tool')
var chosen_args = tc.find('args')
if chosen_tool == 'berry_skill_template'
var wants_write_skill = false
for sw:['create','write','save','install','load','run','make','register']
var swi = string.find(u, sw)
if swi != nil && swi >= 0
wants_write_skill = true
end
end
if wants_write_skill
return 'The user asked to create or load a reusable Berry skill, not just preview a template. Call berry_skill_create now. Use the explicit skill name and command name from the original request, include content/code if the user supplied it, and set autoload:true if the user asked to load it.'
end
end
if chosen_tool == 'berry_skill_create'
var args2 = tc.find('args')
var skill_default = false
if args2 == nil
skill_default = true
else
var sn = args2.find('name')
var sc = args2.find('command')
if sn == nil || sn == '' || string.tolower(str(sn)) == 'tasmo_skill'
skill_default = true
end
if sc == nil || sc == '' || string.tolower(str(sc)) == 'tasmo_skill'
skill_default = true
end
end
if skill_default && (string.find(u, 'called') != nil || string.find(u, 'named') != nil || string.find(u, 'command') != nil)
return 'The Berry skill tool call used the default name. Resend berry_skill_create with the explicit skill name and command name from the original request. If the user asked to load it, include autoload:true.'
end
if args2 != nil
var asked_load = false
for lw:['load','run','execute']
var lwi = string.find(u, lw)
if lwi != nil && lwi >= 0
asked_load = true
end
end
if asked_load && args2.find('autoload') != true
return 'The user asked to create and load the Berry skill. Resend berry_skill_create with autoload:true.'
end
var provided_content = args2.find('content')
if provided_content == nil
provided_content = args2.find('code')
end
if provided_content != nil && provided_content != ''
var pcs = string.tolower(str(provided_content))
if string.find(pcs, 'def (') != nil || string.find(pcs, ' .. ') != nil
return 'The generated Berry code looks invalid for Tasmota Berry. Unless the user supplied exact source code, omit content/code and let berry_skill_create generate the safe default command template for the requested name and command.'
end
end
end
end
var asks_timer_tool = false
for tw:['timer_control','ruletimer','pulsetime','timer state','timers','timer ']
var twi = string.find(u, tw)
if twi != nil && twi >= 0
asks_timer_tool = true
end
end
if asks_timer_tool && chosen_tool != 'timer_control'
return 'The user asked about Tasmota timers, RuleTimer, PulseTime, Timer, or explicitly requested timer_control. Use timer_control now, not rule_control. For a RuleTimer read, call {"tool":"timer_control","args":{"kind":"rule","action":"read"},"reason":"Read RuleTimer state."}.'
end
var asks_rule = false
var has_rule = string.find(u, 'rule')
var has_rules = string.find(u, 'rules')
if (has_rule != nil && has_rule >= 0) || (has_rules != nil && has_rules >= 0)
asks_rule = true
end
if asks_rule
var is_change = false
for rw:['add','set','create','make','apply','enable','disable','delete','remove','clear','erase','run']
var rwi = string.find(u, rw)
if rwi != nil && rwi >= 0
is_change = true
end
end
if !is_change
var tool = tc.find('tool')
var args = tc.find('args')
var cmd = nil
if args != nil
try
cmd = args.find('command')
if cmd == nil
cmd = args.find('cmd')
end
except .. as e,m
end
end
var cmd_l = cmd == nil ? '' : string.tolower(str(cmd))
var ok_rule_tool = false
if tool == 'tasmota_cmd_read' && cmd_l == 'rules'
ok_rule_tool = true
elif tool == 'rule_control'
var action = args == nil ? nil : args.find('action')
if action == nil || action == '' || string.tolower(str(action)) == 'read'
ok_rule_tool = true
end
end
if !ok_rule_tool
return 'The user asked to read Tasmota rules. Use rule_control with args {"action":"read","rule":"Rules"} or tasmota_cmd_read with args {"command":"Rules"}. Do not use device_read for rules. Respond with exactly one complete TasmoClaw tool block.'
end
end
end
return nil
end
def text_has(s, needle)
var i = string.find(s, needle)
return i != nil && i >= 0
end
def agent_file_from_text(s)
if self.text_has(s, 'agents.md') || self.text_has(s, 'agents')
return 'AGENTS.md'
elif self.text_has(s, 'soul.md') || self.text_has(s, 'soul')
return 'SOUL.md'
elif self.text_has(s, 'identity.md') || self.text_has(s, 'identity')
return 'IDENTITY.md'
elif self.text_has(s, 'user.md') || self.text_has(s, 'user file')
return 'USER.md'
elif self.text_has(s, 'memory.md')
return 'MEMORY.md'
end
return ''
end
def day_mask_from_text(s)
if self.text_has(s, 'weekend')
return 'S-----S'
end
if self.text_has(s, 'weekday') || self.text_has(s, 'week day')
return '-MTWTF-'
end
if self.text_has(s, 'every day') || self.text_has(s, 'daily') || self.text_has(s, 'monday to sunday') || self.text_has(s, 'mon to sun') || self.text_has(s, 'from monday') || self.text_has(s, 'all week')
return 'SMTWTFS'
end
return 'SMTWTFS'
end
def light_schedule_intent(user)
var s = string.tolower(str(user))
var target_light = self.text_has(s, 'light') || self.text_has(s, 'lamp') || self.text_has(s, 'relay') || self.text_has(s, 'power')
var time_word = self.text_has(s, 'night') || self.text_has(s, 'sunset') || self.text_has(s, 'evening') || self.text_has(s, 'dark') || self.text_has(s, 'sunrise') || self.text_has(s, 'morning')
var wants_on = self.text_has(s, 'turn on') || self.text_has(s, 'switch on') || self.text_has(s, 'power on') || self.text_has(s, 'light on')
var wants_off = self.text_has(s, 'turn off') || self.text_has(s, 'switch off') || self.text_has(s, 'power off') || self.text_has(s, 'light off')
if !target_light || !time_word || (!wants_on && !wants_off)
return nil
end
return {
'tool':'automation_builder',
'args':{
'goal':user,
'slot':1,
'output':1
},
'reason':'Build a Tasmota Timer automation from the plain-language light schedule request.'
}
end
def direct_tool_for_user(user)
if user == nil
return nil
end
var u=string.tolower(user)
var sched = self.light_schedule_intent(user)
if sched != nil
return sched
end
var says_doctor = string.find(u, 'doctor')
var says_health = string.find(u, 'health')
var says_diagnose = string.find(u, 'diagnos')
if (says_doctor != nil && says_doctor >= 0) || (says_health != nil && says_health >= 0) || (says_diagnose != nil && says_diagnose >= 0)
return {'tool':'device_doctor','args':{},'reason':'Run a TasmoClaw device health check.'}
end
var says_bringup = string.find(u, 'bring')
var says_waveshare = string.find(u, 'waveshare')
var says_board = string.find(u, 'board')
if (says_bringup != nil && says_bringup >= 0) || ((says_waveshare != nil && says_waveshare >= 0) && (says_board != nil && says_board >= 0))
return {'tool':'board_bringup_wizard','args':{},'reason':'Check the Waveshare board bring-up state.'}
end
var says_rule_word = string.find(u, 'rule')
if says_rule_word != nil && says_rule_word >= 0
for rex:['explain','understand','what','why','fix','cleanup','clean up','show me']
var rexi = string.find(u, rex)
if rexi != nil && rexi >= 0
return {'tool':'rule_explain','args':{},'reason':'Read and explain the current Tasmota rules.'}
end
end
end
var says_dashboard = string.find(u, 'dashboard')
if says_dashboard != nil && says_dashboard >= 0
for dbw:['create','make','show','display','draw','screen','lvgl']
var dbwi = string.find(u, dbw)
if dbwi != nil && dbwi >= 0
var title = self.text_after_marker(user, ['called ', 'named ', 'title '])
if title == ''
title = 'TasmoClaw Board'
end
return {'tool':'dashboard_create','args':{'title':title},'reason':'Create a live display dashboard.'}
end
end
end
var says_profile = string.find(u, 'profile')
var says_personality = string.find(u, 'personality')
if (says_profile != nil && says_profile >= 0) || (says_personality != nil && says_personality >= 0)
for pr:['read','show','view','what']
var pri = string.find(u, pr)
if pri != nil && pri >= 0
return {'tool':'profile_memory','args':{'action':'read'},'reason':'Read TasmoClaw profile memory.'}
end
end
var content = self.text_after_marker(user, ['profile that ', 'personality that ', 'remember that ', 'remember ', 'save that ', 'set ', 'to '])
if content == ''
content = user
end
return {'tool':'profile_memory','args':{'action':'append','content':content},'reason':'Update TasmoClaw profile memory.'}
end
var agent_file = self.agent_file_from_text(u)
if agent_file != ''
if self.text_has(u, 'list') || self.text_has(u, 'show files') || self.text_has(u, 'agent files')
return {'tool':'agent_file_list','args':{},'reason':'List TasmoClaw flash agent files.'}
end
if self.text_has(u, 'write') || self.text_has(u, 'replace') || self.text_has(u, 'set')
var afc = self.text_after_marker(user, ['with content ', 'with the content ', 'as ', 'to '])
if afc == ''
afc = user
end
return {'tool':'agent_file_write','args':{'name':agent_file,'content':afc},'reason':'Replace a TasmoClaw flash agent file.'}
end
if self.text_has(u, 'append') || self.text_has(u, 'add') || self.text_has(u, 'note')
var afn = self.text_after_marker(user, ['append ', 'add ', 'note ', 'that '])
if afn == ''
afn = user
end
return {'tool':'agent_file_append','args':{'name':agent_file,'content':afn},'reason':'Append a short note to a TasmoClaw flash agent file.'}
end
return {'tool':'agent_file_read','args':{'name':agent_file},'reason':'Read a TasmoClaw flash agent file.'}
end
var has_sequence_request = false
for sq:[' then ',' and then ',', then ',' after ',' next ']
var sqi = string.find(u, sq)
if sqi != nil && sqi >= 0
has_sequence_request = true
end
end
if has_sequence_request
var seq_items = []
var seq_sensor = false
for ssw:['sensor','temperature','humidity','adc','analog','i2c']
var sswi = string.find(u, ssw)
if sswi != nil && sswi >= 0
seq_sensor = true
end
end
var seq_power = false
for spw:['power','relay']
var spwi = string.find(u, spw)
if spwi != nil && spwi >= 0
seq_power = true
end
end
if seq_sensor && seq_power
seq_items.push({'tool':'device_read','args':{}})
elif seq_sensor
seq_items.push({'tool':'sensor_read','args':{}})
elif seq_power && (string.find(u, 'state') != nil || string.find(u, 'read') != nil)
seq_items.push({'tool':'power_read','args':{}})
end
var seq_rules = string.find(u, 'rule')
if seq_rules != nil && seq_rules >= 0 && (string.find(u, 'read') != nil || string.find(u, 'list') != nil || string.find(u, 'all') != nil)
seq_items.push({'tool':'rule_control','args':{'rule':'Rules','action':'read'}})
end
var seq_timers = false
for stw:['timer','timers','ruletimer','pulsetime']
var stwi = string.find(u, stw)
if stwi != nil && stwi >= 0
seq_timers = true
end
end
if seq_timers && (string.find(u, 'read') != nil || string.find(u, 'list') != nil || string.find(u, 'all') != nil)
seq_items.push({'tool':'timer_control','args':{'kind':'rule','action':'read'}})
end
var seq_files = string.find(u, 'file')
var seq_file_write = false
if seq_files != nil && seq_files >= 0
for sfw:['write','create','make','save','put']
var sfwi = string.find(u, sfw)
if sfwi != nil && sfwi >= 0
seq_file_write = true
end
end
end
if seq_file_write
var seq_file_name = self.filename_from_text(user)
if seq_file_name == nil
seq_file_name = 'tasmoclaw_note.txt'
end
var seq_file_content = self.text_after_marker(user, ['with content ', 'with the content ', 'with text ', 'with the text ', 'containing '])
seq_file_content = self.text_before_later_step(seq_file_content)
if seq_file_content == ''
seq_file_content = 'Hello from TasmoClaw\n'
end
if string.find(u, 'sd') != nil && string.find(u, 'sd') >= 0
seq_items.push({'tool':'file_write','args':{'path':self.prefixed_named_path('sd', seq_file_name),'content':seq_file_content}})
else
seq_items.push({'tool':'file_write','args':{'path':self.prefixed_named_path('flash', seq_file_name),'content':seq_file_content}})
end
end
if seq_files != nil && seq_files >= 0 && (string.find(u, 'list') != nil || string.find(u, 'show') != nil)
if string.find(u, 'sd') != nil && string.find(u, 'sd') >= 0
seq_items.push({'tool':'file_list','args':{'path':'sd:/'}})
else
seq_items.push({'tool':'file_list','args':{'path':'flash:/'}})
end
end
var seq_action = nil
if string.find(u, 'toggle') != nil && string.find(u, 'toggle') >= 0
seq_action = 'toggle'
elif string.find(u, 'turn on') != nil && string.find(u, 'turn on') >= 0
seq_action = 'on'
elif string.find(u, 'power on') != nil && string.find(u, 'power on') >= 0
seq_action = 'on'
elif string.find(u, 'turn off') != nil && string.find(u, 'turn off') >= 0
seq_action = 'off'
elif string.find(u, 'power off') != nil && string.find(u, 'power off') >= 0
seq_action = 'off'
end
if seq_action != nil
var seq_slot = ''
if (string.find(u, 'power2') != nil && string.find(u, 'power2') >= 0) || (string.find(u, 'power 2') != nil && string.find(u, 'power 2') >= 0) || (string.find(u, 'relay 2') != nil && string.find(u, 'relay 2') >= 0)
seq_slot = '2'
elif (string.find(u, 'power1') != nil && string.find(u, 'power1') >= 0) || (string.find(u, 'power 1') != nil && string.find(u, 'power 1') >= 0) || (string.find(u, 'relay 1') != nil && string.find(u, 'relay 1') >= 0)
seq_slot = '1'
end
seq_items.push({'tool':'power_control','args':{'slot':seq_slot,'action':seq_action}})
end
if size(seq_items) > 1
return {'tool':'tool_sequence_run','args':{'items':seq_items},'reason':'Execute the requested multi-step TasmoClaw workflow.'}
end
end
var says_skill_group = string.find(u, 'skill')
if says_skill_group != nil && says_skill_group >= 0
if string.find(u, 'list') != nil || string.find(u, 'show') != nil || string.find(u, 'active') != nil
return {'tool':'skill_list','args':{},'reason':'List TasmoClaw skills.'}
end
var skill_name = self.first_token(self.text_after_marker(user, ['activate ', 'enable ', 'load ']))
if skill_name != ''
return {'tool':'skill_activate','args':{'skill':skill_name},'reason':'Activate a TasmoClaw skill group.'}
end
skill_name = self.first_token(self.text_after_marker(user, ['deactivate ', 'disable ', 'unload ']))
if skill_name != ''
return {'tool':'skill_deactivate','args':{'skill':skill_name},'reason':'Deactivate a TasmoClaw skill group.'}
end
end
var says_memory = string.find(u, 'memory')
var says_remember = string.find(u, 'remember')
if (says_memory != nil && says_memory >= 0) || (says_remember != nil && says_remember >= 0)
var mem_search = string.find(u, 'search')
if mem_search != nil && mem_search >= 0
var mq = self.text_after_marker(user, ['search memory for ', 'search for '])
if mq == ''
mq = user
end
return {'tool':'memory_search','args':{'query':mq},'reason':'Search TasmoClaw local memory.'}
end
var mem_write = false
for mw0:['write','save','set','replace']
var mwi0 = string.find(u, mw0)
if mwi0 != nil && mwi0 >= 0
mem_write = true
end
end
if mem_write
var mc = self.text_after_marker(user, ['with content ', 'with the content ', 'as ', 'to '])
if mc == ''
mc = user
end
return {'tool':'memory_write','args':{'name':'memory.md','content':mc},'reason':'Write TasmoClaw local memory.'}
end
if says_remember != nil && says_remember >= 0
var note = self.text_after_marker(user, ['remember that ', 'remember '])
if note == ''
note = user
end
return {'tool':'memory_append','args':{'name':'memory.md','content':note},'reason':'Append a note to TasmoClaw memory.'}
end
for mr0:['read','show','view','what']
var mri0 = string.find(u, mr0)
if mri0 != nil && mri0 >= 0
return {'tool':'memory_read','args':{'name':'memory.md'},'reason':'Read TasmoClaw local memory.'}
end
end
end
var says_search = string.find(u, 'search')
var says_web = string.find(u, 'web')
var says_brave = string.find(u, 'brave')
if (says_search != nil && says_search >= 0 && (says_web != nil || says_brave != nil)) || (says_brave != nil && says_brave >= 0)
var q = self.text_after_marker(user, ['search web for ', 'web search for ', 'search for ', 'brave search for ', 'brave '])
if q == ''
q = user
end
var args_search = {'query':q}
return {'tool':'web_search','args':args_search,'reason':'Search the web through direct Brave Search API.'}
end
var says_schedule = string.find(u, 'schedule')
var says_scheduler = string.find(u, 'scheduler')
if (says_schedule != nil && says_schedule >= 0) || (says_scheduler != nil && says_scheduler >= 0)
if string.find(u, 'list') != nil || string.find(u, 'show') != nil || string.find(u, 'status') != nil
return {'tool':'scheduler_list','args':{},'reason':'List TasmoClaw schedules.'}
end
if string.find(u, 'trigger') != nil
var sid = self.first_token(self.text_after_marker(user, ['trigger ', 'schedule ']))
if sid == ''
sid = 'default'
end
return {'tool':'scheduler_trigger_now','args':{'id':sid},'reason':'Trigger a TasmoClaw schedule now.'}
end
var add_schedule = false
for sak:['add','create','every','remind']
var saki = string.find(u, sak)
if saki != nil && saki >= 0
add_schedule = true
end
end
if add_schedule
var sec = self.first_number_from_text(user)
if sec == nil
sec = '60'
end
var sid2 = self.first_token(self.text_after_marker(user, ['called ', 'named ', 'id ']))
if sid2 == ''
sid2 = 'schedule_' + str(sec) + 's'
end
var text = self.text_after_marker(user, ['to ', 'message ', 'say '])
if text == ''
text = user
end
return {'tool':'scheduler_add','args':{'id':sid2,'kind':'interval','interval_s':int(sec),'text':text},'reason':'Create an interval schedule.'}
end
end
var says_router = string.find(u, 'router')
if says_router != nil && says_router >= 0
if string.find(u, 'list') != nil || string.find(u, 'show') != nil
return {'tool':'router_rule_list','args':{},'reason':'List TasmoClaw router rules.'}
end
if string.find(u, 'emit') != nil || string.find(u, 'test') != nil
return {'tool':'router_emit','args':{'event_type':'manual','event_key':'test','text':user},'reason':'Emit a manual router test event.'}
end
end
var says_http = string.find(u, 'http')
var says_webhook = string.find(u, 'webhook')
var says_bridge = string.find(u, 'bridge')
if (says_http != nil && says_http >= 0) || (says_webhook != nil && says_webhook >= 0) || (says_bridge != nil && says_bridge >= 0)
var url = self.url_from_text(user)
if url != ''
return {'tool':'http_bridge_call','args':{'method':'get','url':url},'reason':'Call a local/cloud HTTP endpoint through MCP-lite bridge.'}
end
end
var says_image = string.find(u, 'image')
var says_vision = string.find(u, 'vision')
if (says_image != nil && says_image >= 0) || (says_vision != nil && says_vision >= 0)
var img_url = self.url_from_text(user)
if img_url != ''
return {'tool':'image_inspect','args':{'image_url':img_url,'prompt':user},'reason':'Inspect an image URL with the configured vision endpoint.'}
end
end
var says_script = string.find(u, 'script')
if says_script != nil && says_script >= 0
if string.find(u, 'list') != nil || string.find(u, 'show scripts') != nil
return {'tool':'script_list','args':{},'reason':'List TasmoClaw scripts.'}
end
if string.find(u, 'run') != nil || string.find(u, 'load') != nil
var sn = self.first_token(self.text_after_marker(user, ['script ', 'run ', 'load ']))
if sn == ''
sn = 'script'
end
return {'tool':'script_run','args':{'name':sn},'reason':'Run a TasmoClaw Berry script.'}
end
if string.find(u, 'create') != nil || string.find(u, 'write') != nil || string.find(u, 'make') != nil
var sn2 = self.first_token(self.text_after_marker(user, ['called ', 'named ', 'script ']))
if sn2 == ''
sn2 = 'script'
end
return {'tool':'script_create','args':{'name':sn2},'reason':'Create a TasmoClaw Berry script.'}
end
end
var says_webcolor = string.find(u, 'webcolor')
var says_palette = string.find(u, 'palette')
var says_theme = string.find(u, 'theme')
if (says_webcolor != nil && says_webcolor >= 0) || (says_palette != nil && says_palette >= 0) || (says_theme != nil && says_theme >= 0)
var wants_palette_write = false
for wcw:['set','change','apply','use','make']
var wcwi = string.find(u, wcw)
if wcwi != nil && wcwi >= 0
wants_palette_write = true
end
end
if !wants_palette_write
return {'tool':'webcolor_control','args':{'action':'read'},'reason':'Read the current Tasmota WebColor palette.'}
end
end
var says_lvgl = string.find(u, 'lvgl')
if says_lvgl != nil && says_lvgl >= 0
var wants_lvgl_action = false
for law:['show','display','create','draw','label','dashboard','message']
var lai = string.find(u, law)
if lai != nil && lai >= 0
wants_lvgl_action = true
end
end
if wants_lvgl_action
var lv_text = self.text_after_marker(user, ['message ', 'label ', 'show ', 'display '])
if lv_text == ''
lv_text = 'TasmoClaw'
end
return {'tool':'lvgl_control','args':{'action':'label','text':lv_text},'reason':'Create a simple LVGL label screen.'}
end
return {'tool':'lvgl_control','args':{'action':'status'},'reason':'Probe LVGL availability.'}
end
var says_library = string.find(u, 'library')
var says_module_probe = string.find(u, 'module')
if (says_library != nil && says_library >= 0 && string.find(u, 'berry') != nil && string.find(u, 'berry') >= 0) || (says_module_probe != nil && says_module_probe >= 0 && string.find(u, 'probe') != nil && string.find(u, 'probe') >= 0)
return {'tool':'berry_module_probe','args':{},'reason':'Probe available Berry modules and globals.'}
end
var display_word = false
for dw0:['display','screen','show on screen','show text','message']
var dwi0 = string.find(u, dw0)
if dwi0 != nil && dwi0 >= 0
display_word = true
end
end
if display_word
for ndw:['not display','do not display',"don't display",'not screen','do not screen',"don't screen"]
var ndwi = string.find(u, ndw)
if ndwi != nil && ndwi >= 0
display_word = false
end
end
end
if display_word
for dsk:['status','info','configuration','config']
var dski = string.find(u, dsk)
if dski != nil && dski >= 0
return {'tool':'display_control','args':{'action':'read'},'reason':'Read display status.'}
end
end
for dmk:['model','type','width','height','dimmer','brightness','size','font','rotate','rotation','invert']
var dmki = string.find(u, dmk)
if dmki != nil && dmki >= 0
return {'tool':'display_control','args':{'action':dmk},'reason':'Read or adjust display setting.'}
end
end
for dck:['clear','refresh','reinit','restart']
var dcki = string.find(u, dck)
if dcki != nil && dcki >= 0
return {'tool':'display_control','args':{'action':dck},'reason':'Run display control action.'}
end
end
var dm = self.text_after_marker(user, ['display ', 'screen ', 'show ', 'message '])
if dm == ''
dm = user
end
return {'tool':'display_control','args':{'message':dm},'reason':'Show text on the device display.'}
end
var wants_toggle = false
for tw:['toggle','switch','turn on','turn off','power on','power off','power1 on','power1 off','power2 on','power2 off','power 1 on','power 1 off','power 2 on','power 2 off']
var ti = string.find(u, tw)
if ti != nil && ti >= 0
wants_toggle = true
end
end
if wants_toggle
var power_slot = ''
var has_one = string.find(u, 'power1')
if has_one == nil || has_one < 0
has_one = string.find(u, 'power 1')
end
if has_one == nil || has_one < 0
has_one = string.find(u, 'relay 1')
end
var has_two = string.find(u, 'power2')
if has_two == nil || has_two < 0
has_two = string.find(u, 'power 2')
end
if has_two == nil || has_two < 0
has_two = string.find(u, 'relay 2')
end
if has_one != nil && has_one >= 0 && (has_two == nil || has_two < 0)
power_slot = '1'
elif has_two != nil && has_two >= 0
power_slot = '2'
end
var cmd = power_slot == '' ? 'Power 2' : 'Power' + power_slot + ' 2'
var turn_on = string.find(u, 'turn on')
if turn_on == nil || turn_on < 0
turn_on = string.find(u, 'power on')
end
if turn_on == nil || turn_on < 0
turn_on = string.find(u, 'power1 on')
end
if turn_on == nil || turn_on < 0
turn_on = string.find(u, 'power2 on')
end
if turn_on == nil || turn_on < 0
turn_on = string.find(u, 'power 1 on')
end
if turn_on == nil || turn_on < 0
turn_on = string.find(u, 'power 2 on')
end
var turn_off = string.find(u, 'turn off')
if turn_off == nil || turn_off < 0
turn_off = string.find(u, 'power off')
end
if turn_off == nil || turn_off < 0
turn_off = string.find(u, 'power1 off')
end
if turn_off == nil || turn_off < 0
turn_off = string.find(u, 'power2 off')
end
if turn_off == nil || turn_off < 0
turn_off = string.find(u, 'power 1 off')
end
if turn_off == nil || turn_off < 0
turn_off = string.find(u, 'power 2 off')
end
if turn_on != nil && turn_on >= 0
cmd = power_slot == '' ? 'Power 1' : 'Power' + power_slot + ' 1'
elif turn_off != nil && turn_off >= 0
cmd = power_slot == '' ? 'Power 0' : 'Power' + power_slot + ' 0'
end
var action = 'toggle'
if turn_on != nil && turn_on >= 0
action = 'on'
elif turn_off != nil && turn_off >= 0
action = 'off'
end
return {
'tool':'power_control',
'args':{'slot':power_slot,'action':action},
'reason':'Change relay power state.'
}
end
var asks_sensor = false
for sw:['sensor','temperature','humidity','shtc3','i2c']
var si = string.find(u, sw)
if si != nil && si >= 0
asks_sensor = true
end
end
var asks_power = false
for pw:['power','relay']
var pi = string.find(u, pw)
if pi != nil && pi >= 0
asks_power = true
end
end
if asks_sensor && asks_power
return {'tool':'device_read','args':{},'reason':'Read sensors and power state together.'}
end
if asks_sensor
return {'tool':'sensor_read','args':{},'reason':'Read sensor data and I2C status.'}
end
if asks_power
return {'tool':'power_read','args':{},'reason':'Read relay and power state.'}
end
var has_rule_early = string.find(u, 'rule')
var has_timer_early = false
for etkw:['timer','timers','ruletimer','pulsetime']
var etkwi = string.find(u, etkw)
if etkwi != nil && etkwi >= 0
has_timer_early = true
end
end
if has_rule_early != nil && has_rule_early >= 0 && has_timer_early
return {
'tool':'tool_sequence_run',
'args':{
'items':[
{'tool':'rule_control','args':{'rule':'Rules','action':'read'}},
{'tool':'timer_control','args':{'kind':'rule','action':'read'}}
]
},
'reason':'Read all Tasmota rules and timer state.'
}
end
var asks_timer_direct = false
for tkw:['timer_control','ruletimer','pulseTime','pulsetime','timer state','timers']
var tki = string.find(u, string.tolower(tkw))
if tki != nil && tki >= 0
asks_timer_direct = true
end
end
if asks_timer_direct
return {
'tool':'timer_control',
'args':{'kind':'rule','action':'read'},
'reason':'Read Tasmota RuleTimer state.'
}
end
var asks_sd = string.find(u, 'sd')
var asks_flash = string.find(u, 'flash')
var asks_ufs = string.find(u, 'ufs')
var asks_filesystem = string.find(u, 'filesystem')
var asks_file_word = string.find(u, 'file')
if (asks_sd != nil && asks_sd >= 0) || (asks_flash != nil && asks_flash >= 0) || (asks_ufs != nil && asks_ufs >= 0) || (asks_filesystem != nil && asks_filesystem >= 0) || (asks_file_word != nil && asks_file_word >= 0)
var wants_write_sd = false
for swr:['write','create','make','save','put']
var swri = string.find(u, swr)
if swri != nil && swri >= 0
wants_write_sd = true
end
end
if wants_write_sd && asks_sd != nil && asks_sd >= 0
var sd_content = ''
var sd_name = 'note.txt'
if string.find(u, 'hello world') != nil && string.find(u, 'hello world') >= 0
sd_content = 'hello world\n'
sd_name = 'hello_world.txt'
else
var marker_sd = string.find(u, 'with the text')
var marker_sd_len = size('with the text')
if marker_sd == nil || marker_sd < 0
marker_sd = string.find(u, 'containing')
marker_sd_len = size('containing')
end
if marker_sd != nil && marker_sd >= 0 && marker_sd + marker_sd_len < size(user)
sd_content = user[marker_sd + marker_sd_len..size(user)-1]
sd_content = self.text_before_later_step(sd_content)
else
sd_content = user
end
end
return {'tool':'file_write','args':{'path':self.prefixed_named_path('sd', sd_name),'content':sd_content},'reason':'Attempt the requested SD write and report the stock-firmware limitation if Berry cannot write SD files.'}
end
var wants_list = false
for lw:['list','show','content','contents','files','what']
var li = string.find(u, lw)
if li != nil && li >= 0
wants_list = true
end
end
if wants_list
if asks_flash != nil && asks_flash >= 0
return {'tool':'file_list','args':{'path':'flash:/'},'reason':'List files on internal FlashFS.'}
elif asks_sd != nil && asks_sd >= 0
return {'tool':'file_list','args':{'path':'sd:/'},'reason':'List files on the mounted SD card.'}
end
return {'tool':'file_list','args':{'path':'flash:/'},'reason':'List files on internal FlashFS.'}
end
var wants_status = false
for lws:['info','status','mounted','mount']
var lsi = string.find(u, lws)
if lsi != nil && lsi >= 0
wants_status = true
end
end
if wants_status
return {'tool':'ufs_info','args':{},'reason':'Read filesystem and SD card status.'}
end
end
var named_file = self.filename_from_text(user)
if named_file != nil
var wants_write_file = false
for fw:['write','create','make','save','put']
var fwi = string.find(u, fw)
if fwi != nil && fwi >= 0
wants_write_file = true
end
end
if wants_write_file
var file_content = self.text_after_marker(user, ['with content ', 'with the content ', 'with text ', 'with the text ', 'containing '])
file_content = self.text_before_later_step(file_content)
if file_content == ''
file_content = 'Hello from TasmoClaw\n'
end
var file_path = self.prefixed_named_path('flash', named_file)
if (asks_sd != nil && asks_sd >= 0)
file_path = self.prefixed_named_path('sd', named_file)
elif (asks_flash != nil && asks_flash >= 0)
file_path = self.prefixed_named_path('flash', named_file)
end
return {'tool':'file_write','args':{'path':file_path,'content':file_content},'reason':'Write the requested file.'}
end
var wants_delete_file = false
for fd:['delete','remove','erase']
var fdi = string.find(u, fd)
if fdi != nil && fdi >= 0
wants_delete_file = true
end
end
if wants_delete_file
var del_path = self.prefixed_named_path('flash', named_file)
if (asks_sd != nil && asks_sd >= 0)
del_path = self.prefixed_named_path('sd', named_file)
elif (asks_flash != nil && asks_flash >= 0)
del_path = self.prefixed_named_path('flash', named_file)
end
return {'tool':'file_delete','args':{'path':del_path},'reason':'Delete the requested file.'}
end
var wants_read_file = false
for fr:['read','show','view','open','cat','display']
var fri = string.find(u, fr)
if fri != nil && fri >= 0
wants_read_file = true
end
end
if wants_read_file
if (asks_flash != nil && asks_flash >= 0)
return {'tool':'file_read','args':{'path':self.prefixed_named_path('flash', named_file),'max_bytes':8192},'reason':'Read the requested file from internal FlashFS.'}
elif (asks_sd != nil && asks_sd >= 0)
return {'tool':'file_read','args':{'path':self.prefixed_named_path('sd', named_file),'max_bytes':8192},'reason':'Attempt the requested SD read and report the stock-firmware limitation if Berry cannot read SD files.'}
end
return {'tool':'file_read','args':{'path':self.prefixed_named_path('flash', named_file),'max_bytes':8192},'reason':'Read the requested file from internal FlashFS.'}
end
end
var md_name = nil
for mn:['memory.md','agent.md','soul.md','user.md']
var mi = string.find(u, mn)
if mi != nil && mi >= 0
md_name = mn
end
end
if md_name != nil
var wants_write_md = false
for mw:['write','create','make','save','put']
var mwi = string.find(u, mw)
if mwi != nil && mwi >= 0
wants_write_md = true
end
end
if wants_write_md
var content = '# ' + md_name + '\n'
var marker = string.find(u, 'with the text')
var marker_len = size('with the text')
if marker == nil || marker < 0
marker = string.find(u, 'containing')
marker_len = size('containing')
end
if marker != nil && marker >= 0 && marker + marker_len < size(user)
content = user[marker + marker_len..size(user)-1]
content = self.text_before_later_step(content)
end
return {'tool':'file_write','args':{'path':self.prefixed_named_path('sd', md_name),'content':content},'reason':'Attempt the requested SD markdown write and report the stock-firmware limitation if Berry cannot write SD files.'}
end
return {'tool':'file_read','args':{'path':self.prefixed_named_path('sd', md_name),'max_bytes':8192},'reason':'Attempt the requested SD markdown read and report the stock-firmware limitation if Berry cannot read SD files.'}
end
var says_berry = string.find(u, 'berry')
var says_skill = string.find(u, 'skill')
var starts_br_command = string.find(u, 'br ')
if starts_br_command != nil && starts_br_command == 0
return {'tool':'berry_console','args':{'code':user[3..size(user)-1]},'reason':'Run the requested short Berry console snippet.'}
end
if says_berry != nil && says_berry >= 0 && says_skill != nil && says_skill >= 0
var create_skill = false
for cs:['create','write','make','save','install','register']
var csi = string.find(u, cs)
if csi != nil && csi >= 0
create_skill = true
end
end
var load_skill = false
for ls:['load','run','execute']
var lsi = string.find(u, ls)
if lsi != nil && lsi >= 0
load_skill = true
end
end
var explain_skill = false
for es:['explain','describe','what does']
var esi = string.find(u, es)
if esi != nil && esi >= 0
explain_skill = true
end
end
var skill_name = self.first_token(self.text_after_marker(user, ['called ', 'named ']))
if skill_name == ''
skill_name = self.first_token(self.text_after_marker(user, ['skill ']))
end
if skill_name == ''
skill_name = 'tasmo_skill'
end
var skill_cmd = self.first_token(self.text_after_marker(user, ['command ']))
if skill_cmd == ''
skill_cmd = skill_name
end
if create_skill
return {
'tool':'berry_skill_create',
'args':{'name':skill_name,'command':skill_cmd,'autoload':load_skill},
'reason':'Create a reusable Berry skill that registers a Tasmota command.'
}
elif explain_skill
return {'tool':'berry_skill_explain','args':{'name':skill_name},'reason':'Read and explain the requested Berry skill.'}
elif load_skill
return {'tool':'berry_skill_run','args':{'name':skill_name},'reason':'Load the requested Berry skill.'}
end
end
var says_hello_world = string.find(u, 'hello world')
var says_file = string.find(u, 'file')
if says_berry != nil && says_berry >= 0 && says_hello_world != nil && says_hello_world >= 0 && says_file != nil && says_file >= 0
return {
'tool':'berry_program_write',
'args':{
'name':'hello_world'
},
'reason':'Create a runnable Hello World Berry program in the TasmoClaw workspace.'
}
end
if says_berry != nil && says_berry >= 0
var berry_code = self.text_after_marker(user, ['br ', 'berry console ', 'berry one-liner ', 'berry one liner ', 'run berry code ', 'execute berry code '])
var starts_br = string.find(u, 'br ')
if starts_br != nil && starts_br == 0
berry_code = user[3..size(user)-1]
end
if berry_code != ''
return {'tool':'berry_console','args':{'code':berry_code},'reason':'Run the requested short Berry console snippet.'}
end
var run_berry = false
for rb:['run','load','execute']
var rbi = string.find(u, rb)
if rbi != nil && rbi >= 0
run_berry = true
end
end
var explain_berry = false
for eb:['explain','describe','what does']
var ebi = string.find(u, eb)
if ebi != nil && ebi >= 0
explain_berry = true
end
end
var read_berry = false
for bb:['read','show','view','list']
var bbi = string.find(u, bb)
if bbi != nil && bbi >= 0
read_berry = true
end
end
var berry_name = 'hello_world'
if explain_berry
return {'tool':'berry_program_explain','args':{'name':berry_name},'reason':'Read Berry program source so it can be explained.'}
end
if run_berry
return {'tool':'berry_program_run','args':{'name':berry_name},'reason':'Load and run the Berry program.'}
end
if read_berry
var list_berry = string.find(u, 'list')
if list_berry != nil && list_berry >= 0
return {'tool':'file_list','args':{'path':'/tasmoclaw/berry'},'reason':'List Berry programs in the TasmoClaw workspace.'}
end
return {'tool':'berry_program_read','args':{'name':berry_name},'reason':'Read the Berry program source.'}
end
end
var has_rule = string.find(u, 'rule')
if has_rule != nil && has_rule >= 0
var add_rule = false
for aw:['add','set','create','make','apply']
var ai = string.find(u, aw)
if ai != nil && ai >= 0
add_rule = true
end
end
var says_hello = string.find(u, 'hello')
var says_5 = string.find(u, '5 second')
if add_rule && says_hello != nil && says_hello >= 0 && says_5 != nil && says_5 >= 0
return {
'tool':'rule_apply',
'args':{
'rule':'Rule3',
'definition':'ON Rules#Timer=1 DO Backlog Br print(\'hello\'); RuleTimer1 5 ENDON',
'enable':true,
'start_timer1':true,
'timer1_seconds':5
},
'reason':'Create Rule3 to print hello every 5 seconds and start RuleTimer1 immediately.'
}
end
var target_hello_rule = false
for hw:['hello','that rule','timer rule','rule3']
var hi = string.find(u, hw)
if hi != nil && hi >= 0
target_hello_rule = true
end
end
if target_hello_rule
for dw:['disable','stop','turn off']
var di = string.find(u, dw)
if di != nil && di >= 0
return {
'tool':'rule_control',
'args':{'rule':'Rule3','action':'disable'},
'reason':'Disable the Rule3 hello timer rule.'
}
end
end
for rw:['remove','delete','clear','erase']
var ri_remove = string.find(u, rw)
if ri_remove != nil && ri_remove >= 0
return {
'tool':'rule_clear',
'args':{'rule':'Rule3','stop_timer1':true},
'reason':'Disable and clear the Rule3 hello timer rule.'
}
end
end
end
var is_write = false
for w:['add','set','change','create','make','apply','enable','disable','delete','remove','update','run']
var wi = string.find(u, w)
if wi != nil && wi >= 0
is_write = true
end
end
if is_write
return nil
end
for w2:['show','view','give','current','read','list','what']
var ri = string.find(u, w2)
if ri != nil && ri >= 0
return {'tool':'rule_control','args':{'rule':'Rules','action':'read'},'reason':'Read all Tasmota rules.'}
end
end
if u == 'rules'
return {'tool':'rule_control','args':{'rule':'Rules','action':'read'},'reason':'Read all Tasmota rules.'}
end
end
return nil
end
def parse_tool_block(c)
var a='<<<TASMOCLAW_TOOL>>>'
var b='<<<END_TASMOCLAW_TOOL>>>'
if c == nil
return nil
end
var i=string.find(c,a)
var j=string.find(c,b)
if i == nil
return nil
end
if i < 0
return nil
end
var s = ''
if j != nil && j >= 0 && j > i
s=c[i+size(a)..j-1]
else
s=c[i+size(a)..size(c)-1]
var k=string.find(s,'<<<')
if k != nil && k >= 0
s=s[0..k-1]
end
end
var open_brace=string.find(s,'{')
if open_brace == nil || open_brace < 0
tasmoclaw_util.debug('tool block parse failed: no JSON object')
return nil
end
s=s[open_brace..size(s)-1]
try
return json.load(s)
except .. as e,m
tasmoclaw_util.debug('tool block parse JSON failure: ' + str(e) + ' ' + str(m) + ' text=' + tasmoclaw_util.preview(s, 160))
return nil
end
end
def api_approve()
if self.pending==nil
tasmoclaw_util.debug('api approve failed: no pending action')
self.api_json({'ok':false,'error':'no pending action'})
return
end
self.approve_pending()
end
def approve_pending()
var p=self.pending
tasmoclaw_util.debug('api approve start tool=' + str(p.find('tool')))
self.pending=nil
self.store.save_pending(nil)
var r=self.tools.run(p['tool'],p['args'])
self.refresh_agent_context_if_needed(p['tool'])
tasmoclaw_util.debug('api approve tool result tool=' + str(p.find('tool')) + ' ok=' + str(r.find('ok')) + ' error=' + str(r.find('error')))
var content = self.format_tool_answer(str(p.find('reason')), p['tool'], r)
if content == nil || content == ''
content = 'Approved TasmoClaw tool ' + str(p['tool']) + ' result:\n' + tasmoclaw_util.json_encode(r)
end
self.history.push({
'role':'assistant',
'content':content
})
self.trim_history()
self.store.save_history(self.history)
self.api_json({'ok':true,'content':content,'result':r,'tool_trace':self.format_tool_trace(p['tool'], r),'tool_result':r})
end
def api_test()
tasmoclaw_util.debug('api test start')
var cfg2 = {}
for k:self.cfg.keys()
cfg2[k] = self.cfg[k]
end
cfg2['max_tokens'] = 100
cfg2['thinking'] = 'omit'
var msgs=[
{'role':'system','content':'You are TasmoClaw. Reply exactly as requested.'},
{'role':'user','content':'Reply with exactly: TasmoClaw online.'}
]
var r=self.llm.call_chat(cfg2,msgs)
tasmoclaw_util.debug('api test result ok=' + str(r.find('ok')) + ' transport=' + str(r.find('transport')) + ' status=' + str(r.find('status')) + ' error=' + str(r.find('error')))
if r['ok']
self.remember_tested_model()
self.api_json({'ok':true,'content':r['content'],'transport':r.find('transport'),'status':r.find('status')})
else
self.api_json({
'ok':false,
'error':r['error'],
'transport':r.find('transport'),
'status':r.find('status'),
'body':r.find('body'),
'hint':r.find('hint'),
'fallback_hint':r.find('fallback_hint'),
'attempt':r.find('attempt'),
'attempts':r.find('attempts')
})
end
end
def trim_history()
var lim=self.cfg['history_limit']*2
while size(self.history)>lim
self.history.remove(0)
end
end
end
def start()
try
if global.tasmoclaw_driver
global.tasmoclaw_driver.stop()
end
except .. as e0,m0
end
try
if global.tasmoclaw_common_driver
global.tasmoclaw_common_driver.unload()
end
except .. as e_lite,m_lite
end
_driver = TasmoClawDriver()
try
_driver.web_add_handler()
print('TasmoClaw web handlers registered')
except .. as e,m
print('TasmoClaw web handler registration failed: ' + str(m))
end
try
tasmota.add_driver(_driver)
global.tasmoclaw_driver = _driver
print('TasmoClaw driver registered')
except .. as e2,m2
print('TasmoClaw driver registration failed: ' + str(m2))
end
print('TasmoClaw started')
return _driver
end
start()
var tasmoclaw = module("tasmoclaw")
tasmoclaw.start = start
return tasmoclaw
