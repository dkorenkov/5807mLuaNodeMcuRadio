local M = {}

function M.getStatus(parameters, onDone) 
    local result={}
    result.nodeId=node.chipid()
    result.memory=node.heap()
    result.hostName=wifi.sta.gethostname()    
    majorVer, minorVer, devVer, chipid, flashid, flashsize, flashmode, flashspeed = node.info()
    result.nodeMcuVersion=majorVer.."."..minorVer.."."..devVer
    result.wifiPowerMode=wifi.getphymode()
    result.signal=wifi.sta.getrssi()
    if onDone~=nil then
      onDone(result)
    end
    result=nil
end


function M.getFiles(parameters, onDone) 
    local result={}
    result.fileList=file.list()  
    result.flashsize=node.flashsize()
    result.remaining, result.used, result.total=file.fsinfo()    
    result.memory=node.heap()
    if onDone~=nil then
      onDone(result)
    end
    result=nil
end


function M.compile(parameters, onDone) 
    local result={}
    print("will compile in 10 seconds")
    tmr.alarm(1,10000,tmr.ALARM_SINGLE, function ()
      print("Started compilation")
      node.compile(parameters)  
    end)     
    if onDone~=nil then
      onDone(result)
      collectgarbage()
    end
    result=nil
end


function M.doFile(parameters, onDone) 
    local result={}
    result.doResult=dofile(parameters)     
    if onDone~=nil then
      onDone(result)
    end
    result=nil
end


function M.deleteFile(parameters, onDone) 
    local result={}
    file.remove(parameters)   
    if onDone~=nil then
      onDone(result)
    end
    result=nil
end

function M.restart(parameters, onDone) 
    local result={} 
    print("restart requested")   
    if onDone~=nil then
      onDone(result)
      print("restarting...")  
      node.restart()   
    end
    result=nil
end


function M.initiateShutdownIn(milliSecondsWait,sleepTimeMilliSeconds)
  local DEEP_SLEEP_TIMER=1
  tmr.stop(DEEP_SLEEP_TIMER)
  tmr.alarm(DEEP_SLEEP_TIMER, milliSecondsWait, 0, function ()
     if sleepTimeMilliSeconds>2147483 or sleepTimeMilliSeconds<=0 then
      sleepTimeMilliSeconds=2147483
     end     
     print('Going into deep sleep for '..sleepTimeMilliSeconds..' milliseconds. Bye!')
     node.dsleep(sleepTimeMilliSeconds*1000)
  end)
  print('System shutdown in '..milliSecondsWait..' milliseconds, timer#'..DEEP_SLEEP_TIMER)
end

function M.cancelShutdown()
  local DEEP_SLEEP_TIMER=1
  tmr.stop(DEEP_SLEEP_TIMER)
  print('System shutdown cancelled')
end

gpio.mode(4,gpio.INPUT,gpio.FLOAT)
gpio.write(4,gpio.LOW)

function M.blink(milliseconds, pin1, blinkTimer)
  local pin=pin1 or 4
  local BLINK_TIMER=blinkTimer or 6
  tmr.stop(BLINK_TIMER)
  if milliseconds>0 then
    local count=0
    tmr.alarm(BLINK_TIMER, milliseconds, 1, function ()
      count=count+1
      gpio.write(pin,count%2)
    end)
    print('Blinking every '..milliseconds..' milliseconds, timer#'..BLINK_TIMER)
  else
    gpio.write(pin,gpio.LOW)  
  end
end

function M.getWebPagePayload(webPage)
	    local nIndex=string.find(webPage,"\r\n\r\n")
	    if nIndex>0 then
        return string.sub(webPage,nIndex+4)
      end
      nIndex=string.find(webPage,"\n\n")
      return string.sub(webPage,nIndex+2)
end

function M.logMessage(level,message) 
   print(level..' >'..message)
   local location=location or 312
   local messageBody=encoder.toBase64(message)
   local ok, json = pcall(cjson.encode, {message=message, level=level})
   if ok then
      --print("\nSending message "..json)
      http.post("http://192.168.2.100:8080/esp8266/logMessage?loc="..location.."&cid="..node.chipid(), 
        'Content-Type: application/json\r\n', 
        json,
        function(code, response)
          if (code ~= 200) then 
            if response~=nil then          
              print("\nHTTP request failed, code="..code.." body: "..response)
            else
              print("\nHTTP request failed, code="..code)
            end  
          else
           if response~=nil then   
            print ("received "..response)
           else
            print("Error 200");
           end 
          end 
      end)    
   else
      print("failed to encode!")
   end
end

function M.getHttpData(request,onDone)  
  http.get("http://192.168.2.100:8080"..request, 
    nil, 
    function(code, response)
      onDone(response,code)            
    end)  
end

return M
