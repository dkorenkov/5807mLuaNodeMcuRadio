-- see https://github.com/papadkostas/RDA5807M/blob/master/RDA5807M/RDA5807M.h
-- see https://github.com/papadkostas/RDA5807M/blob/master/RDA5807M/RDA5807M.c
local M = {}
local sda=2
local scl=1
local id=0
--local dev_addr=0x10
local dev_addr=0x60  --5767 mode 
-- Initialization Options 
local StartingFreq 	= 8700
local EndingFreq 		= 10800
local DefaultFreq		= 10490
local StartingVolume =	0x4 
 
local RDASequential 	=0x10  
local RDARandom  		  =0x11  
local  ADRW 	 =       0x20
local  ADRR 	 =      0x21
local  RDA_CHIP_ID    = 0x0058
local  RDA_DHIZ        =0x8000
local   RDA_MUTE		   =0x8000
local  RDA_MONO_ON     =0x2000
local   RDA_MONO_OFF	 =0xDFFF
local   RDA_BASS_ON     =0x1000
local   RDA_BASS_OFF	  =0xEFFF
local   RDA_RCLK_MODE  =0x0800
local   RDA_RCLK_DIRECT =0x0400
local   RDA_SEEK_UP     =0x0300
local   RDA_SEEK_DOWN	  =0x0100
local   RDA_SEEK_STOP	  =0xFCFF
local   RDA_SEEK_WRAP   =0x0080
local   RDA_SEEK_NOWRAP =0xFF7F
local   RDA_RDS_ON      =0x0008
local   RDA_RDS_OFF		  =0xFFF7
local   RDA_RESET       =0x0002
local   RDA_POWER       =0x0001
local   RDA_TUNE_ON		  =0x0010
local   RDA_TUNE_OFF	  =0xFFEF
 
local RDAstatus=0 
 
-- initialize i2c, set pin1 as sda, set pin2 as scl
i2c.setup(id, sda, scl, i2c.SLOW)

--calculate parameters and write frequency to tea5767
function M.set_freq(freq)
  local frequency = 4 * (freq * 100000 + 225000) / 32768
  local frequencyH = frequency / 256
  local frequencyL = bit.band(frequency,0xff)
  i2c.start(id)  
  if i2c.address(id, dev_addr ,i2c.TRANSMITTER) then
    print("Transmitter ok")
    i2c.write(id,frequencyH)
    i2c.write(id,frequencyL)
    i2c.write(id,0xB0)
    i2c.write(id,0x10)
    i2c.write(id,0)
    i2c.stop(id)
    return true
  else
      print("Transmitter failed")
      return false
  end    
end

local RDA5807M_WriteRegDef ={0xC004,0x0000,0x0100,0x84D4,0x4000,0x0000,0x0000}
local RDA5807M_WriteReg={0,0,0,0,0,0,0,0}

local RDA5807M_ReadReg={0,0,0,0,0,0,0}
local RDA5807M_RDS={}
for i=1,32 do RDA5807M_RDS[i]=0 end



----- RDS Variables
local StationName={}    -- Station Name. 8 characters
local RDStextbuffer={}  -- RDS text buffer 64 characters
local  RDStext={}        --  RDS text message 64 characters
local 	RDSscrolltext={}	  -- RDS scroll text buffer,64
local  CTtime={}         -- CT time string formatted as 'CT hh:mm', 12 chard
local	c1, c2				      -- RDS text characters
local 	PSName={}    		  -- 10 symbols including trailing '\00' character.
local 	PSName1={}		    -- Station Name buffer1, 10 
local 	PSName2={}       -- Station Name buffer2, 10 



function M.RDA5807_Init()	
	for i=1, 7 do
		RDA5807M_WriteReg[i] = RDA5807M_WriteRegDef[i]
	end		
  return RDAstatus	
end

-- Set frequency in khz*10. For example, 104.9 MHz becomes 10490
function M.RDA5807_Frequency(Freq) 
  print("Setting frequency to "..Freq)
	local Channel = (Freq-StartingFreq)/10
	print("Setting channel to "..Channel)
	Channel = bit.band(Channel , 0x03FF)
	RDA5807M_WriteReg[2] = Channel*64 +0x10  -- Channel + TUNE-Bit + Band=00(87-108) + Space=00(100kHz)
	RDAstatus = RDA5807_WriteAll()
	RDA5807M_WriteReg[2] = bit.band(RDA5807M_WriteReg[1] , RDA_TUNE_OFF)
	return M.RDA5807_Read() 
end

function M.RDA5807_Volume(vol)
  vol=bit.band(vol,0xF)
  RDA5807M_WriteReg[4] = bit.bor(bit.band(RDA5807M_WriteReg[4] , 0xFFF0), vol)   --  Set New Volume
	RDAstatus = RDA5807_WriteAll()
	return M.RDA5807_Read() 
end

function M.RDA5807_PowerOn()
	RDA5807M_WriteReg[2] = bit.bor(RDA5807M_WriteReg[2] , 0x0010)
	RDA5807M_WriteReg[1] = bit.bor(RDA5807M_WriteReg[1] , RDA_POWER)
	RDAstatus = RDA5807_WriteAll()
	RDA5807M_WriteReg[2] = bit.band(RDA5807M_WriteReg[2] , 0xFFEF) --Disable tune after PowerOn operation
	return RDAstatus
end

function M.RDA5807_PowerOff()
	RDA5807M_WriteReg[1] = bit.bxor(RDA5807M_WriteReg[1] , RDA_POWER)
	RDAstatus = RDA5807_WriteAll()
	return RDAstatus
end

function M.RDA5807_Reset()
	RDAstatus = M.RDA5807_Init()
	RDAstatus = M.RDA5807_PowerOn()
  RDAstatus = M.RDA5807_Volume(StartingVolume)	
	tmr.alarm(1,100,tmr.ALARM_SINGLE, function ()
      M.RDA5807_Frequency(DefaultFreq)
  end)
	--RDAstatus = RDA5807_RDSinit() -- fix RDS part
	--RDAstatus = M.RDA5807_RDS()
	return RDAstatus
end

local I2C3_DATA={}

-- save all register in fixed address from fixed start
function RDA5807_WriteAll()
  local x=1
	for i=0, 10, 2 do
    -- print("setting data i="..i..", x="..x.." baseValue ="..RDA5807M_WriteReg[x])
		I2C3_DATA[i+1] = bit.arshift(RDA5807M_WriteReg[x],8)
		x=x+1
	end
	
	x = 1
	for i=1, 11, 2 do
     --   print("setting data i="..i..", x="..x.." baseValue ="..RDA5807M_WriteReg[x])
		I2C3_DATA[i+1] = bit.band(RDA5807M_WriteReg[x] , 0xFF)
		x=x+1
	end

  for k,v in pairs(I2C3_DATA) do
    print("sending index:"..k..", value:"..v)
  end
	
	i2c.start(id)  
  if i2c.address(id, RDASequential ,i2c.TRANSMITTER) then
    print("Transmitter ok")    	        
    i2c.write(id,I2C3_DATA)      
    i2c.stop(id)
    return true
  else
      print("Transmitter failed")
      return false
  end    	
end

-- toggle bass boost
function M.RDA5807_BassBoost()
    if bit.band(RDA5807M_WriteReg[1], 0x1000)==0 then
    	RDA5807M_WriteReg[1] = bit.bor(RDA5807M_WriteReg[1], RDA_BASS_ON)    
    else
    	RDA5807M_WriteReg[1] = bit.band(RDA5807M_WriteReg[1], RDA_BASS_OFF )
    end	
    RDAstatus = RDA5807_WriteAll()
    return RDAstatus
end

--toggle mono
function M.RDA5807_Mono()
    if bit.band(RDA5807M_WriteReg[1] , 0x2000)==0 then 
    	RDA5807M_WriteReg[1] = bit.bor(RDA5807M_WriteReg[1] , RDA_MONO_ON)
    else
    	RDA5807M_WriteReg[1] = bit.band(RDA5807M_WriteReg[1] , RDA_MONO_OFF)
    end
    RDAstatus = RDA5807_WriteAll()
    return RDAstatus
end

-- toggle mute
function M.RDA5807_Mute()
    if bit.band(RDA5807M_WriteReg[1] , 0x8000)==0 then
    	RDA5807M_WriteReg[1] =  bit.bor(RDA5807M_WriteReg[1] , 0x8000)    
    else
    	RDA5807M_WriteReg[1] = bit.band(RDA5807M_WriteReg[1] , 0x7FFF)
    end
    RDAstatus = RDA5807_WriteAll()
    return M.RDA5807_Read() 
end

-- does not work for me
--[[function RDA5807_Softmute()
    if bit.band(RDA5807M_WriteReg[3] , 0x0200)==0 then 
    	RDA5807M_WriteReg[3] =  bit.bor(RDA5807M_WriteReg[3] , 0x0200)    
    else
    	RDA5807M_WriteReg[3] = bit.band(RDA5807M_WriteReg[3] , 0xFDFF)
    end
    RDAstatus = RDA5807_WriteAll()
    return RDAstatus
end

function RDA5807_SoftBlend()
    if bit.band(RDA5807M_WriteReg[7] , 0x0001)==0 then
    	RDA5807M_WriteReg[7] = bit.bor(RDA5807M_WriteReg[7] , 0x0001)
    
    else
    	RDA5807M_WriteReg[7] = bit.band(RDA5807M_WriteReg[7] , 0xFFFE)
    end
    RDAstatus = RDA5807_WriteAll()
    return RDAstatus
end


function M.RDA5807_SeekUp()
	RDA5807M_WriteReg[1] = bit.bor(RDA5807M_WriteReg[1] , RDA_SEEK_UP)   -- Set Seek Up
	RDAstatus = RDA5807_WriteAll()
	RDA5807M_WriteReg[1] = bit.band( RDA5807M_WriteReg[1] , RDA_SEEK_STOP)   -- Disable Seek
	return RDAstatus
end

function M.RDA5807_SeekDown()
	RDA5807M_WriteReg[1] = bit.bor(RDA5807M_WriteReg[1] , RDA_SEEK_DOWN)   -- Set Seek Down
	RDAstatus = RDA5807_WriteAll()
	RDA5807M_WriteReg[1] =  bit.band(RDA5807M_WriteReg[1] , RDA_SEEK_STOP)   -- Disable Seek
	return RDAstatus
end
--]]

--toggle Radio Data System 
function M.RDA5807_RDS()
    if bit.band(RDA5807M_WriteReg[1] , RDA_RDS_ON)==0 then
    	RDA5807M_WriteReg[1] = bit.bor(RDA5807M_WriteReg[1] , RDA_RDS_ON)    
    else 
    	RDA5807M_WriteReg[1] = bit.bor(RDA5807M_WriteReg[1] , RDA_RDS_OFF)
    end
    RDAstatus = RDA5807_WriteAll()
    return RDAstatus
end

function bytetostring (bytes)
    local result=""
    for i=1,table.getn(bytes) do
      result=result..string.char(bytes[i])
    end  
    return result
end

local lastTextIDX = 0

function RDA5807_RDSinit()
  StationName= {string.byte("--------", 1,-1)}
  PSName= {string.byte("        ", 1,-1)}
  PSName1= {string.byte("        ", 1,-1)}
  PSName2={string.byte("        ", 1,-1)}
  for i=1,64 do RDStext[i]=0 end  
  for i=1,64 do RDStextbuffer[i]=0 end 
  lastTextIDX = 0
  mins=0
  CTtime= {string.byte("CT --:--")}
  return RDAstatus
end

function READ_RDAFM_2w(deviceAddr, registers, reg_addr, count) 
    i2c.start(id)
    if i2c.address(id, deviceAddr ,i2c.TRANSMITTER) then    
      print("Transmitter ok. Writing to addr "..deviceAddr.." "..reg_addr.." as read address")
      i2c.write(id, reg_addr)
      i2c.stop(id)
      i2c.start(id)
      if i2c.address(id, deviceAddr, i2c.RECEIVER) then
        print("Receiver ok. Reading from addr: "..deviceAddr)       
        local p=i2c.read(id,count)
        print("Read "..string.len(p).." starting from addr: "..deviceAddr)   
        for n = 1, string.len(p) do 
          print("read value at index "..n.." was "..string.byte(p,n))
          registers[n]=string.byte(p,n)
        end  
        i2c.stop(id)
        return true
      else
       print("Receiver failed")
      return false
      end  
    else
     print("Transmitter failed")
     return false
  end   
end  


function M.RDA5807_Read()  -- Read all RDA5807 registers	 
  --numeric RDS variables
  local  	rdsblockerror,rdssynchro,rdsready,rds,block1,block2,block3,block4
  local 	mins          		-- RDS CT time in minutes transmitted on the minute
  local 	textAB, lasttextAB
  local 	rdsGroupType, rdsTP, rdsPTY
  local 	idx              -- index of rdsText
  local 	offset           -- RDS time offset and sign
  
	
	RDAstatus = READ_RDAFM_2w(RDASequential,I2C3_DATA,0x20,12) --read 12 bytes
	for i=0,5 do
		RDA5807M_ReadReg[i+1] = bit.bor(bit.lshift(I2C3_DATA[i *2+1],8) , I2C3_DATA [(i*2) +2] )
  end

  

	rdsready = bit.band(RDA5807M_ReadReg[1] , 0x8000)			--if rdsready != 0 rds data are ready
	tuneok = bit.band(RDA5807M_ReadReg[1] , 0x4000)				--if tuneok != 0 seek/tune completed
	nochannel = bit.band(RDA5807M_ReadReg[1] , 0x2000)		--if nochannel != 0 no channel found
	rdssynchro = bit.band(RDA5807M_ReadReg[1] , 0x1000)			--if rdssynchro = 1000 rds decoder syncrhonized
	stereo = bit.band(RDA5807M_ReadReg[1] , 0x0400) 				--if stereo = 0 station is mono else stereo
	freq = (bit.band(RDA5807M_ReadReg[1] , 0x03FF) * 100) + 87000	--return freq ex 102600KHz > 102.6MHz
	signal = bit.rshift(RDA5807M_ReadReg[2] , 10)					--return signal strength rssi
	fmready =  bit.band(RDA5807M_ReadReg[2] , 0x0008) 			--if fmready = 8 > fm is ready
	fmstation =  bit.band(RDA5807M_ReadReg[2] , 0x0100) 			--if fmstation = 100 fm station is true
	rdsblockerror =  bit.band(RDA5807M_ReadReg[2] , 0x000C)		--check for rds blocks errors
														--00= 0 errors,01= 1~2 errors requiring correction
														--10= 3~5 errors requiring correction
														--11= 6+ errors or error in checkword, correction not possible.

  print("rdsready="..rdsready)
  print("tuneok="..tuneok)
  print("nochannel="..nochannel)
  print("rdssynchro="..rdssynchro)
  print("stereo="..stereo)
  
   print("freq="..freq)
   print("signal="..signal)
   print("fmready="..fmready)
   print("fmstation="..fmstation)
   print("rdsblockerror="..rdsblockerror)

  local result={}
  if rdsready~=0 then result.ready=1 else result.ready=0 end
  if stereo~=0 then result.stereo=1 else result.stereo=0 end
  result.freq=freq
  result.signal=signal
  if fmready==80 then 
    result.fmready=1 
    gpio.write(7,gpio.HIGH)
  else 
    result.fmready=0 
    gpio.write(7,gpio.LOW)
  end
  if fmstation==0x0100 then result.fmstation=1 else result.fmstation=0 end
  

  return result
--[[
  RDS part does not work as expected
	block1 = RDA5807M_ReadReg[3]  --RDS Text data blocks
	block2 = RDA5807M_ReadReg[4]
	block3 = RDA5807M_ReadReg[5]
	block4 = RDA5807M_ReadReg[6]

  print("block1="..block1)
  print("block2="..block2)
  print("block3="..block3)
  print("block4="..block4)

  if rdssynchro ~= 0x1000 then  -- RDS not synchronised or tuning changed, reset all the RDS info.
    RDA5807_RDSinit()
  end

  -- analyzing Block 2
  rdsGroupType = bit.bor(0x0A , bit.rshift(bit.band(block2 , 0xF000) , 8) , bit.rshift(bit.band(block2 , 0x0800), 11))
  rdsTP = bit.band(block2 , 0x0400)
  rdsPTY = bit.band(block2 , 0x0400)


  print("rdsGroupType="..rdsGroupType)
  print("rdsTP="..rdsTP)
  print("rdsPTY="..rdsPTY)

	 if rdsGroupType==0x0A or rdsGroupType==0x0B then
      print("Processing station name")
      -- The data received is part of the Service Station Name
      idx = 2 * bit.band(block2 , 0x0003)
      -- new data is 2 chars from block 4
      c1 = bit.rshift(block4,8)
      c2 = bit.band(block4 , 0x00FF)
      -- check that the data was received successfully twice
      -- before sending the station name
      if (PSName1[idx+1] == c1) and (PSName1[idx + 2] == c2) then
          -- retrieve the text a second time: store to _PSName2
          PSName2[idx+1] = c1
          PSName2[idx + 2] = c2
          PSName2[8+1] = 0
          if PSName1==PSName2 then
            -- populate station name
            n=0
            for i=0,7 do --  remove non-printable error ASCCi characters
                if(PSName2[i+1] > 31 and PSName2[i+1] < 127) then
                    StationName[n] = PSName2[i]
                    n=n+1
                end -- if(PSName2[i+1] > 31
            end --  for i=0,7
          end -- if PSName1==PSName2      
      end   -- if (PSName1[idx+1] == c1) ... 
      if (PSName1[idx+1] ~= c1) or (PSName1[idx + 2] ~= c2) then
          PSName1[idx+1] = c1
          PSName1[idx + 2] = c2
          PSName1[8+1] = 0      
	    end
	    print("PSName1: "..bytetostring (PSName1))
	    print("PSName2: "..bytetostring (PSName2))	    
	  elseif rdsGroupType==0x2A then
       print("Processing RDS text")
    -- RDS text
	    textAB = bit.band(block2 , 0x0010)
	    idx = 4 * bit.band(block2 , 0x000F)
	    print ("idx="..idx)
	    print ("lastTextIDX="..lastTextIDX)
	    if idx < lastTextIDX then
	      -- The existing text might be complete because the index is starting at the beginning again.
	      -- Populate RDS text array.
	    	n=0
        for i=1,string.len(RDStextbuffer) do
            if RDStextbuffer[i] > 31 and RDStextbuffer[i] < 127 then    -- remove non printable error characters
                RDStext[n+1] = RDStextbuffer[i+1]
                n=n+1
            end
        end -- for i=1,..
	    end --  if idx < lastTextIDX t
	    lastTextIDX = idx
	    if textAB ~= lasttextAB then
	      -- when this bit is toggled text data has changed, the whole buffer should be cleared.
	      lasttextAB = textAB
	      for i=1,64 do RDStext[i]=0 end  
        for i=1,64 do RDStextbuffer[i]=0 end 
	    end -- if textAB ~= lasttextAB
	    if rdsblockerror < 4 then  -- limit RDS data errors as we have no correction code
	        -- new data is 2 chars from block 3
	    	RDStextbuffer[idx+1] = bit.rshift(block3 , 8)
	    	idx=idx+1
	    	RDStextbuffer[idx+1] = bit.band(block3 , 0x00FF)
	    	idx=idx+1
	        -- new data is 2 chars from block 4
	    	RDStextbuffer[idx+1] = bit.rshift(block4 , 8)
	    	idx=idx+1
	    	RDStextbuffer[idx+1] = bit.band(block4 , 0x00FF)
	    	idx=idx+1
	    end -- if rdsblockerror < 4 
	    print("RDStextbuffer: "..bytetostring (RDStextbuffer))	    
	  elseif rdsGroupType==0x4A then
      print("Processing time and date")
      --Clock time and date
      if rdsblockerror <3 then -- limit RDS data errors as we have no correction code
	        offset = bit.band(block4, 0x3F) -- 6 bits
	        mins = bit.band(bit.rshift(block4, 6) , 0x3F) -- 6 bits
	        mins = mins+ 60 * bit.bor(bit.lshift(bit.band(block3 , 0x0001) , 4) , bit.band(bit.rshift(block4, 12) , 0x0F))
	      end
	    -- adjust offset
	    if  bit.band(offset , 0x20) then
	      mins =mins- 30 *  bit.band(offset , 0x1F)
	    else 
	      mins = mins + 30 *  bit.band(offset , 0x1F)
	    end

	    if mins>0 and mins<1500 then 
          print("h="..(mins/60))
          print("m="..(mins%60))
	    	--sprintf(CTtime, "CT %2d:%02d",(mins/60),(mins%60));  -- CT time formatted string
      end
	end
	]]--	
end

rawcode, reason=node.bootreason()
if reason==6 or reason==0 then --power on 
  M.RDA5807_Reset()
  M.RDA5807_BassBoost()
  M.RDA5807_Mute()
else
  M.RDA5807_Init()
end  
--M.RDA5807_Volume(1)

return M