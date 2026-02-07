#######################################################################
# Wifi Heap Sticker
#
# Sticker to show realtime wifi strengh and memory (top left of main page)

#################################################################################
# Wifi_Heap_Sticker
#################################################################################
class Wifi_Heap_Sticker

  static var HTTP_HEAD_STYLE_WIFI =
    "<style>"
    ".wifi{width:18px;height:12px;position:relative}"
    ".arc{padding:0;position:absolute;border:2px solid transparent;border-radius:50%;border-top-color:var(--c_txt)}"
    ".a0{width:2px;height:3px;top:9px;left:8px}"
    ".a1{width:6px;height:6px;top:6px;left:6px}"
    ".a2{width:12px;height:12px;top:3px;left:3px}"
    ".a3{width:18px;height:18px;top:0px;left:0px}"
    ".o30{opacity:.3}"
    "</style>"

  def init()

    tasmota.add_driver(self)
  end

  def unload()
    tasmota.remove_driver(self)
  end

  #################################################################################
  # called when displaying the left status line
  def web_status_line_left()
    import webserver
    # display wifi
    if tasmota.wifi('up')
      webserver.content_send(self.HTTP_HEAD_STYLE_WIFI)
      var rssi = tasmota.wifi('rssi')
      webserver.content_send(format("<div class='wifi' title='%s: RSSI %d%% (%d dBm)'><div class='arc a3%s'></div><div class='arc a2%s'></div><div class='arc a1%s'></div><div class='arc a0'></div></div>",
                                    tasmota.wifi('ssid'),
									tasmota.wifi('quality'), rssi,
                                    rssi < -55 ? " o30" : "",
                                    rssi < -70 ? " o30" : "",
                                    rssi < -85 ? " o30" : ""))
    end
    # display free heap
    var gc_time = tasmota.memory('gc_time')
    var gc_heap = tasmota.memory('gc_heap')
    if (gc_time != nil) && (gc_heap != nil)
      webserver.content_send(f"<span>&nbsp;{tasmota.memory('heap_free')}-{gc_heap}k [{gc_time}ms]</span>")
    else
      webserver.content_send(f"<span>&nbsp;{tasmota.memory('heap_free')}k</span>")
    end
  end
end

return Wifi_Heap_Sticker()
