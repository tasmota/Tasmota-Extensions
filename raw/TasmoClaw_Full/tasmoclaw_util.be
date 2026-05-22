import string
class TasmoClawUtil
def json_escape_string(s)
if s == nil return '' end
s = string.replace(s, '\\', '\\\\')
s = string.replace(s, '"', '\\"')
s = string.replace(s, '\n', '\\n')
s = string.replace(s, '\r', '\\r')
s = string.replace(s, '\t', '\\t')
return s
end
def json_quote(s)
return '"' + self.json_escape_string(s) + '"'
end
def json_encode(v)
import json
try
return json.dump(v)
except .. as e,m
end
if v == nil return 'null' end
var t = type(v)
if t == 'string' return self.json_quote(v) end
if t == 'bool' return v ? 'true' : 'false' end
if t == 'real' || t == 'int' return str(v) end
if t == 'list'
var out = '['
var first = true
for item:v
if !first out += ',' end
out += self.json_encode(item)
first = false
end
return out + ']'
end
if t == 'map'
var out2 = '{'
var first2 = true
for k:v.keys()
if !first2 out2 += ',' end
out2 += self.json_quote(str(k)) + ':' + self.json_encode(v[k])
first2 = false
end
return out2 + '}'
end
return self.json_quote(str(v))
end
def preview(s, limit)
if s == nil return '' end
if size(s) <= limit return s end
return s[0..limit-1]
end
def safe_url(url)
if url == nil return '' end
var s = str(url)
var qi = string.find(s, '?')
if qi != nil && qi >= 0
if qi == 0
return '?...'
end
return s[0..qi-1] + '?...'
end
return s
end
def debug(msg)
try
if tasmota.loglevel(4)
tasmota.log('TCL: ' + str(msg), 4)
end
except .. as e,m
end
end
end
var _util = TasmoClawUtil()
var tasmoclaw_util = module("tasmoclaw_util")
tasmoclaw_util.json_encode = def(v) return _util.json_encode(v) end
tasmoclaw_util.preview = def(s, limit) return _util.preview(s, limit) end
tasmoclaw_util.safe_url = def(url) return _util.safe_url(url) end
tasmoclaw_util.debug = def(msg) return _util.debug(msg) end
global.tasmoclaw_util_mod = tasmoclaw_util
return tasmoclaw_util
