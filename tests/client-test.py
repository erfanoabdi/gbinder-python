import gbinder

service_manager = gbinder.ServiceManager("/dev/binder")
iface = "test@1.0"
fqname = "test"
code = 1

remote, status = service_manager.get_service_sync(fqname)

if remote:
    print("Connected to " + fqname)
    client = gbinder.Client(remote, iface)

    while True:
        request = client.new_request()
        value = input("Say something: ")
        request.append_string16(value)

        reply, status = client.transact_sync_reply(code, request)
        if status:
            print("Sending string failed")
        else:
            reader = reply.init_reader()
            reply_value = reader.read_string16()
            print("Reply: ", reply_value)
else:
    print("Failed to Connected to " + fqname)
