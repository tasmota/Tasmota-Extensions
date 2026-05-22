do
import introspect
var app = introspect.module('tasmoclaw_lite', true)
tasmota.add_extension(app)
end
