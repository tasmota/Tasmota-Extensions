###################################################################################
# Display in Main GUI Devices Online based on MQTT Tasmota Discovery Config and STATE reports
#
# Copyright (C) 2025  Stephan Hadinger & Theo Arends
#
# Enable either
#  line_option = 1  : Scroll 'line_cnt' lines
# or
#  line_option = 2  : Show devices updating within 'line_teleperiod'
#
# rm Devices_Online.tapp; zip -j -0 Devices_Online.tapp Devices_Online/*
###################################################################################

import mqtt 
import json
import string
import webserver
import persist

class devices_online
#  static var line_option = 1                       # Scroll line_cnt lines
  static var line_option = 2                        # Show devices updating within line_teleperiod

  static var line_cnt = 10                          # Option 1 number of lines to show
  static var line_teleperiod = 600                  # Option 2 number of teleperiod seconds for devices to be shown as online
  static var line_highlight = 10                    # Highlight latest change duration in seconds
  static var line_highlight_color = "yellow"        # Latest change highlight HTML color like "#FFFF00" or "yellow"
  static var line_lowuptime_color = "lime"          # Low uptime highlight HTML color like "#00FF00" or "lime"

  var mqtt_state                                    # MQTT tele STATE subscribe format
  var mqtt_topic_idx                                # Index of %topic% within full topic
  var mqtt_step                                     # MQTT message state
  var bool_devicename                               # Show device name
  var bool_version                                  # Show version
  var bool_ipaddress                                # Show IP address
  var sort_direction                                # Sort direction
  var sort_column                                   # Sort column
  var sort_last_column                              # Sort last column
  var list_buffer                                   # Buffer storing lines
  var list_config                                   # Buffer storing retained config

  #################################################################################
  # init
  #
  # install the extension and allocate all resources
  #################################################################################
  def init()
    self.bool_devicename = persist.find("dvo_devicename", 0) # Show device name
    self.bool_version = persist.find("dvo_version", 0)       # Show version
    self.bool_ipaddress = persist.find("dvo_upaddress", 0)   # Show IP address
    self.sort_direction = persist.find("dvo_direction", 0)   # Sort direction (0) Up or (1) Down, default Up
    self.sort_column = persist.find("dvo_column", 0)         # Sort column, default Hostname
    if !persist.has("dvo_column")
      self.persist_save()
    end
    self.sort_last_column = self.sort_column        # Sort last column to detect direction toggle

    self.list_buffer = []                           # Init line buffer list
    self.list_config = []                           # Init retained config buffer list

    var parts = string.split(tasmota.cmd('_FullTopic', true)['FullTopic'], '/')
    var prefix3 = tasmota.cmd("Prefix", true)['Prefix3'] # tele = Prefix3 used by STATE message
    self.mqtt_topic_idx = -1
    for ix : 0..size(parts)-1
      var level = parts[ix]
      if level == '%prefix%' 
        parts[ix] = prefix3
      elif level == '%topic%'
        parts[ix] = '+'
        self.mqtt_topic_idx = ix
      elif level == ''
        parts[ix] = 'STATE'
      else
        parts[ix] = '+'
      end
    end
    self.mqtt_state = parts.concat('/')             # default = tele/+/STATE

    if self.mqtt_topic_idx == -1
      log("DVO: ERROR No %topic% in FullTopic defined", 1)
      return
    end

    tasmota.add_driver(self)

    mqtt.subscribe(self.mqtt_state, /topic, idx, data, databytes -> self.handle_state_data(topic, idx, data, databytes))
    mqtt.subscribe("tasmota/discovery/+/config", /topic, idx, data, databytes -> self.handle_discovery_data(topic, idx, data, databytes))

    self.mqtt_step = 0
    if !mqtt.connected()
      log("DVO: Need MQTT connected", 1)
    end
  end

  #################################################################################
  # unload
  #
  # Uninstall the extension and deallocate all resources
  #################################################################################
  def unload()
    mqtt.unsubscribe("tasmota/discovery/+/config")
    mqtt.unsubscribe(self.mqtt_state)
    tasmota.remove_driver(self)
  end

  #################################################################################
  # handle_discovery_data(discovery_topic, idx, data, databytes)
  #
  # Handle MQTT Tasmota Discovery Config data
  #################################################################################
  def handle_discovery_data(discovery_topic, idx, data, databytes)
    if self.mqtt_step == 0
      log("DVO: Discovery started...", 3)
      self.mqtt_step = 1
    end
#    log(f"DVO: Discovery topic '{discovery_topic}'", 4)
    var config = json.load(data)
    if config
      # tasmota/discovery/142B2F9FAF38/config = {"ip":"192.168.2.208","dn":"AtomLite2","fn":["Tasmota",null,null,null,null,null,null,null],"hn":"atomlite2","mac":"142B2F9FAF38","md":"M5Stack Atom Lite","ty":0,"if":0,"cam":0,"ofln":"Offline","onln":"Online","state":["OFF","ON","TOGGLE","HOLD"],"sw":"15.0.1.4","t":"atomlite2","ft":"%prefix%/%topic%/","tp":["cmnd","stat","tele"],"rl":[2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"swc":[-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1],"swn":[null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null],"btn":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"so":{"4":0,"11":0,"13":0,"17":0,"20":0,"30":0,"68":0,"73":0,"82":0,"114":0,"117":0},"lk":1,"lt_st":3,"bat":0,"dslp":0,"sho":[],"sht":[],"ver":1} (retained)
      var topic = config['t']
      var hostname = config['hn']
      var ipaddress = config['ip']
      var devicename = config['dn']
      var version = config['sw']
      var line = [topic, hostname, ipaddress, devicename, version]
      if self.list_config.size()
        var list_index = 0
        var list_size = size(self.list_config)
        while list_index < list_size                # Use while loop as counter is decremented
          if self.list_config[list_index][0] == topic
            self.list_config.remove(list_index)     # Remove current config
            list_size -= 1                          # Continue for duplicates
          end
          list_index += 1
        end
      end
      self.list_config.push(line)                   # Add (re-discovered) config as last entry
    end
    return true                                     # return true to stop propagation as a Tasmota cmd
  end

  #################################################################################
  # handle_state_data(tele_topic, idx, data, databytes)
  #
  # Handle MQTT STATE data
  #################################################################################
  def handle_state_data(tele_topic, idx, data, databytes)
    if self.mqtt_step == 1 
      log("DVO: Discovery complete", 3)
      self.mqtt_step = 2
    end
#    log(f"DVO: STATE topic '{tele_topic}'", 4)
    var subtopic = string.split(tele_topic, "/")
    if subtopic[-1] == "STATE"                      # we are only serving topic ending in STATE
      var topic = subtopic[self.mqtt_topic_idx]
      var topic_index = -1
      for i: self.list_config.keys()
        if self.list_config[i][0] == topic
          topic_index = i
          break
        end
      end
#      log(format("DVO: Topic '%s', Index %d, Size %d, Line '%s'", topic, topic_index, self.list_config.size(), self.list_config[topic_index]), 3)
      if topic_index == -1 return true end          # return true to stop propagation as a Tasmota cmd

      var state = json.load(data)                   # Assume topic is in retained discovery list
      if state                                      # Valid JSON state message
        var hostname = self.list_config[topic_index][1]
        var ipaddress = self.list_config[topic_index][2]
        var devicename = self.list_config[topic_index][3]
        var version = self.list_config[topic_index][4]
        var version_splits = string.split(version, ".")
        var version_int = 0
        var multiplier = 0x1000000
        for split : version_splits
          version_int += int(split) * multiplier
          if multiplier
            multiplier /= 0x100
          end
        end
        var version_num = format("%011i", version_int) # 00235143427 - Convert to string to enable multicolumn sort

        # tele/atomlite2/STATE = {"Time":"2025-09-24T14:13:00","Uptime":"0T00:15:09","UptimeSec":909,"Heap":142,"SleepMode":"Dynamic","Sleep":50,"LoadAvg":19,"MqttCount":1,"Berry":{"HeapUsed":12,"Objects":167},"POWER":"OFF","Dimmer":10,"Color":"1A0000","HSBColor":"0,100,10","Channel":[10,0,0],"Scheme":0,"Width":1,"Fade":"OFF","Speed":1,"LedTable":"ON","Wifi":{"AP":1,"SSId":"indebuurt_IoT","BSSId":"18:E8:29:CA:17:C1","Channel":11,"Mode":"HT40","RSSI":100,"Signal":-28,"LinkCount":1,"Downtime":"0T00:00:04"},"Hostname":"atomlite2","IPAddress":"192.168.2.208"}
        var uptime = state['Uptime']                # 0T00:15:09
        var uptime_sec = format("%011i", state['UptimeSec']) # 00000000909 - Convert to string to enable multicolumn sort
        if state.find('Hostname')
          hostname = state['Hostname']              # atomlite2
          ipaddress = state['IPAddress']            # 192.168.2.208
        end
        var last_seen = tasmota.rtc('local')
        var line = [hostname, ipaddress, uptime, uptime_sec, last_seen, devicename, version, version_num]
        if self.list_buffer.size()
          var list_index = 0
          var list_size = size(self.list_buffer)
          while list_index < list_size              # Use while loop as counter is decremented
            if self.list_buffer[list_index][0] == hostname || self.list_buffer[list_index][1] == ipaddress
              self.list_buffer.remove(list_index)   # Remove current state
              list_size -= 1                        # Continue for duplicates
            end
            list_index += 1
          end
        end
        self.list_buffer.push(line)                 # Add state as last entry

      end
    end
    return true                                     # return true to stop propagation as a Tasmota cmd
  end

  #################################################################################
  # sort_col(l, col, dir)
  #
  # Shell sort list of online devices based on user selected column and direction
  #################################################################################
  def sort_col(l, col, dir)
    var cmp = /a,b -> a < b                         # Sort up
    if dir
      cmp = /a,b -> a > b                           # Sort down
    end

    if col == 0                                     # Sort hostname as primary key
      for i:1..size(l)-1                            # Sort string
        var k = l[i]
        var ks = k[col]
        var j = i
        while (j > 0) && !cmp(l[j-1][col], ks)
          l[j] = l[j-1]
          j -= 1
        end
        l[j] = k
      end
    else                                            # Sort any other string using primary and secondary key
      for i:1..size(l)-1
        var k = l[i]
        var ks = k[col] + k[0]                      # Primary search key and Secondary unique search key (hostname)
        var j = i
        while (j > 0) && !cmp(l[j-1][col] + l[j-1][0], ks)
          l[j] = l[j-1]
          j -= 1
        end
        l[j] = k
      end
    end
  end

  #################################################################################
  # persist_save
  #
  # Save user data to be used on restart
  #################################################################################
  def persist_save()
    persist.dvo_devicename = self.bool_devicename
    persist.dvo_version = self.bool_version
    persist.dvo_ipaddress = self.bool_ipaddress
    persist.dvo_column = self.sort_column
    persist.dvo_direction = self.sort_direction
    persist.save()
#    log("DVO: Persist saved", 3)
  end

  #################################################################################
  # web_sensor
  #
  # Display Devices Online in user selected sorted columns
  #################################################################################
  def web_sensor()
    if webserver.has_arg("sd_dn")
      # Toggle display Device Name
      self.bool_devicename ^= 1
      self.persist_save()
    elif webserver.has_arg("sd_sw")
      # Toggle display software version
      self.bool_version ^= 1
      self.persist_save()
    elif webserver.has_arg("sd_ip")
      # Toggle display IP address
      self.bool_ipaddress ^= 1
      self.persist_save()
    elif webserver.has_arg("sd_sort")
      # Toggle sort column
      self.sort_column = int(webserver.arg("sd_sort"))
      if self.sort_last_column == self.sort_column
        self.sort_direction ^= 1
      end
      self.sort_last_column = self.sort_column
      self.persist_save()
    end

    if self.list_buffer.size()
      var now = tasmota.rtc('local')
      var time_window = now - self.line_teleperiod
      var list_index = 0
      var list_size = size(self.list_buffer)
      while list_index < list_size
        var last_seen = self.list_buffer[list_index][4]
        if time_window > int(last_seen)             # Remove offline devices
          self.list_buffer.remove(list_index)
          list_size -= 1
        end
        list_index += 1
      end
      if !list_size return end                      # If list became empty bail out

      var msg = "</table><table style='width:100%;font-size:80%'>" # Terminate two column table and open new table
      msg += "<tr>"

      list_index = 0
      if 1 == self.line_option
        list_index = list_size - self.line_cnt      # Offset in list using self.line_cnt
        if list_index < 0 list_index = 0 end

        if self.bool_devicename
          msg += "<th>Device Name&nbsp</th>"
        end
        if self.bool_version
          msg += "<th>Version&nbsp</th>"
        end
        msg += "<th>Hostname&nbsp</th>"
        if self.bool_ipaddress
          msg += "<th>IP Address&nbsp</th>"
        end
        msg += "<th align='right'>Uptime&nbsp</th>"
      else
#        var start = tasmota.millis()
        self.sort_col(self.list_buffer, self.sort_column, self.sort_direction) # Sort list by column
#        var stop = tasmota.millis()
#        log(format("DVO: Sort time %d ms", stop - start), 3)
        var icon_direction = self.sort_direction ? "&#x25BC" : "&#x25B2"
        if self.bool_devicename
          msg += format("<th><a href='#p' onclick='la(\"&sd_sort=5\");'>Device Name</a>%s&nbsp</th>", self.sort_column == 5 ? icon_direction : "")
        end
        if self.bool_version
          msg += format("<th><a href='#p' onclick='la(\"&sd_sort=7\");'>Version</a>%s&nbsp</th>", self.sort_column == 7 ? icon_direction : "")
        end
        msg += format("<th><a href='#p' onclick='la(\"&sd_sort=0\");'>Hostname</a>%s&nbsp</th>", self.sort_column == 0 ? icon_direction : "")
        if self.bool_ipaddress
          msg += format("<th><a href='#p' onclick='la(\"&sd_sort=1\");'>IP Address</a>%s&nbsp</th>", self.sort_column == 1 ? icon_direction : "")
        end
        msg += format("<th align='right'><a href='#p' onclick='la(\"&sd_sort=3\");'>Uptime</a>%s&nbsp</th>", self.sort_column == 3 ? icon_direction : "")
      end

      msg += "</tr>"

      while list_index < list_size
        var hostname = self.list_buffer[list_index][0]
        var ipaddress = self.list_buffer[list_index][1]
        var uptime = self.list_buffer[list_index][2]
        var uptime_sec = self.list_buffer[list_index][3]
        var last_seen = self.list_buffer[list_index][4]
        var devicename = self.list_buffer[list_index][5]
        var version = self.list_buffer[list_index][6]

        msg += "<tr>"
        if self.bool_devicename
          msg += format("<td>%s&nbsp</td>", devicename)
        end
        if self.bool_version
          msg += format("<td>%s&nbsp</td>", version)
        end
        msg += format("<td><a target=_blank href='http://%s.'>%s&nbsp</a></td>", hostname, hostname)
        if self.bool_ipaddress
          msg += format("<td><a target=_blank href='http://%s'>%s&nbsp</a></td>", ipaddress, ipaddress)
        end

        if int(last_seen) >= (now - self.line_highlight) # Highlight changes within latest seconds
          msg += format("<td align='right' style='color:%s'>%s</td>", self.line_highlight_color, uptime)
        elif int(uptime_sec) < self.line_teleperiod  # Highlight changes just after restart
          msg += format("<td align='right' style='color:%s'>%s</td>", self.line_lowuptime_color, uptime)
        else 
          msg += format("<td align='right'>%s</td>", uptime)
        end

        msg += "</tr>"
        list_index += 1
      end
      msg += "</table>{t}"                          # Terminate three/four/five column table and open new table: <table style='width:100%'>
      msg += format("{s}Devices online{m}%d{e}", list_size) # <tr><th>Devices online</th><td style='width:20px;white-space:nowrap'>%d</td></tr>

      msg += "</table><p></p>{t}"                   # Terminate two column table and open new table: <table style='width:100%'>
      msg += "<td style=\"width:33%\"><button onclick='la(\"&sd_dn=1\");'>Name</button></td>"
      msg += "<td style=\"width:33%\"><button onclick='la(\"&sd_sw=1\");'>Version</button></td>"
      msg += "<td style=\"width:33%\"><button onclick='la(\"&sd_ip=1\");'>Address</button></td>"
      msg += "</table>{t}"                          # Terminate two column table and open new table: <table style='width:100%'>

      tasmota.web_send(msg)                         # Do not use tasmota.web_send_decimal() which will replace IPAddress dots
      tasmota.web_send_decimal("")                  # Force horizontal line
    end
  end

end

return devices_online()
