import persist
import json
import path
import introspect
import string
var tasmoclaw_util = introspect.module('tasmoclaw_util')
class TasmoClawStore
var config_file, history_file, pending_file, workspace_fallback, last_error
def init()
self.config_file = '/tasmoclaw_config.json'
self.history_file = '/tasmoclaw_history.md'
self.pending_file = '/tasmoclaw_pending.json'
self.workspace_fallback = false
self.last_error = ''
end
def default_config()
return {
'enabled': true,
'provider':'deepseek',
'api_url':'https://api.deepseek.com/chat/completions',
'model':'deepseek-v4-flash',
'model_flash':'deepseek-v4-flash',
'model_pro':'deepseek-v4-pro',
'api_key':'',
'temperature':0.2,
'max_tokens':700,
'thinking':'omit',
'reasoning_effort':'high',
'max_tool_iterations':3,
'history_limit':6,
'prompt_mode':'compact',
'context_byte_limit':5200,
'auto_approve_tools':false,
'tested_models':[],
'workspace':'/tasmoclaw/',
'brave_api_key':'',
'vision_api_url':'',
'vision_model':'',
'vision_api_key':'',
'system_extra':''
}
end
def agent_file_names()
return ['AGENTS.md','SOUL.md','IDENTITY.md','USER.md','MEMORY.md']
end
def agent_file_path(name)
var n = name == nil || name == '' ? 'MEMORY.md' : str(name)
n = string.replace(n, '/', '')
n = string.replace(n, '\\', '')
n = string.replace(n, '..', '')
if string.find(n, '.') == nil
n += '.md'
end
var lower = string.tolower(n)
for f:self.agent_file_names()
if lower == string.tolower(f)
return self.workspace_fallback ? '/' + f : '/tasmoclaw/' + f
end
end
return nil
end
def default_agent_file(name)
if name == 'AGENTS.md'
return '# AGENTS.md\n\n- Use tools before guessing when the request depends on live Tasmota state, files, rules, sensors, power, web search, or command output.\n- Prefer structured TasmoClaw tools over raw commands.\n- Keep workflows short: inspect, act, verify, summarize.\n- Finish requested multi-step work when possible.\n- Store durable facts in MEMORY.md and user preferences in USER.md.\n'
elif name == 'SOUL.md'
return '# SOUL.md\n\nBe concise, practical, friendly, and lightly playful.\n'
elif name == 'IDENTITY.md'
return '# IDENTITY.md\n\nName: TasmoClaw\nEmoji: \xF0\x9F\xA6\x9E\nRole: Embedded Tasmota assistant\n'
elif name == 'USER.md'
return '# USER.md\n\nAdd stable user preferences, environment notes, and project context here.\n'
elif name == 'MEMORY.md'
return '# MEMORY.md\n\nKeep this file very small. Curate stable facts only; rewrite or remove stale notes instead of growing the file.\n\nAdd durable project facts and important decisions here.\n'
end
return ''
end
def read_file(file)
try
if path.exists(file) != true
return nil
end
var f = open(file, 'r')
var data = f.read()
f.close()
tasmoclaw_util.debug('store read file=' + str(file) + ' bytes=' + str(data == nil ? 0 : size(data)))
return data
except .. as e,m
self.last_error = 'read failed for ' + file + ': ' + str(m)
tasmoclaw_util.debug('store read failed file=' + str(file) + ' error=' + str(m))
return nil
end
end
def write_file(file, data)
try
var f = open(file, 'w')
f.write(data)
f.close()
self.last_error = ''
tasmoclaw_util.debug('store write file=' + str(file) + ' bytes=' + str(data == nil ? 0 : size(data)))
return {'ok':true}
except .. as e,m
self.last_error = 'write failed for ' + file + ': ' + str(m)
tasmoclaw_util.debug('store write failed file=' + str(file) + ' error=' + str(m))
return {'ok':false,'error':self.last_error}
end
end
def remove_file(file)
try
if path.exists(file) == true
path.remove(file)
end
self.last_error = ''
tasmoclaw_util.debug('store remove file=' + str(file))
return {'ok':true}
except .. as e,m
self.last_error = 'remove failed for ' + file + ': ' + str(m)
tasmoclaw_util.debug('store remove failed file=' + str(file) + ' error=' + str(m))
return {'ok':false,'error':self.last_error}
end
end
def persist_key(file)
if file == self.config_file
return 'tasmoclaw_config_json'
elif file == self.history_file
return 'tasmoclaw_history_json'
elif file == self.pending_file
return 'tasmoclaw_pending_json'
end
return 'tasmoclaw_data_json'
end
def persist_read(file)
try
return persist.find(self.persist_key(file), nil)
except .. as e,m
tasmoclaw_util.debug('store persist_read failed key=' + str(self.persist_key(file)) + ' error=' + str(m))
return nil
end
end
def persist_write(file, data)
try
persist.setmember(self.persist_key(file), data)
persist.save(true)
return {'ok':true}
except .. as e,m
tasmoclaw_util.debug('store persist_write failed key=' + str(self.persist_key(file)) + ' error=' + str(m))
return {'ok':false,'error':str(m)}
end
end
def persist_delete(file)
try
persist.remove(self.persist_key(file))
persist.save(true)
return {'ok':true}
except .. as e,m
tasmoclaw_util.debug('store persist_delete failed key=' + str(self.persist_key(file)) + ' error=' + str(m))
return {'ok':false,'error':str(m)}
end
end
def is_list_like(value)
if value == nil
return false
end
try
var push_fn = value.push
return push_fn != nil
except .. as e,m
end
return false
end
def safe_find(value, key)
if value == nil
return nil
end
try
return value.find(key)
except .. as e,m
end
return nil
end
def history_list(value)
if self.is_list_like(value)
return value
end
for k:['history','messages','items','result']
var nested = self.safe_find(value, k)
if self.is_list_like(nested)
return nested
end
end
var nested_result = self.safe_find(value, 'result')
for k2:['history','messages','items']
var nested2 = self.safe_find(nested_result, k2)
if self.is_list_like(nested2)
return nested2
end
end
return nil
end
def strip_blank_lines(s)
if s == nil
return ''
end
var out = str(s)
while size(out) > 0 && out[0..0] == '\n'
out = out[1..]
end
while size(out) > 0 && out[size(out)-1..size(out)-1] == '\n'
if size(out) == 1
out = ''
else
out = out[0..size(out)-2]
end
end
return out
end
def history_to_markdown(h)
var out = '# TasmoClaw History\n\n'
out += '<!-- Human-readable chat transcript. TasmoClaw parses sections that start with "## role". -->\n\n'
if h == nil
return out
end
for m:h
var role = self.safe_find(m, 'role')
var content = self.safe_find(m, 'content')
if role == nil role = 'assistant' end
if content == nil content = '' end
out += '## ' + str(role) + '\n\n'
out += str(content) + '\n\n---\n\n'
end
return out
end
def markdown_to_history(raw)
var history = []
if raw == nil || size(raw) == 0
return history
end
var parts = string.split(str(raw), '\n## ')
for i:0..size(parts)-1
var part = parts[i]
if i == 0
if string.find(part, '## ') == 0
part = part[3..]
else
continue
end
end
var first_nl = string.find(part, '\n')
if first_nl == nil || first_nl < 0
continue
end
var role = part[0..first_nl-1]
var body = part[first_nl+1..]
var sep = string.find(body, '\n\n---')
if sep != nil && sep >= 0
body = body[0..sep-1]
end
body = self.strip_blank_lines(body)
if role == 'user' || role == 'assistant' || role == 'tool' || role == 'approval'
history.push({'role':role,'content':body})
end
end
return history
end
def ensure_agent_files()
for name:self.agent_file_names()
var p = self.agent_file_path(name)
if p != nil
try
if path.exists(p) != true
self.write_file(p, self.default_agent_file(name))
end
except .. as e,m
tasmoclaw_util.debug('store ensure_agent_files failed file=' + str(name) + ' error=' + str(m))
end
end
end
end
def agent_context(max_bytes)
if max_bytes == nil || max_bytes < 1
max_bytes = 1800
end
var out = ''
for name:self.agent_file_names()
if size(out) >= max_bytes
break
end
var p = self.agent_file_path(name)
if p != nil
var raw = self.read_file(p)
if raw != nil && size(raw) > 0
var header = '\n\n### ' + name + '\n'
var remaining = max_bytes - size(out) - size(header)
if remaining > 80
out += header + tasmoclaw_util.preview(raw, remaining)
end
end
end
end
if out == ''
return ''
end
return 'TasmoClaw flash agent files:' + out
end
def load_config()
tasmoclaw_util.debug('store load_config start')
var cfg = self.default_config()
var loaded = false
try
var raw = self.read_file(self.config_file)
if raw != nil
var obj = json.load(raw)
for k:obj.keys()
cfg[k]=obj[k]
end
loaded = true
self.persist_delete(self.config_file)
end
except .. as e,m
self.last_error = 'config parse failed: ' + str(m)
tasmoclaw_util.debug('store config parse failed; trying persist error=' + str(m))
end
if !loaded
try
var raw2 = self.persist_read(self.config_file)
if raw2 != nil
var obj2 = json.load(raw2)
for k:obj2.keys()
cfg[k]=obj2[k]
end
tasmoclaw_util.debug('store config loaded from persist')
end
except .. as e2,m2
tasmoclaw_util.debug('store config persist fallback failed: ' + str(m2))
end
end
tasmoclaw_util.debug('store load_config done model=' + str(cfg.find('model')))
return cfg
end
def save_config(cfg)
var r = self.write_file(self.config_file, tasmoclaw_util.json_encode(cfg))
if !r['ok']
var p = self.persist_write(self.config_file, tasmoclaw_util.json_encode(cfg))
if p['ok']
tasmoclaw_util.debug('store save_config used persist fallback warning=' + str(r['error']))
return {'ok':true,'fallback':'persist','warning':r['error']}
end
end
return r
end
def load_history()
var tried_file = false
try
var raw = self.read_file(self.history_file)
if raw != nil
tried_file = true
var h = self.markdown_to_history(raw)
if h != nil
tasmoclaw_util.debug('store load_history markdown count=' + str(size(h)))
self.persist_delete(self.history_file)
return h
end
end
except .. as e,m
self.last_error = 'history parse failed: ' + str(m)
tasmoclaw_util.debug('store history parse failed; trying persist error=' + str(m))
end
if !tried_file
try
var raw_legacy = self.read_file('/tasmoclaw_history.json')
if raw_legacy != nil
tried_file = true
var h_legacy = json.load(raw_legacy)
var hl_legacy = self.history_list(h_legacy)
if hl_legacy != nil
tasmoclaw_util.debug('store history migrated from json count=' + str(size(hl_legacy)))
self.write_file(self.history_file, self.history_to_markdown(hl_legacy))
self.remove_file('/tasmoclaw_history.json')
self.persist_delete(self.history_file)
return hl_legacy
end
end
except .. as e_legacy,m_legacy
tasmoclaw_util.debug('store legacy history migration failed: ' + str(m_legacy))
end
end
if !tried_file
try
var raw2 = self.persist_read(self.history_file)
if raw2 != nil
var h2 = json.load(raw2)
var hl2 = self.history_list(h2)
if hl2 != nil
tasmoclaw_util.debug('store history loaded from persist count=' + str(size(hl2)))
self.write_file(self.history_file, self.history_to_markdown(hl2))
self.persist_delete(self.history_file)
return hl2
end
tasmoclaw_util.debug('store history persist ignored non-list value')
end
except .. as e2,m2
tasmoclaw_util.debug('store history persist fallback failed: ' + str(m2))
end
end
tasmoclaw_util.debug('store load_history default empty')
return []
end
def save_history(h)
var r = self.write_file(self.history_file, self.history_to_markdown(h))
self.remove_file('/tasmoclaw_history.json')
self.persist_delete(self.history_file)
return r
end
def load_pending()
var tried_file = false
try
var raw = self.read_file(self.pending_file)
if raw != nil && size(raw) > 0
tried_file = true
var p = json.load(raw)
if p == nil || self.safe_find(p, 'tool') == nil
tasmoclaw_util.debug('store load_pending ignored non-map pending')
self.persist_delete(self.pending_file)
return nil
end
tasmoclaw_util.debug('store load_pending found tool=' + str(self.safe_find(p, 'tool')))
self.persist_delete(self.pending_file)
return p
end
except .. as e,m
self.last_error = 'pending parse failed: ' + str(m)
tasmoclaw_util.debug('store pending parse failed; trying persist error=' + str(m))
end
if !tried_file
try
var raw2 = self.persist_read(self.pending_file)
if raw2 != nil
var p2 = json.load(raw2)
if p2 != nil && self.safe_find(p2, 'tool') != nil
tasmoclaw_util.debug('store pending loaded from persist')
self.write_file(self.pending_file, tasmoclaw_util.json_encode(p2))
self.persist_delete(self.pending_file)
return p2
end
tasmoclaw_util.debug('store pending persist ignored non-map value')
end
except .. as e2,m2
tasmoclaw_util.debug('store pending persist fallback failed: ' + str(m2))
end
end
return nil
end
def save_pending(p)
if p == nil
var r = self.remove_file(self.pending_file)
self.persist_delete(self.pending_file)
return r
else
var r2 = self.write_file(self.pending_file, tasmoclaw_util.json_encode(p))
self.persist_delete(self.pending_file)
return r2
end
end
def ensure_workspace()
tasmoclaw_util.debug('store ensure_workspace start')
self.workspace_fallback = false
try
if path.exists('/tasmoclaw') != true
path.mkdir('/tasmoclaw')
end
if path.exists('/tasmoclaw/berry') != true
path.mkdir('/tasmoclaw/berry')
end
if path.exists('/tasmoclaw/logs') != true
path.mkdir('/tasmoclaw/logs')
end
if path.exists('/tasmoclaw/scripts') != true
path.mkdir('/tasmoclaw/scripts')
end
if path.exists('/tasmoclaw/memory') != true
path.mkdir('/tasmoclaw/memory')
end
self.ensure_agent_files()
tasmoclaw_util.debug('store ensure_workspace done fallback=false')
return {'ok':true,'fallback':false}
except .. as e,m
self.workspace_fallback = true
self.last_error = 'workspace mkdir failed: ' + str(m)
tasmoclaw_util.debug('store ensure_workspace failed: ' + str(m))
self.ensure_agent_files()
try
tasmota.log('TasmoClaw: ' + self.last_error, 2)
except .. as e2,m2
end
return {'ok':false,'fallback':true,'error':self.last_error}
end
end
end
var tasmoclaw_store = module("tasmoclaw_store")
tasmoclaw_store.create = def()
return TasmoClawStore()
end
global.tasmoclaw_store_mod = tasmoclaw_store
return tasmoclaw_store
