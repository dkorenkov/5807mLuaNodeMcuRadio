local M = {}

function M.compile(parameters, onDone) 
    local result={}
    print("will compile in 10 seconds")
    tmr.alarm(1,10000,tmr.ALARM_SINGLE, function ()
      print("Started "..parameters.."  compilation")
      node.compile(parameters)  
       print("Complieted "..parameters.." compilation")
    end)     
    if onDone~=nil then
      onDone(result)
      collectgarbage()
    end
    result=nil
end

return M
