function handleJsonRequest(request) 
  for key,value in pairs(request) do print("json key="..key..", json value="..value) end
  local functionName=request["type"]
  if functionName=="compile" then
    if file.open(request["fileName"], "a+") then
      -- write 'foo bar' to the end of the file
      file.write(request["fileContent"])
      file.close()
      return node.compile(request["fileName"])
    end
  end
end 