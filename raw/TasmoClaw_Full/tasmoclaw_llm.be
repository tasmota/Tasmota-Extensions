import json
import string
import tasmoclaw_util
class TasmoClawLLM
def call_chat(cfg, messages)
var provider = self.provider(cfg)
var local_provider = self.is_local_provider(provider)
if !local_provider && (cfg.find('api_key') == nil || cfg['api_key'] == '')
tasmoclaw_util.debug('llm config error: missing api_key')
return {'ok':false,'error':'Missing DeepSeek API key'}
end
if cfg.find('api_url') == nil || cfg['api_url'] == ''
tasmoclaw_util.debug('llm config error: missing api_url')
return {'ok':false,'error':'Missing api_url'}
end
if cfg.find('model') == nil || cfg['model'] == ''
tasmoclaw_util.debug('llm config error: missing model')
return {'ok':false,'error':'Missing model'}
end
var max_tokens = cfg.find('max_tokens')
if max_tokens == nil
max_tokens = 900
end
var temperature = cfg.find('temperature')
if temperature == nil
temperature = 0.2
end
var payload = {
'model': cfg['model'],
'messages': messages,
'temperature': temperature,
'max_tokens': max_tokens,
'stream': false
}
var thinking = cfg.find('thinking')
if thinking == nil
thinking = 'omit'
end
if local_provider
thinking = 'omit'
end
if thinking == 'enabled'
payload['thinking'] = {'type':'enabled'}
payload['reasoning_effort'] = cfg.find('reasoning_effort') == nil ? 'high' : cfg['reasoning_effort']
elif thinking == 'disabled'
payload['thinking'] = {'type':'disabled'}
end
var payload_s = tasmoclaw_util.json_encode(payload)
var headers = {
'Content-Type':'application/json',
'Accept':'application/json',
'Connection':'close',
'User-Agent':'TasmoClaw/0.1'
}
if !local_provider && cfg.find('api_key') != nil && cfg['api_key'] != ''
headers['Authorization'] = 'Bearer '+cfg['api_key']
end
var headers_s = tasmoclaw_util.json_encode(headers)
var transport = cfg.find('https_transport')
if transport == nil || transport == ''
transport = 'webclient'
end
if transport != 'webclient' && transport != 'native' && transport != 'auto'
transport = 'webclient'
end
tasmoclaw_util.debug('llm call start provider=' + provider + ' transport=' + transport + ' model=' + str(cfg['model']) + ' messages=' + str(size(messages)) + ' payload_bytes=' + str(size(payload_s)) + ' max_tokens=' + str(max_tokens) + ' thinking=' + thinking)
if transport == 'native'
return self.call_chat_native(cfg, payload_s, headers_s, nil)
elif transport == 'auto'
var wr = self.call_chat_webclient(cfg, payload_s, nil)
if wr.find('ok') == true || !self.should_native_fallback(wr)
tasmoclaw_util.debug('llm auto webclient result ok=' + str(wr.find('ok')) + ' status=' + str(wr.find('status')) + ' error=' + str(wr.find('error')))
return wr
end
tasmoclaw_util.debug('llm auto falling back to native after webclient error=' + str(wr.find('error')) + ' status=' + str(wr.find('status')))
var nr = self.call_chat_native(cfg, payload_s, headers_s, wr.find('error'))
if nr.find('ok') == true
nr['webclient_error'] = wr.find('error')
end
tasmoclaw_util.debug('llm auto native result ok=' + str(nr.find('ok')) + ' status=' + str(nr.find('status')) + ' error=' + str(nr.find('error')))
return nr
end
return self.call_chat_webclient(cfg, payload_s, nil)
end
def provider(cfg)
var p = cfg.find('provider')
if p == nil || p == ''
return 'deepseek'
end
return str(p)
end
def is_local_provider(provider)
return provider == 'local_openai' || provider == 'local' || provider == 'openai_compatible'
end
def should_native_fallback(r)
if r == nil
return true
end
var status = r.find('status')
if status == nil
return true
end
return status < 0
end
def extract_error_message(body)
if body == nil || size(body) == 0
return ''
end
try
var o = json.load(body)
var e = o.find('error')
if e != nil
if type(e) == 'string'
return str(e)
end
if type(e) == 'map'
var msg = e.find('message')
if msg != nil
return str(msg)
end
msg = e.find('error')
if msg != nil
return str(msg)
end
msg = e.find('type')
if msg != nil
return str(msg)
end
end
return str(e)
end
var m = o.find('message')
if m != nil
return str(m)
end
m = o.find('detail')
if m != nil
return str(m)
end
m = o.find('error_description')
if m != nil
return str(m)
end
except .. as e_json,m_json
end
return tasmoclaw_util.preview(body, 220)
end
def http_error(transport, status, body, extra_error)
var msg = self.extract_error_message(body)
var error = 'HTTP '+str(status)
if msg != nil && msg != ''
error += ': '+msg
elif status == 401
error += ': unauthorized'
elif status == 403
error += ': forbidden'
elif body == nil || size(body) == 0
error += ': empty error body'
end
var r = {
'ok':false,
'transport':transport,
'status':status,
'error':error,
'body':tasmoclaw_util.preview(body, 500)
}
if status == 401 || status == 403
r['hint'] = 'Check the API key or local server auth settings in /tasmoclaw/config.'
end
if extra_error != nil
r['webclient_error'] = extra_error
end
tasmoclaw_util.debug('llm http error transport=' + transport + ' status=' + str(status) + ' error=' + error + ' body=' + tasmoclaw_util.preview(body, 160))
return r
end
def empty_response_error(transport, status, extra_error)
var r = {
'ok':false,
'transport':transport,
'status':status,
'error':'HTTP '+str(status)+' returned an empty response body'
}
if extra_error != nil
r['webclient_error'] = extra_error
end
tasmoclaw_util.debug('llm empty response transport=' + transport + ' status=' + str(status))
return r
end
def webclient_error_name(code)
if code == -1 return 'connection refused or timeout' end
if code == -2 return 'send header failed' end
if code == -3 return 'send payload failed' end
if code == -4 return 'not connected' end
if code == -5 return 'connection lost' end
if code == -6 return 'no stream' end
if code == -7 return 'no HTTP server' end
if code == -8 return 'too little RAM' end
if code == -9 return 'unsupported transfer encoding' end
if code == -10 return 'stream write error' end
if code == -11 return 'read timeout' end
if code < -1000 return 'TLS error '+str(-code - 1000) end
return 'webclient transport error'
end
def retryable_webclient_error(code)
return code < 0 && code != -8 && code > -1000
end
def call_chat_native(cfg, payload_s, headers_s, webclient_error)
if !global.contains('idf_https_post')
var msg = 'ESP-IDF HTTPS bridge idf_https_post is not available. Rebuild firmware with USE_TASMOCLAW_HTTPS to use native transport.'
tasmoclaw_util.debug('native https unavailable')
var r_missing = {'ok':false,'transport':'esp_http_client','error':msg}
if webclient_error != nil
r_missing['webclient_error'] = webclient_error
end
return r_missing
end
try
tasmoclaw_util.debug('native https POST start url=' + tasmoclaw_util.safe_url(cfg['api_url']) + ' payload_bytes=' + str(size(payload_s)))
var raw = global.idf_https_post(cfg['api_url'], headers_s, payload_s)
tasmoclaw_util.debug('native https raw response bytes=' + str(raw == nil ? 0 : size(raw)))
var nr = json.load(raw)
if !nr['ok']
tasmoclaw_util.debug('native https transport failure status=' + str(nr.find('status')) + ' stage=' + str(nr.find('stage')) + ' esp_err=' + str(nr.find('esp_err')) + ' error=' + str(nr.find('error')))
var er = {
'ok':false,
'transport':'esp_http_client',
'status':nr.find('status'),
'stage':nr.find('stage'),
'esp_err':nr.find('esp_err'),
'error':nr.find('error') == nil ? 'ESP-IDF HTTPS request failed' : nr['error'],
'body':tasmoclaw_util.preview(nr.find('body'), 500)
}
if webclient_error != nil
er['webclient_error'] = webclient_error
end
return er
end
var status = nr.find('status')
var body = nr.find('body')
if status == nil
status = 0
end
tasmoclaw_util.debug('native https POST done status=' + str(status) + ' body_bytes=' + str(body == nil ? 0 : size(body)) + ' truncated=' + str(nr.find('truncated')))
if status < 200 || status >= 300
return self.http_error('esp_http_client', status, body, webclient_error)
end
if body == nil || size(body) == 0
return self.empty_response_error('esp_http_client', status, webclient_error)
end
if nr.find('truncated') == true
tasmoclaw_util.debug('native https oversized/truncated response bytes=' + str(nr.find('bytes')))
return {'ok':false,'transport':'esp_http_client','status':status,'error':'oversized response','bytes':nr.find('bytes'),'webclient_error':webclient_error}
end
var pr = self.parse_response(body)
pr['transport'] = 'esp_http_client'
pr['status'] = status
return pr
except .. as e_native,m_native
var msg = 'ESP-IDF HTTPS bridge idf_https_post failed: '+str(m_native)
tasmoclaw_util.debug('native https exception: ' + str(e_native) + ' ' + str(m_native))
var r = {'ok':false,'transport':'esp_http_client','error':msg}
if webclient_error != nil
r['webclient_error'] = webclient_error
end
return r
end
end
def call_chat_webclient(cfg, payload_s, native_missing)
var attempts = cfg.find('webclient_retries')
if attempts == nil
attempts = 2
else
attempts = int(attempts) + 1
end
if attempts < 1
attempts = 1
end
if attempts > 3
attempts = 3
end
var last = nil
var attempt = 0
while attempt < attempts
attempt += 1
tasmoclaw_util.debug('webclient attempt ' + str(attempt) + '/' + str(attempts))
var r = self.call_chat_webclient_once(cfg, payload_s, native_missing, attempt, attempts)
if r.find('ok') == true
tasmoclaw_util.debug('webclient attempt ok status=' + str(r.find('status')))
return r
end
var status = r.find('status')
if status == nil || !self.retryable_webclient_error(status) || attempt >= attempts
tasmoclaw_util.debug('webclient attempt final failure status=' + str(status) + ' error=' + str(r.find('error')))
return r
end
tasmoclaw_util.debug('webclient retrying after status=' + str(status) + ' error=' + str(r.find('error')))
last = r
end
return last
end
def call_chat_webclient_once(cfg, payload_s, native_missing, attempt, attempts)
var cl = nil
try
cl = webclient()
except .. as e,m
tasmoclaw_util.debug('webclient unavailable: ' + str(e) + ' ' + str(m))
return {
'ok':false,
'transport':'webclient',
'error':'Tasmota Berry webclient is unavailable: '+str(m),
'native_error':native_missing
}
end
try
tasmoclaw_util.debug('webclient begin url=' + tasmoclaw_util.safe_url(cfg['api_url']) + ' payload_bytes=' + str(size(payload_s)))
cl.begin(cfg['api_url'])
try
cl.set_timeouts(45000, 15000)
except .. as e_to,m_to
tasmoclaw_util.debug('webclient set_timeouts failed: ' + str(e_to) + ' ' + str(m_to))
end
try
cl.use_http10(true)
except .. as e_http10,m_http10
tasmoclaw_util.debug('webclient use_http10 failed: ' + str(e_http10) + ' ' + str(m_http10))
end
cl.add_header('Content-Type','application/json')
cl.add_header('Accept','application/json')
cl.add_header('Connection','close')
if !self.is_local_provider(self.provider(cfg)) && cfg.find('api_key') != nil && cfg['api_key'] != ''
cl.add_header('Authorization','Bearer '+cfg['api_key'])
end
cl.add_header('User-Agent','TasmoClaw/0.1')
var code = cl.POST(payload_s)
tasmoclaw_util.debug('webclient POST completed code=' + str(code) + ' attempt=' + str(attempt) + '/' + str(attempts))
if code < 0
try
cl.close()
except .. as e_close,m_close
tasmoclaw_util.debug('webclient close after negative code failed: ' + str(e_close) + ' ' + str(m_close))
end
tasmoclaw_util.debug('webclient pre-http failure code=' + str(code) + ' name=' + self.webclient_error_name(code) + ' retryable=' + str(self.retryable_webclient_error(code)))
return {
'ok': false,
'transport':'webclient',
'status':code,
'error': 'HTTP '+str(code)+' from Tasmota webclient before receiving a server response ('+self.webclient_error_name(code)+')',
'hint': 'The TCP/TLS connection may have opened but failed before a valid HTTP response. TasmoClaw retries transient webclient errors once.',
'fallback_hint':'Set HTTPS transport to auto or native if this firmware includes USE_TASMOCLAW_HTTPS.',
'api_url': tasmoclaw_util.safe_url(cfg['api_url']),
'payload_bytes': size(payload_s),
'model': cfg['model'],
'attempt':attempt,
'attempts':attempts,
'native_error':native_missing
}
end
var body = cl.get_string()
cl.close()
tasmoclaw_util.debug('webclient response code=' + str(code) + ' body_bytes=' + str(body == nil ? 0 : size(body)))
if code < 200 || code >= 300
return self.http_error('webclient', code, body, native_missing)
end
if body == nil || size(body) == 0
return self.empty_response_error('webclient', code, native_missing)
end
if size(body) > 24000
tasmoclaw_util.debug('webclient oversized response bytes=' + str(size(body)))
return {'ok':false,'transport':'webclient','status':code,'error':'oversized response','bytes':size(body)}
end
var pr = self.parse_response(body)
pr['transport'] = 'webclient'
pr['status'] = code
return pr
except .. as e,m
try
cl.close()
except .. as e2,m2
tasmoclaw_util.debug('webclient close after exception failed: ' + str(e2) + ' ' + str(m2))
end
tasmoclaw_util.debug('webclient exception: ' + str(e) + ' ' + str(m))
return {'ok':false,'transport':'webclient','error':'request failed: '+str(m),'native_error':native_missing}
end
end
def probe_webclient(url)
var cl = nil
var out = {'transport':'webclient','url':tasmoclaw_util.safe_url(url)}
tasmoclaw_util.debug('webclient probe start url=' + tasmoclaw_util.safe_url(url))
try
cl = webclient()
except .. as e,m
tasmoclaw_util.debug('webclient probe unavailable: ' + str(e) + ' ' + str(m))
out['ok'] = false
out['error'] = 'webclient unavailable: '+str(m)
return out
end
try
cl.begin(url)
try
cl.set_timeouts(30000, 15000)
except .. as e_to,m_to
tasmoclaw_util.debug('webclient probe set_timeouts failed: ' + str(e_to) + ' ' + str(m_to))
end
try
cl.use_http10(true)
except .. as e_http10,m_http10
tasmoclaw_util.debug('webclient probe use_http10 failed: ' + str(e_http10) + ' ' + str(m_http10))
end
cl.add_header('Accept','application/json,text/plain,*/*')
cl.add_header('Connection','close')
cl.add_header('User-Agent','TasmoClaw/0.1')
var code = cl.GET()
var body = cl.get_string()
cl.close()
out['status'] = code
out['ok'] = code >= 0
if code < 0
out['error'] = 'webclient returned '+str(code)+' before receiving an HTTP status'
end
out['body'] = tasmoclaw_util.preview(body, 220)
tasmoclaw_util.debug('webclient probe done url=' + tasmoclaw_util.safe_url(url) + ' status=' + str(code) + ' body_bytes=' + str(body == nil ? 0 : size(body)))
return out
except .. as e2,m2
try
cl.close()
except .. as e_close,m_close
tasmoclaw_util.debug('webclient probe close failed: ' + str(e_close) + ' ' + str(m_close))
end
tasmoclaw_util.debug('webclient probe exception: ' + str(e2) + ' ' + str(m2))
out['ok'] = false
out['error'] = 'webclient request failed: '+str(m2)
return out
end
end
def probe_native_get(url)
tasmoclaw_util.debug('native probe start url=' + tasmoclaw_util.safe_url(url))
var headers = tasmoclaw_util.json_encode({
'Accept':'application/json,text/plain,*/*',
'Connection':'close',
'User-Agent':'TasmoClaw/0.1'
})
var raw = nil
var get_error = nil
if global.contains('idf_https_get')
try
raw = global.idf_https_get(url, headers)
except .. as e_get,m_get
tasmoclaw_util.debug('native probe idf_https_get failed: ' + str(e_get) + ' ' + str(m_get))
get_error = str(m_get)
end
else
get_error = 'idf_https_get unavailable'
end
if raw == nil
if global.contains('idf_https_post')
try
raw = global.idf_https_post(url, headers, '')
except .. as e_post,m_post
tasmoclaw_util.debug('native probe idf_https_post failed: ' + str(e_post) + ' ' + str(m_post))
return {
'ok':false,
'transport':'esp_http_client',
'native_available':false,
'url':tasmoclaw_util.safe_url(url),
'error':'idf_https_post unavailable or failed: '+str(m_post),
'get_error':get_error
}
end
else
return {
'ok':false,
'transport':'esp_http_client',
'native_available':false,
'url':tasmoclaw_util.safe_url(url),
'error':'idf_https_get/post unavailable',
'get_error':get_error
}
end
end
try
var o = json.load(raw)
tasmoclaw_util.debug('native probe done url=' + tasmoclaw_util.safe_url(url) + ' ok=' + str(o.find('ok')) + ' status=' + str(o.find('status')) + ' stage=' + str(o.find('stage')) + ' esp_err=' + str(o.find('esp_err')))
return {
'ok':o.find('ok') == true,
'transport':'esp_http_client',
'native_available':true,
'url':tasmoclaw_util.safe_url(url),
'status':o.find('status'),
'stage':o.find('stage'),
'esp_err':o.find('esp_err'),
'error':o.find('error'),
'body':tasmoclaw_util.preview(o.find('body'), 220)
}
except .. as e_json,m_json
tasmoclaw_util.debug('native probe invalid JSON: ' + str(e_json) + ' ' + str(m_json) + ' raw=' + tasmoclaw_util.preview(raw, 160))
return {
'ok':false,
'transport':'esp_http_client',
'native_available':true,
'url':tasmoclaw_util.safe_url(url),
'error':'native probe returned invalid JSON: '+str(m_json),
'body':tasmoclaw_util.preview(raw, 220)
}
end
end
def parse_response(body)
try
tasmoclaw_util.debug('llm parse response body_bytes=' + str(body == nil ? 0 : size(body)))
var o = json.load(body)
if o.find('choices') == nil || size(o['choices']) == 0
if o.find('error') != nil || o.find('message') != nil || o.find('detail') != nil
tasmoclaw_util.debug('llm parse API error object: ' + self.extract_error_message(body))
return {'ok':false,'error':'OpenAI-compatible API error: '+self.extract_error_message(body),'body':tasmoclaw_util.preview(body, 500)}
end
tasmoclaw_util.debug('llm parse missing choices')
return {'ok':false,'error':'OpenAI-compatible response missing choices','body':tasmoclaw_util.preview(body, 500)}
end
var msg = o['choices'][0]['message']
if msg == nil
tasmoclaw_util.debug('llm parse missing message')
return {'ok':false,'error':'OpenAI-compatible response missing message','body':tasmoclaw_util.preview(body, 500)}
end
if msg.find('content') == nil && msg.find('reasoning') != nil
tasmoclaw_util.debug('llm parse using reasoning field as local fallback')
return {'ok':true,'content':str(msg['reasoning']),'raw':o,'reasoning_fallback':true}
end
if msg.find('content') == nil
tasmoclaw_util.debug('llm parse missing message content')
return {'ok':false,'error':'OpenAI-compatible response missing message content','body':tasmoclaw_util.preview(body, 500)}
end
if msg['content'] == nil || size(msg['content']) == 0
tasmoclaw_util.debug('llm parse empty assistant content')
return {'ok':true,'content':'','raw':o,'empty_content':true}
end
tasmoclaw_util.debug('llm parse ok content_bytes=' + str(size(msg['content'])))
return {'ok':true,'content':msg['content'],'raw':o}
except .. as e,m
tasmoclaw_util.debug('llm parse JSON failure: ' + str(e) + ' ' + str(m) + ' body=' + tasmoclaw_util.preview(body, 160))
return {'ok':false,'error':'JSON parse failure: '+str(m),'body':tasmoclaw_util.preview(body, 500)}
end
end
end
var tasmoclaw_llm = module("tasmoclaw_llm")
tasmoclaw_llm.create = def()
return TasmoClawLLM()
end
return tasmoclaw_llm
