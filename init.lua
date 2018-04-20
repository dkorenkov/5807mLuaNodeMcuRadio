tmr.softwd(900) -- set up software watchdog for 900 seconds
gpio.mode(4,gpio.OUTPUT)
gpio.write(4,gpio.LOW)
gpio.mode(6,gpio.OUTPUT)
gpio.write(6,gpio.HIGH)
gpio.mode(7,gpio.OUTPUT)
gpio.write(7,gpio.LOW)
location=16
wifi.sta.sethostname("LuaRadio")
print('Starting main program in 4 seconds, timer #1')
gpio.write(4,gpio.LOW)
tmr.alarm(1,4000,tmr.ALARM_AUTO, function ()
   ip,nm=wifi.sta.getip(1)
   if ip then 
    tmr.unregister(1)
    print("Starting server on http://"..ip.."")
    node.compile("5807m.lua")
    gpio.write(4,gpio.HIGH)
    gpio.write(6,gpio.LOW)
    dofile("httpServer.lc")
    tmr.softwd(-1) -- clear software watchdog 
   else
     print("unable to connect to WIFI")
   end  
end)

