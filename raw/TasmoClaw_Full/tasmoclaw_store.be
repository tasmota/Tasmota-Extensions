import persist
import json
import path
import tasmoclaw_util
class TasmoClawStore
var config_file, history_file, pending_file, workspace_fallback, last_error
def init()
self.config_file = '/tasmoclaw_config.json'
self.history_file = '/tasmoclaw_history.json'
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
'https_transport':'webclient',
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
'system_extra':''
}
end
def read_file(file)
try
if path.exists(file) != true
tasmoclaw_util.debug('store read missing file=' + str(file))
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
tasmoclaw_util.debug('store load_config done transport=' + str(cfg.find('https_transport')) + ' model=' + str(cfg.find('model')))
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
else
self.persist_write(self.config_file, tasmoclaw_util.json_encode(cfg))
end
return r
end
def load_history()
var tried_file = false
try
var raw = self.read_file(self.history_file)
if raw != nil
tried_file = true
var h = json.load(raw)
var hl = self.history_list(h)
if hl != nil
tasmoclaw_util.debug('store load_history count=' + str(size(hl)))
return hl
end
tasmoclaw_util.debug('store load_history ignored non-list history file')
end
except .. as e,m
self.last_error = 'history parse failed: ' + str(m)
tasmoclaw_util.debug('store history parse failed; trying persist error=' + str(m))
end
if !tried_file
try
var raw2 = self.persist_read(self.history_file)
if raw2 != nil
var h2 = json.load(raw2)
var hl2 = self.history_list(h2)
if hl2 != nil
tasmoclaw_util.debug('store history loaded from persist count=' + str(size(hl2)))
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
var r = self.write_file(self.history_file, tasmoclaw_util.json_encode(h))
if !r['ok']
var p = self.persist_write(self.history_file, tasmoclaw_util.json_encode(h))
if p['ok']
tasmoclaw_util.debug('store save_history used persist fallback warning=' + str(r['error']))
return {'ok':true,'fallback':'persist','warning':r['error']}
end
else
self.persist_write(self.history_file, tasmoclaw_util.json_encode(h))
end
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
return nil
end
tasmoclaw_util.debug('store load_pending found tool=' + str(self.safe_find(p, 'tool')))
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
if !r['ok']
var pdel = self.persist_delete(self.pending_file)
if pdel['ok']
tasmoclaw_util.debug('store save_pending remove used persist fallback warning=' + str(r['error']))
return {'ok':true,'fallback':'persist','warning':r['error']}
end
else
self.persist_delete(self.pending_file)
end
return r
else
var r2 = self.write_file(self.pending_file, tasmoclaw_util.json_encode(p))
if !r2['ok']
var pw = self.persist_write(self.pending_file, tasmoclaw_util.json_encode(p))
if pw['ok']
tasmoclaw_util.debug('store save_pending used persist fallback warning=' + str(r2['error']))
return {'ok':true,'fallback':'persist','warning':r2['error']}
end
else
self.persist_write(self.pending_file, tasmoclaw_util.json_encode(p))
end
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
tasmoclaw_util.debug('store ensure_workspace done fallback=false')
return {'ok':true,'fallback':false}
except .. as e,m
self.workspace_fallback = true
self.last_error = 'workspace mkdir failed: ' + str(m)
tasmoclaw_util.debug('store ensure_workspace failed: ' + str(m))
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
return tasmoclaw_store
