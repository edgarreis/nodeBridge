
-- agreed, ';' is required only to deambigui-fy lua code. 
print("start configuration of access point:");
print("Heap:(bytes)"..node.heap());

cfg={};cfg.ssid="ESP8266_123";cfg.pwd="12345678";wifi.ap.config(cfg);

cfg={};cfg.ip="192.168.4.1";cfg.netmask="255.255.255.0";cfg.gateway="192.168.4.1";wifi.ap.setip(cfg);

wifi.setmode(wifi.SOFTAP);

collectgarbage();

print("Soft AP should have started...");
print("Heap:(bytes)"..node.heap());
print("MAC:"..wifi.ap.getmac().."\r\nIP:"..wifi.ap.getip());


-- uart.setup(id, baud, databits, parity, stopbits, echo)
-- id always zero, only one uart supported
-- baud one of 300, 600, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 74880, 115200, 230400, 460800, 921600, 1843200, 2686400
-- databits one of 5, 6, 7, 8
-- parity uart.PARITY_NONE, uart.PARITY_ODD, or uart.PARITY_EVEN
-- stopbits uart.STOPBITS_1, uart.STOPBITS_1_5, or uart.STOPBITS_2
-- echo if 0, disable echo, otherwise enable echo
uart.setup(0,9600,8,0,1,1);

tcpSocket = nil;
escape_sequence_started = 0;
temp_buff="";

-- net.createServer(type, timeout)
-- type net.TCP or net.UDP
-- timeout for a TCP server timeout is 1~28'800 seconds (for an inactive client to be disconnected)
tcpServer=net.createServer(net.TCP, 28800);



function escapeSequenceCheckingCallback()
	--print("escapeSequenceCheckingCallback")
	if escape_sequence_started==1 then
		if string.sub(temp_buff, 1, 3)=="***"	then 
			-- uart.on(method, [number/end_char], [function], [run_input])
			-- To unregister the callback, provide only the "data" parameter.
			uart.on("data");
			-- similarly for tcp->uart forwarder is also removed?
			-- tcpSocket:on("receive");
			temp_buff="";
			Interupt_sig=0; 
			print("back to lua");
		else
			--print("no escape sequence till timer expiry");
			-- no escape sequence till timer expiry. send the buffer out.
			tcpSocket:send(temp_buff);
			-- clear temp_buff:
			temp_buff="";
			-- release flag
			escape_sequence_started = 0;
		end
	end
end


function uartToTCPForwarder(data)

	if data=="*" then
		--print("star received")
		if escape_sequence_started==0 then
			escape_sequence_started = 1;
			tmr.unregister(1);
			if not tmr.alarm( 1,200,tmr.ALARM_SINGLE,escapeSequenceCheckingCallback ) then
				print("timer could not be started. whooops");
			else
				print("escapeSequenceCheckingCallback registered to tmr")
			end 
		end

		-- append the escape char anyway: (this is true for * or ** or *** or greater.)
		temp_buff=temp_buff..data;


	else
		-- release the flag if held previously.
		if escape_sequence_started==1 then
			--print("abort escape")
			escape_sequence_started = 0;
			-- stop timer, not required because of the clearing of above flag.
			-- if we are here, then it means atleast *ONE* * is lurking around in the temp_buff.
			-- append the current data received to temp_buff and send the whole shebang
			temp_buff=temp_buff..data;
			tcpSocket:send(temp_buff);
			-- clear temp_buff
			temp_buff="";

		else
			--print("normal case")
			-- this is the normal case. no escape sequence started, not an escape char now either.
			-- just send the data.
			tcpSocket:send(data);
		end

	end
end 

-- function(net.socket[, string]) callback function. 
-- The first parameter is the socket. If event is "receive", the second parameter is the received data as string.
function tcpToUARTForwarder(socket, payload)
	print(payload);
	--socket:send("<html><h1> Hello, NodeMCU!!! </h1></html>"); -- testing.
end


-- if the server is started successfully, then setup the call back functions for uart receive and tcp socket receive.
-- each of them forwards data to the other interface
function onSomeoneConnectedToPort80(socket)

	tcpSocket = socket
	Interupt_sig=0;
	temp_buff="";

	-- enable the uart to tcp socket forwarding:
	-- uart.on(method, [number/end_char], [function(data)], [run_input]) , only for "data" callback
	uart.on("data", 1, uartToTCPForwarder, 0);

	-- enable the tcp socket to uart forwarding:
	-- net.socket:on(event, function(net.socket[, string]) ) 
	tcpSocket:on("receive",tcpToUARTForwarder);

	-- print who connected
	for mac,ip in pairs(wifi.ap.getclient()) do
    	print(mac,ip)
	end

end



-- net.server.listen(port,[ip],function(net.socket))
-- callback function, pass to caller function as param if a connection is created successfully
tcpServer:listen(80, onSomeoneConnectedToPort80);

print("Heap:(bytes)"..node.heap());
print("uart <-> tcp bridge up.");