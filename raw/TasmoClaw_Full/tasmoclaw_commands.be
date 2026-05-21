import string
var tasmoclaw_commands = module("tasmoclaw_commands")
tasmoclaw_commands.contains = def(haystack, needle)
if haystack == nil || needle == nil
return false
end
var hi = string.tolower(str(haystack))
var ni = string.tolower(str(needle))
var i = string.find(hi, ni)
return i != nil && i >= 0
end
tasmoclaw_commands.first = def(args, keys, fallback)
if args == nil
return fallback
end
for k:keys
var v = args.find(k)
if v != nil && v != ''
return v
end
end
return fallback
end
tasmoclaw_commands.rtttl_presets = def()
return {
'happy_birthday':'Happy:d=4,o=5,b=120:8g,8g,a,g,c6,b,2g,8g,8g,a,g,d6,c6,2g,8g,8g,g6,e6,c6,b,a,2f6,8f6,e6,c6,d6,c6',
'happy':'Happy:d=4,o=5,b=120:8g,8g,a,g,c6,b,2g,8g,8g,a,g,d6,c6,2g,8g,8g,g6,e6,c6,b,a,2f6,8f6,e6,c6,d6,c6',
'success':'Success:d=16,o=5,b=180:c,e,g,c6',
'ok':'Success:d=16,o=5,b=180:c,e,g,c6',
'error':'Error:d=8,o=5,b=120:c,16p,c,16p,c',
'startup':'Startup:d=16,o=5,b=160:c,e,g,8c6,8p,g,c6',
'mario':'Mario:d=16,o=5,b=100:e6,e6,32p,e6,32p,c6,e6,32p,g6,8p,g',
'scale':'Scale:d=8,o=5,b=140:c,d,e,f,g,a,b,c6',
'twinkle':'Twinkle:d=4,o=5,b=100:c,c,g,g,a,a,2g,f,f,e,e,d,d,2c',
'ode':'Ode:d=4,o=5,b=120:e,e,f,g,g,f,e,d,c,c,d,e,e,d,2d'
}
end
tasmoclaw_commands.rtttl_key = def(name)
if name == nil
return ''
end
var key = string.tolower(str(name))
key = string.replace(key, ' ', '_')
key = string.replace(key, '-', '_')
return key
end
tasmoclaw_commands.is_rtttl = def(tune)
if tune == nil
return false
end
var s = str(tune)
var colon = string.find(s, ':')
var comma = string.find(s, ',')
var defaults = string.find(s, 'd=')
return colon != nil && colon >= 0 && comma != nil && comma >= 0 && defaults != nil && defaults >= 0
end
tasmoclaw_commands.rtttl_from_name = def(name)
var presets = tasmoclaw_commands.rtttl_presets()
return presets.find(tasmoclaw_commands.rtttl_key(name))
end
tasmoclaw_commands.families = def()
return [
{
'id':'status',
'title':'Status and diagnostics',
'keywords':['status','uptime','memory','heap','wifi','ip','module','template','gpio','i2c'],
'examples':['Status 0','Time','Uptime','Mem','Wifi','IPAddress','I2CScan']
},
{
'id':'sensors',
'title':'Sensors and I2C',
'keywords':['sensor','temperature','humidity','adc','analog','shtc3','i2c'],
'examples':['Status 8','Sensor','I2CScan']
},
{
'id':'power',
'title':'Power relays',
'keywords':['power','relay','toggle','switch','on','off'],
'examples':['Power','Power1','Power2','Power2 2','Power1 1','Power1 0']
},
{
'id':'audio',
'title':'I2S audio and RTTTL',
'keywords':['audio','i2s','play','song','rtttl','music','say','speak','volume','gain','beep','record'],
'examples':['I2SRtttl <tune>','I2SPlay sd:/music/file.mp3','I2SGain 20','I2SSay hello','I2SStop']
},
{
'id':'display',
'title':'Display and screen text',
'keywords':['display','screen','message','show text','draw','dimmer','rotate','font','model','lvgl'],
'examples':['Display','DisplayModel','DisplayWidth','DisplayHeight','DisplayDimmer','DisplayText hello','DisplayClear','DisplayReInit']
},
{
'id':'webcolor',
'title':'Web UI colors',
'keywords':['webcolor','web color','palette','theme','ui color','button color'],
'examples':['WebColor','WebColor1 #eaeaea','WebColor {"WebColor":["#cccccc", "..."]}']
},
{
'id':'berry',
'title':'Berry modules, scripts, and commands',
'keywords':['berry','script','library','module','lvgl','skill','command','load','compile'],
'examples':['Br print(tasmota.memory())','UfsRun /script.be']
},
{
'id':'light',
'title':'Lights, dimmers, and color',
'keywords':['light','led','dimmer','brightness','color','colour','ct','white','fade','scheme'],
'examples':['Power 1','Power 0','Dimmer 50','Color FF8800','CT 350','Scheme 2','Fade 1','Speed 5']
},
{
'id':'mqtt',
'title':'MQTT status, config, and publish',
'keywords':['mqtt','publish','topic','fulltopic','grouptopic','prefix','retain'],
'examples':['MqttHost','MqttPort','Topic','FullTopic','Publish stat/topic hello']
},
{
'id':'network',
'title':'Wi-Fi and network',
'keywords':['network','wifi','ssid','hostname','ipaddress','ntp','timezone'],
'examples':['Wifi','IPAddress','Hostname','NtpServer1','Timezone']
},
{
'id':'telemetry',
'title':'Telemetry and logging',
'keywords':['telemetry','teleperiod','log','weblog','seriallog','syslog'],
'examples':['TelePeriod','TelePeriod 300','WebLog','SerialLog','SysLog']
},
{
'id':'system',
'title':'System control',
'keywords':['system','restart','reset','backlog','event','sleep','template','module'],
'examples':['State','Status 0','Backlog Power1 1; Delay 10; Power1 0','Event hello=1','Restart 1']
},
{
'id':'rules',
'title':'Rules and timers',
'keywords':['rule','rules','timer','event','trigger'],
'examples':['Rules','Rule1','Rule2','Rule3','Rule3 0','Rule3 "']
},
{
'id':'filesystem',
'title':'FlashFS, SD card, and UFS',
'keywords':['file','filesystem','ufs','sd','card','flash','delete','list','copy','move'],
'examples':['Ufs','UfsType','UfsSize','UfsFree','UfsList sd:/','UfsList flash:/']
},
{
'id':'timers',
'title':'Timers, RuleTimer, PulseTime, and schedules',
'keywords':['timer','timers','ruletimer','pulsetime','schedule','delay'],
'examples':['Timers','Timer1','RuleTimer1','RuleTimer1 5','PulseTime1','PulseTime1 10']
}
]
end
tasmoclaw_commands.search = def(args)
var q = tasmoclaw_commands.first(args, ['query','q','text'], '')
var out = []
for f:tasmoclaw_commands.families()
var hit = q == ''
if !hit
if tasmoclaw_commands.contains(f.find('id'), q) || tasmoclaw_commands.contains(f.find('title'), q)
hit = true
end
end
if !hit
for kw:f.find('keywords')
if tasmoclaw_commands.contains(kw, q) || tasmoclaw_commands.contains(q, kw)
hit = true
end
end
end
if hit
out.push(f)
end
end
return {'ok':true,'query':q,'families':out}
end
tasmoclaw_commands.classify_command = def(command)
if command == nil || command == ''
return {'ok':false,'error':'missing command','safety':'dangerous','requires_approval':true}
end
var c = str(command)
var lower = string.tolower(c)
var first = lower
var rest = ''
var sp = string.find(lower, ' ')
if sp != nil && sp >= 0
first = lower[0..sp-1]
rest = lower[sp+1..size(lower)-1]
end
var safety = 'action'
var reason = 'Command changes device state or is not known to be read-only.'
if first == 'status'
safety = 'read'
reason = 'Status is read-only.'
elif first == 'time' && rest == ''
safety = 'read'
reason = 'Time without payload is read-only.'
elif first == 'uptime' && rest == ''
safety = 'read'
reason = 'Uptime is read-only.'
elif first == 'mem' && rest == ''
safety = 'read'
reason = 'Mem is read-only.'
elif first == 'state' && rest == ''
safety = 'read'
reason = 'State is read-only.'
elif first == 'module' && rest == ''
safety = 'read'
reason = 'Module without payload is read-only.'
elif first == 'template' && rest == ''
safety = 'read'
reason = 'Template without payload is read-only.'
elif first == 'gpio' && rest == ''
safety = 'read'
reason = 'GPIO without payload is read-only.'
elif first == 'i2cscan' && rest == ''
safety = 'read'
reason = 'I2CScan is read-only.'
elif first == 'sensor'
safety = 'read'
reason = 'Sensor read is read-only.'
elif first == 'wifi'
safety = 'read'
reason = 'Wifi status is read-only.'
elif first == 'ipaddress' && rest == ''
safety = 'read'
reason = 'IPAddress without payload is read-only.'
elif first == 'teleperiod' && rest == ''
safety = 'read'
reason = 'TelePeriod without payload is read-only.'
elif (first == 'weblog' || first == 'seriallog' || first == 'syslog' || first == 'mqttlog') && rest == ''
safety = 'read'
reason = 'Log level without payload is read-only.'
elif first == 'power' && rest == ''
safety = 'read'
reason = 'Power without payload is read-only.'
elif (first == 'power1' || first == 'power2' || first == 'power3' || first == 'power4') && rest == ''
safety = 'read'
reason = 'Power channel without payload is read-only.'
elif first == 'ufs' || first == 'ufstype' || first == 'ufssize' || first == 'ufsfree' || first == 'ufslist'
safety = 'read'
reason = 'UFS status/list command is read-only.'
elif first == 'rules' && rest == ''
safety = 'read'
reason = 'Rules read is read-only.'
elif (first == 'rule1' || first == 'rule2' || first == 'rule3') && rest == ''
safety = 'read'
reason = 'Rule slot read is read-only.'
elif first == 'i2sconfig' && rest == ''
safety = 'read'
reason = 'I2SConfig without payload is read-only.'
elif (first == 'display' || first == 'displaymodel' || first == 'displaytype' || first == 'displaywidth' || first == 'displayheight' || first == 'displaymode' || first == 'displaydimmer' || first == 'displaysize' || first == 'displayfont' || first == 'displayrotate' || first == 'displayinvert' || first == 'displaycolumns' || first == 'displayrows') && rest == ''
safety = 'read'
reason = 'Display command without payload is read-only.'
elif (first == 'webcolor' || string.find(first, 'webcolor') == 0) && rest == ''
safety = 'read'
reason = 'WebColor without payload is read-only.'
elif (first == 'dimmer' || first == 'color' || first == 'colour' || first == 'ct' || first == 'white' || first == 'scheme' || first == 'fade' || first == 'speed' || first == 'ledstate') && rest == ''
safety = 'read'
reason = 'Light command without payload is read-only.'
elif (first == 'mqtthost' || first == 'mqttport' || first == 'mqttuser' || first == 'topic' || first == 'fulltopic' || first == 'grouptopic' || first == 'prefix1' || first == 'prefix2' || first == 'prefix3' || first == 'buttonretain' || first == 'powerretain' || first == 'switchretain') && rest == ''
safety = 'read'
reason = 'MQTT config command without payload is read-only.'
elif (first == 'hostname' || first == 'ntpserver1' || first == 'ntpserver2' || first == 'ntpserver3' || first == 'timezone' || first == 'latitude' || first == 'longitude') && rest == ''
safety = 'read'
reason = 'Network/time config command without payload is read-only.'
elif string.find(first, 'pulsetime') == 0 && rest == ''
safety = 'read'
reason = 'PulseTime without payload is read-only.'
elif string.find(first, 'ruletimer') == 0 && rest == ''
safety = 'read'
reason = 'RuleTimer without payload is read-only.'
elif first == 'timers' && rest == ''
safety = 'read'
reason = 'Timers without payload is read-only.'
elif string.find(first, 'timer') == 0 && rest == ''
safety = 'read'
reason = 'Timer without payload is read-only.'
elif string.find(first, 'setoption') == 0 && rest == ''
safety = 'read'
reason = 'SetOption without payload is read-only.'
elif first == 'restart' || first == 'reset' || first == 'upgrade' || first == 'otaurl' || first == 'wificonfig' || first == 'wifimanager'
safety = 'dangerous'
reason = 'Command may reboot, reset, upgrade, or change connectivity.'
elif first == 'backlog'
if tasmoclaw_commands.contains(rest, 'restart') || tasmoclaw_commands.contains(rest, 'reset') || tasmoclaw_commands.contains(rest, 'upgrade') || tasmoclaw_commands.contains(rest, 'otaurl') || tasmoclaw_commands.contains(rest, 'ufsdelete')
safety = 'dangerous'
reason = 'Backlog contains a high-impact command.'
else
safety = 'action'
reason = 'Backlog can change state.'
end
elif first == 'rule1' || first == 'rule2' || first == 'rule3' || string.find(first, 'setoption') == 0
safety = 'write'
reason = 'Command writes persistent configuration or rules.'
elif first == 'ssid1' || first == 'ssid2' || first == 'password1' || first == 'password2' || first == 'hostname' || first == 'ipaddress'
safety = 'dangerous'
reason = 'Network identity command can disconnect the device.'
elif first == 'mqtthost' || first == 'mqttport' || first == 'mqttuser' || first == 'topic' || first == 'fulltopic' || first == 'grouptopic' || first == 'prefix1' || first == 'prefix2' || first == 'prefix3' || first == 'teleperiod' || first == 'weblog' || first == 'seriallog' || first == 'syslog' || first == 'ntpserver1' || first == 'ntpserver2' || first == 'ntpserver3' || first == 'timezone' || first == 'latitude' || first == 'longitude'
safety = 'write'
reason = 'Command writes device configuration.'
elif first == 'dimmer' || first == 'color' || first == 'colour' || first == 'ct' || first == 'white' || first == 'scheme' || first == 'fade' || first == 'speed' || first == 'ledstate' || string.find(first, 'pulsetime') == 0 || string.find(first, 'ruletimer') == 0 || first == 'timers' || string.find(first, 'timer') == 0
safety = 'action'
reason = 'Command changes light, timer, or runtime behavior.'
elif first == 'ufsdelete' || first == 'ufsrename' || first == 'ufsmkdir' || first == 'ufsrmdir' || first == 'ufsrun'
safety = 'write'
reason = 'Command modifies or runs files.'
elif first == 'publish' || first == 'publish2' || first == 'event' || first == 'displaytext' || first == 'displaytextnc' || first == 'displayclear' || first == 'displayrefresh' || first == 'displayreinit' || first == 'displaybatch'
safety = 'action'
reason = 'Command sends output or triggers device behavior.'
elif first == 'webcolor' || string.find(first, 'webcolor') == 0
safety = 'write'
reason = 'WebColor command writes UI palette settings.'
elif first == 'i2srtttl' || first == 'i2splay' || first == 'i2sloop' || first == 'i2spause' || first == 'i2sstop' || first == 'i2sgain' || first == 'i2ssay' || first == 'i2sbeep' || first == 'i2srec' || first == 'i2stime'
safety = 'action'
reason = 'I2S audio command changes audio state.'
end
return {
'ok':true,
'command':c,
'safety':safety,
'requires_approval':safety != 'read',
'reason':reason
}
end
tasmoclaw_commands.timer_command = def(args)
var kind = string.tolower(str(tasmoclaw_commands.first(args, ['kind','type','timer_type'], 'rule')))
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','mode'], 'read')))
var slot = tasmoclaw_commands.first(args, ['slot','index','timer','channel'], '')
var value = tasmoclaw_commands.first(args, ['value','seconds','duration','payload','definition'], nil)
var cmd = 'RuleTimer'
if kind == 'pulse' || kind == 'pulsetime' || action == 'pulse'
cmd = 'PulseTime'
elif kind == 'timer' || kind == 'schedule'
cmd = 'Timer'
elif kind == 'timers'
cmd = 'Timers'
end
if cmd != 'Timers' && slot != nil && slot != ''
var slot_s = str(slot)
var slot_l = string.tolower(slot_s)
var cmd_l = string.tolower(cmd)
if slot_l == cmd_l
elif string.find(slot_l, cmd_l) == 0
cmd = slot_s
else
cmd += slot_s
end
end
if action == 'read' || action == 'status' || action == 'show'
return cmd
elif action == 'enable' && cmd == 'Timers'
return 'Timers 1'
elif action == 'disable' && cmd == 'Timers'
return 'Timers 0'
elif action == 'clear' || action == 'stop' || action == 'off'
return cmd + ' 0'
elif action == 'set' || action == 'start' || action == 'write' || action == 'on'
if value == nil
return nil
end
return cmd + ' ' + str(value)
end
if value != nil
return cmd + ' ' + str(value)
end
return nil
end
tasmoclaw_commands.filesystem_command = def(args)
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','mode'], 'list')))
var p = tasmoclaw_commands.first(args, ['path','file','filename'], '')
if action == 'status' || action == 'info'
return 'Ufs'
elif action == 'type'
return 'UfsType'
elif action == 'size'
return 'UfsSize'
elif action == 'free'
return 'UfsFree'
elif action == 'list' || action == 'ls' || action == 'read'
return p == '' ? 'UfsList' : 'UfsList ' + str(p)
elif action == 'delete' || action == 'remove'
if p == ''
return nil
end
return 'UfsDelete ' + str(p)
elif action == 'mkdir' || action == 'createdir'
if p == ''
return nil
end
return 'UfsMkDir ' + str(p)
elif action == 'rmdir' || action == 'removedir'
if p == ''
return nil
end
return 'UfsRmDir ' + str(p)
elif action == 'rename' || action == 'move'
var dest = tasmoclaw_commands.first(args, ['dest','destination','to'], '')
if p == '' || dest == ''
return nil
end
return 'UfsRename ' + str(p) + ',' + str(dest)
elif action == 'run'
if p == ''
return nil
end
return 'UfsRun ' + str(p)
end
return nil
end
tasmoclaw_commands.power_command = def(args)
var slot = tasmoclaw_commands.first(args, ['slot','channel','index','power'], '')
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','state'], 'read')))
var prefix = 'Power'
if slot != nil && slot != ''
prefix = 'Power' + str(slot)
end
if action == 'read' || action == 'status' || action == 'state'
return prefix
elif action == 'on'
return prefix + ' 1'
elif action == 'off'
return prefix + ' 0'
elif action == 'toggle' || action == 'switch'
return prefix + ' 2'
end
return nil
end
tasmoclaw_commands.audio_command = def(args)
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','mode'], 'rtttl')))
if action == 'rtttl' || action == 'song' || action == 'tune'
var tune = tasmoclaw_commands.first(args, ['rtttl','tune','body'], nil)
if tune != nil && !tasmoclaw_commands.is_rtttl(tune)
var named_tune = tasmoclaw_commands.rtttl_from_name(tune)
if named_tune == nil
return nil
end
tune = named_tune
end
if tune == nil
var preset = tasmoclaw_commands.first(args, ['preset','name','song'], nil)
if preset != nil
tune = tasmoclaw_commands.rtttl_from_name(preset)
end
end
if tune == nil || !tasmoclaw_commands.is_rtttl(tune)
return nil
end
return 'I2SRtttl ' + str(tune)
elif action == 'play'
var p = tasmoclaw_commands.first(args, ['path','file','filename','url'], '')
return p == '' ? 'I2SPlay' : 'I2SPlay ' + str(p)
elif action == 'loop'
var lp = tasmoclaw_commands.first(args, ['path','file','filename','url'], '')
return 'I2SLoop ' + str(lp)
elif action == 'pause'
return 'I2SPause'
elif action == 'resume'
return 'I2SPlay'
elif action == 'stop'
return 'I2SStop'
elif action == 'say' || action == 'speak'
var text = tasmoclaw_commands.first(args, ['text','message','content'], '')
return 'I2SSay ' + str(text)
elif action == 'gain' || action == 'volume'
var value = tasmoclaw_commands.first(args, ['value','level','gain','volume'], '25')
return 'I2SGain ' + str(value)
elif action == 'beep'
var duration = tasmoclaw_commands.first(args, ['duration','duration_ms','ms'], '')
return duration == '' ? 'I2SBeep' : 'I2SBeep ' + str(duration)
elif action == 'codec'
return 'I2SCodec'
elif action == 'time'
return 'I2STime'
elif action == 'record' || action == 'rec'
var seconds = tasmoclaw_commands.first(args, ['seconds','duration'], '')
var dest = tasmoclaw_commands.first(args, ['path','file','filename'], '')
if seconds == ''
return 'I2SRec'
end
return dest == '' ? 'I2SRec ' + str(seconds) : 'I2SRec ' + str(seconds) + ',' + str(dest)
end
return nil
end
tasmoclaw_commands.display_command = def(args)
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','mode'], 'text')))
if action == 'read' || action == 'status' || action == 'info'
return 'Display'
elif action == 'model'
return 'DisplayModel'
elif action == 'type'
return 'DisplayType'
elif action == 'width'
return 'DisplayWidth'
elif action == 'height'
return 'DisplayHeight'
elif action == 'mode'
var mode = tasmoclaw_commands.first(args, ['value','mode_value'], nil)
return mode == nil ? 'DisplayMode' : 'DisplayMode ' + str(mode)
elif action == 'dimmer' || action == 'brightness'
var dimmer = tasmoclaw_commands.first(args, ['value','level','dimmer','brightness'], nil)
return dimmer == nil ? 'DisplayDimmer' : 'DisplayDimmer ' + str(dimmer)
elif action == 'size'
var display_size = tasmoclaw_commands.first(args, ['value','size'], nil)
return display_size == nil ? 'DisplaySize' : 'DisplaySize ' + str(display_size)
elif action == 'font'
var font = tasmoclaw_commands.first(args, ['value','font'], nil)
return font == nil ? 'DisplayFont' : 'DisplayFont ' + str(font)
elif action == 'rotate' || action == 'rotation'
var rot = tasmoclaw_commands.first(args, ['value','rotation','rotate'], nil)
return rot == nil ? 'DisplayRotate' : 'DisplayRotate ' + str(rot)
elif action == 'invert'
var inv = tasmoclaw_commands.first(args, ['value','enabled','invert'], nil)
return inv == nil ? 'DisplayInvert' : 'DisplayInvert ' + str(inv)
elif action == 'clear'
return 'DisplayClear'
elif action == 'refresh'
return 'DisplayRefresh'
elif action == 'reinit' || action == 'restart'
return 'DisplayReInit'
elif action == 'batch'
var path = tasmoclaw_commands.first(args, ['path','file','filename'], '')
return path == '' ? nil : 'DisplayBatch ' + str(path)
end
var msg = tasmoclaw_commands.first(args, ['message','text','content'], '')
return 'DisplayText ' + str(msg)
end
tasmoclaw_commands.light_command = def(args)
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','mode'], 'read')))
if action == 'read' || action == 'status'
return str(tasmoclaw_commands.first(args, ['command','cmd'], 'State'))
elif action == 'on'
return 'Power 1'
elif action == 'off'
return 'Power 0'
elif action == 'toggle'
return 'Power 2'
elif action == 'dimmer' || action == 'brightness'
return 'Dimmer ' + str(tasmoclaw_commands.first(args, ['value','level','brightness'], '50'))
elif action == 'color' || action == 'colour'
return 'Color ' + str(tasmoclaw_commands.first(args, ['value','color','colour'], 'FFFFFF'))
elif action == 'ct' || action == 'temperature'
return 'CT ' + str(tasmoclaw_commands.first(args, ['value','ct'], '350'))
elif action == 'white'
return 'White ' + str(tasmoclaw_commands.first(args, ['value','white'], '50'))
elif action == 'scheme' || action == 'effect'
return 'Scheme ' + str(tasmoclaw_commands.first(args, ['value','scheme','effect'], '0'))
elif action == 'fade'
return 'Fade ' + str(tasmoclaw_commands.first(args, ['value','enabled','fade'], '1'))
elif action == 'speed'
return 'Speed ' + str(tasmoclaw_commands.first(args, ['value','speed'], '5'))
end
return nil
end
tasmoclaw_commands.mqtt_command = def(args)
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','mode'], 'read')))
if action == 'publish'
var topic = tasmoclaw_commands.first(args, ['topic','name'], '')
var payload = tasmoclaw_commands.first(args, ['payload','message','text','content'], '')
if topic == ''
return nil
end
return 'Publish ' + str(topic) + ' ' + str(payload)
elif action == 'publish2'
var topic2 = tasmoclaw_commands.first(args, ['topic','name'], '')
var payload2 = tasmoclaw_commands.first(args, ['payload','message','text','content'], '')
if topic2 == ''
return nil
end
return 'Publish2 ' + str(topic2) + ' ' + str(payload2)
end
var key = string.tolower(str(tasmoclaw_commands.first(args, ['key','setting'], 'host')))
var value = tasmoclaw_commands.first(args, ['value','host','port','topic','prefix'], nil)
var cmd = 'MqttHost'
if key == 'host'
cmd = 'MqttHost'
elif key == 'port'
cmd = 'MqttPort'
elif key == 'user'
cmd = 'MqttUser'
elif key == 'topic'
cmd = 'Topic'
elif key == 'fulltopic'
cmd = 'FullTopic'
elif key == 'grouptopic'
cmd = 'GroupTopic'
elif key == 'prefix1' || key == 'prefix2' || key == 'prefix3'
cmd = key[0..0] == 'p' ? 'Prefix' + key[size(key)-1..size(key)-1] : key
elif key == 'retain'
cmd = 'PowerRetain'
end
return value == nil ? cmd : cmd + ' ' + str(value)
end
tasmoclaw_commands.telemetry_command = def(args)
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','mode','setting','key'], 'teleperiod')))
if action == 'read' || action == 'teleperiod' || action == 'period'
var period = tasmoclaw_commands.first(args, ['seconds','value','period'], nil)
return period == nil ? 'TelePeriod' : 'TelePeriod ' + str(period)
elif action == 'weblog'
var wl = tasmoclaw_commands.first(args, ['level','value'], nil)
return wl == nil ? 'WebLog' : 'WebLog ' + str(wl)
elif action == 'seriallog'
var sl = tasmoclaw_commands.first(args, ['level','value'], nil)
return sl == nil ? 'SerialLog' : 'SerialLog ' + str(sl)
elif action == 'syslog'
var yl = tasmoclaw_commands.first(args, ['level','value'], nil)
return yl == nil ? 'SysLog' : 'SysLog ' + str(yl)
elif action == 'status'
return 'Status ' + str(tasmoclaw_commands.first(args, ['value','status'], '0'))
end
return 'State'
end
tasmoclaw_commands.network_command = def(args)
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','setting'], 'wifi')))
var value = tasmoclaw_commands.first(args, ['value','name','host','server'], nil)
var cmd = 'Wifi'
if action == 'wifi'
cmd = 'Wifi'
elif action == 'ip' || action == 'ipaddress'
cmd = 'IPAddress'
elif action == 'hostname'
cmd = 'Hostname'
elif action == 'ntp' || action == 'ntpserver1'
cmd = 'NtpServer1'
elif action == 'ntpserver2'
cmd = 'NtpServer2'
elif action == 'ntpserver3'
cmd = 'NtpServer3'
elif action == 'timezone'
cmd = 'Timezone'
elif action == 'ssid1'
cmd = 'SSId1'
elif action == 'ssid2'
cmd = 'SSId2'
end
return value == nil ? cmd : cmd + ' ' + str(value)
end
tasmoclaw_commands.system_command = def(args)
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','mode'], 'state')))
if action == 'state'
return 'State'
elif action == 'status'
return 'Status ' + str(tasmoclaw_commands.first(args, ['value','status'], '0'))
elif action == 'event'
var event_name = tasmoclaw_commands.first(args, ['name','event'], '')
var payload = tasmoclaw_commands.first(args, ['payload','value'], '')
return payload == '' ? 'Event ' + str(event_name) : 'Event ' + str(event_name) + '=' + str(payload)
elif action == 'backlog'
return 'Backlog ' + str(tasmoclaw_commands.first(args, ['commands','command','body'], ''))
elif action == 'restart'
return 'Restart ' + str(tasmoclaw_commands.first(args, ['value','mode'], '1'))
elif action == 'module'
var module_value = tasmoclaw_commands.first(args, ['value','module'], nil)
return module_value == nil ? 'Module' : 'Module ' + str(module_value)
elif action == 'template'
var template = tasmoclaw_commands.first(args, ['value','template'], nil)
return template == nil ? 'Template' : 'Template ' + str(template)
end
return nil
end
tasmoclaw_commands.rule_command = def(args)
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','mode'], 'read')))
var slot = str(tasmoclaw_commands.first(args, ['rule','slot'], 'Rules'))
if slot == '1' || slot == '2' || slot == '3'
slot = 'Rule' + slot
end
if action == 'read' || action == 'list' || action == 'show' || action == 'status'
return slot == 'Rules' ? 'Rules' : slot
elif action == 'enable'
return slot + ' 1'
elif action == 'disable'
return slot + ' 0'
elif action == 'clear' || action == 'delete' || action == 'remove'
return slot + ' "'
elif action == 'set' || action == 'apply' || action == 'write'
var definition = tasmoclaw_commands.first(args, ['definition','rule_definition','content'], '')
if definition == ''
return nil
end
return slot + ' ' + str(definition)
end
return nil
end
tasmoclaw_commands.berry_command = def(args)
var action = string.tolower(str(tasmoclaw_commands.first(args, ['action','mode'], 'console')))
if action == 'load' || action == 'run'
var p = tasmoclaw_commands.first(args, ['path','file','filename'], '')
if p == ''
return nil
end
var ps = string.replace(str(p), '\\', '\\\\')
ps = string.replace(ps, '"', '\\"')
return 'Br load("' + ps + '")'
end
var code = tasmoclaw_commands.first(args, ['code','expr','expression','body'], '')
if code == ''
return nil
end
return 'Br ' + str(code)
end
tasmoclaw_commands.build = def(args)
if args == nil
args = {}
end
var raw = tasmoclaw_commands.first(args, ['command','cmd','cmnd'], nil)
if raw != nil && raw != ''
var cls = tasmoclaw_commands.classify_command(raw)
cls['description'] = 'Raw Tasmota command'
return cls
end
var family = string.tolower(str(tasmoclaw_commands.first(args, ['family','domain','tool'], '')))
var command = nil
if family == 'audio' || family == 'i2s' || family == 'sound'
command = tasmoclaw_commands.audio_command(args)
elif family == 'display' || family == 'screen'
command = tasmoclaw_commands.display_command(args)
elif family == 'light' || family == 'led'
command = tasmoclaw_commands.light_command(args)
elif family == 'mqtt'
command = tasmoclaw_commands.mqtt_command(args)
elif family == 'telemetry' || family == 'log'
command = tasmoclaw_commands.telemetry_command(args)
elif family == 'network' || family == 'wifi'
command = tasmoclaw_commands.network_command(args)
elif family == 'system' || family == 'event' || family == 'backlog'
command = tasmoclaw_commands.system_command(args)
elif family == 'power' || family == 'relay'
command = tasmoclaw_commands.power_command(args)
elif family == 'rule' || family == 'rules'
command = tasmoclaw_commands.rule_command(args)
elif family == 'timer' || family == 'timers' || family == 'ruletimer' || family == 'pulsetime'
command = tasmoclaw_commands.timer_command(args)
elif family == 'filesystem' || family == 'file' || family == 'ufs' || family == 'sd' || family == 'flash'
command = tasmoclaw_commands.filesystem_command(args)
elif family == 'berry' || family == 'br'
command = tasmoclaw_commands.berry_command(args)
end
if command == nil || command == ''
return {'ok':false,'error':'could not build command from args'}
end
var out = tasmoclaw_commands.classify_command(command)
out['description'] = family + ' command'
return out
end
return tasmoclaw_commands
