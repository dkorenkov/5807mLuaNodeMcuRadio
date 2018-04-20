local M = {}

function M.exec(parameters, onDone)  
    local result={}
    result.output=""
    function s_output(str)
      if str~=nil then 
        result.output=result.output..str
      end  
    end
    print("sending line "..parameters.." to interpreter")  
 
    tmr.alarm(1,100,tmr.ALARM_SINGLE, function ()
      print("Started "..parameters.."  execution")
      node.output(s_output, 1) 
      local resultValue=node.input(parameters)           
      if onDone~=nil then
        tmr.alarm(1,1000,tmr.ALARM_SINGLE, function ()
          node.output(nil)
          result.output=result.output:sub(1, -4)
          onDone(result)
          result=nil
        end)  
      end     
    end)  
end

return M
