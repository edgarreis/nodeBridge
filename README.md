# nodeBridge
yet another transparent (uart&lt;->tcp) bridge for esp8266 running the nodemcu FW. written in lua.

simple_vX.Y.lua : the simple scripts are for AP mode, serial <-> TCP transparent bridge. "***" on the serial interface brings back the lua console, so anyone connected to the serial port can rewrite/modify the lua script on the esp8266. this is the escape sequence, similar to the convention in escaping from transparent bridge mode to "AT" command mode in many commercial modules.

work in progress:
- station mode transparent bridge.
- sta and ap mode transparent bridge.
