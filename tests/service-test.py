import gbinder
from gi.repository import GLib

service_manager = gbinder.ServiceManager("/dev/binder")
iface = "test@1.0"
fqname = "test"
Command = 1

def got_reply(req, code, flags):
    reader = req.init_reader()
    if code == Command:
        val = reader.read_string16()
        print ("Got: ", val)

    lr = response.new_reply()
    lr.append_string16(val)
    return lr, 0

response = service_manager.new_local_object(iface, got_reply)
status = service_manager.add_service_sync(fqname, response)

if not status:
    loop = GLib.MainLoop()
    loop.run()
else:
    print("Failed to add service " + fqname)
