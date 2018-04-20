-- Create the httpd server
svr = net.createServer (net.TCP, 30)

-- radio-specific functions
local radio=nil

if cjson==nil and sjson~=nil then cjson=sjson end

function Sendfile(client, filename)
    print("sending file "..filename)
    local contentType="text/plain; charset=us-ascii"
    if filename:find(".htm") then
      contentType="text/html; charset=UTF-8"
    end
    local fh=file.open(filename, "r")
    if fh then
        local function sendChunk()
            local line = file.read(512)
            if line then 
                client:send(line, sendChunk)
                line=nil 
            else
                file.close()
                client:close()
                collectgarbage()
            end
        end
        client:send("HTTP/1.1 200 OK\r\n" ..
            "Server: NodeMCU on ESP8266\r\n" ..
            "Content-Type: "..contentType.."\r\n\r\n", sendChunk)
    else
        client:send("HTTP/1.0 404 Not Found\r\n\r\nPage not found")
        client:close()
        collectgarbage()
    end
end

function onReady(client, file, jsonObjectString)
    --local request=cjson.decode(bodyContent)
                     --if request~=nil then                 
                        --print("json handling required")
                        --handleJsonRequest(request)
    local result={}
    if file~=nil then 
      result.filename=file
      -- compile "lua" files if emought memory
      --if string.sub(result.filename,-string.len(".lua"))==".lua" then
      --  print("compiling "..result.filename)
      --  local p=node.compile(result.filename)
      --  print("compiled "..result.filename)
      --end
      client:send("HTTP/1.1 200 OK\r\n" ..
            "Server: NodeMCU on ESP8266\r\n" ..
            "Content-Type: application/json; charset=UTF-8\r\n\r\n"..cjson.encode(result))  
      client:close()       
      print("Data sent back to client")   
    elseif jsonObjectString~=nil and jsonObjectString:len()>2 then
     print("decoding '" .. jsonObjectString .. "'")
     local jsonObject=cjson.decode(jsonObjectString) 
     if jsonObject.moduleName~=nil and jsonObject.functionName~=nil then
        local M=require(jsonObject.moduleName)
        M[jsonObject.functionName](jsonObject.params, function(callbackResult)
          client:send("HTTP/1.1 200 OK\r\n" ..
              "Server: NodeMCU on ESP8266\r\n" ..
              "Content-Type: application/json; charset=UTF-8\r\n\r\n"..cjson.encode(callbackResult))  
          client:close()      
          print("Data sent back to client") 
          collectgarbage()
        end)
     elseif jsonObject.moduleName==nil and jsonObject.functionName~=nil then
          local callbackResult={}
          if radio==nil then
            radio=require("5807m")
          end  
          callbackResult.status=radio[jsonObject.functionName](jsonObject.params)
          client:send("HTTP/1.1 200 OK\r\n" ..
              "Server: NodeMCU on ESP8266\r\n" ..
              "Content-Type: application/json; charset=UTF-8\r\n\r\n"..cjson.encode(callbackResult))  
          client:close()      
          print("Object function result sent back to client") 
          collectgarbage()     
     else      
       client:send("HTTP/1.1 200 OK\r\n" ..
              "Server: NodeMCU on ESP8266\r\n" ..
              "Content-Type: application/json; charset=UTF-8\r\n\r\n"..cjson.encode(result))  
        client:close()      
        print("Data sent back to client")   
      end
    end       
    collectgarbage()          
end


local function connect (conn, data)
   local jsonObject=nil
   local bytesLeft=0
   local contentType=""
   local fileName=nil
   conn:on ("receive",
      function (cn, req_data)
         print("New data arrived from "..tostring(cn))         
         print(req_data) 
         if bytesLeft>0 then
           bytesLeft=bytesLeft-req_data:len()
           if fileName then   
            if file.open(fileName,"a+") then
              file.write(req_data)
              file.close()  
            end
           elseif jsonObject~=nil then              
              bytesLeft=bytesLeft-req_data:len()
              jsonObject=jsonObject..req_data     
           end           
           if bytesLeft<=0 then
            print("finally, all data received")
            onReady(cn,fileName,jsonObject)
            fileName=nil
            jsonObject=nil
           end
         else -- bytesLeft<=0
           local query_data = get_http_req (req_data)
           local host=query_data["Host"] 
           if host==nil then host="unknown" end
           print (query_data["METHOD"] .. " from  " .. host)  
           if query_data["METHOD"]=="GET" then
               bytesLeft=0
               fileName=nil
               jsonObject=nil
               local path = string.match(req_data, "GET /(.+) HTTP")
               if  path == nil or path == "" or path=="/"  then path = "index.html" end
               if path~="favicon.ico" then 
                  Sendfile(cn, path)
               end
           elseif query_data["METHOD"]=="POST" or query_data["METHOD"]=="PUT" then
              for key,value in pairs(query_data) do print("key="..key..", value="..value) end
              if query_data["Content-Length"] and tonumber(query_data["Content-Length"])>0 then 
                bytesLeft=tonumber(query_data["Content-Length"])
                print("Expecting "..bytesLeft.." bytes in body")
                contentType=query_data["Content-Type"]
                fileName=nil
                if contentType:find("text/plain")==1 and query_data["REQUEST"] then
                  print(" @@@@@@@@@@ Waiting for text @@@@@@@@@@@@@ "..query_data["REQUEST"])
                  -- key=REQUEST, value=/file.html?httpServer.lua HTTP/1.1
                  local i=query_data["REQUEST"]:find("%?")
                  local j=query_data["REQUEST"]:find("% ")
                  if i>0 and j>0 then
                    fileName=query_data["REQUEST"]:sub(i+1,j-1)
                    print("Saving data in file "..fileName)
                    file.remove(fileName)                    
                  end
                elseif contentType:find("application/json") then
                    jsonObject=""
                    print("Will be waiting for json object, size "..bytesLeft)
                end
              end --query_data["Content-Length"] 
              if query_data["BODY"]~=nil and contentType~=nil and bytesLeft>0 then
                  print("Request contains body: ".. query_data["BODY"])
                  bytesLeft=bytesLeft-query_data["BODY"]:len()
                  if contentType:find("text/plain") then                         
                      if fileName then                    
                        if file.open(fileName,"w+")then
                          file.write(query_data["BODY"])
                          file.close()  
                        end
                      end 
                   elseif contentType:find("application/json") then
                      jsonObject=jsonObject..query_data["BODY"]
                      print("jsonObject="..jsonObject)                                                               
                   end -- text/plain                              
                   if bytesLeft<=0 then
                      print("all data received")
                      onReady(cn,fileName,jsonObject)
                      fileName=nil
                      jsonObject=nil
                   else
                       print("Waiting for more data, need "..bytesLeft.." bytes")
                   end
              end -- query_data["BODY"]~=nil 
         else -- query_data["METHOD"] is unknown
            print("Query method not found or unknown ")         
         end 
        end 
      end)
end


-- Build and return a table of the http request data
function get_http_req (instr)
   local t={}
   local first=nil
   local key, v, strt_ndx, end_ndx
   local bodyDelimiter=instr:find("\n\r?\n\r?")
   if bodyDelimiter~=nil then
    t["BODY"] = instr:sub(bodyDelimiter+2)
    instr=instr:sub(1,bodyDelimiter) 
   end 
   for str in instr:gmatch("([^\n]+)") do
      -- First line in the method and path
      if (first == nil) then
         first = 1
         strt_ndx, end_ndx = str:find("([^ ]+)")
         if (end_ndx ~= nil) then 
          v = trim (str:sub(end_ndx + 2))
          key = trim (str:sub (strt_ndx, end_ndx))
          t["METHOD"] = key
          t["REQUEST"] = v
         end 
      else -- Process and reamaining ":" fields
         strt_ndx, end_ndx = str:find("([^:]+)")
         if (end_ndx ~= nil) then
            v = trim (str:sub(end_ndx + 2))
            key = trim (str:sub(strt_ndx, end_ndx))
            t[key] = v
         end
      end
   end   
   return t
end

-- String trim left and right
function trim (s)
  return (s:gsub ("^%s*(.-)%s*$", "%1"))
end

-- Server listening on port 80, call connect function if a request is received
svr:listen (80, connect)