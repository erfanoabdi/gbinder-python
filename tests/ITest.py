import gbinder
import logging
import time
from gi.repository import GLib


BINDER_DRIVER = "/dev/binder"
INTERFACE = "gbinder.ITest"
SERVICE_NAME = "gbinder_test"

TRANSACTION_sendTest = 1

serviceManager = gbinder.ServiceManager(BINDER_DRIVER)

class ITest:
    def __init__(self, remote):
        self.client = gbinder.Client(remote, INTERFACE)

    def sendTest(self, arg1):
        request = self.client.new_request()
        request.append_string16(arg1)
        reply, status = self.client.transact_sync_reply(
            TRANSACTION_sendTest, request)

        if status:
            logging.error("Sending reply failed")
        else:
            reader = reply.init_reader()
            rep1 = reader.read_string16()
            return rep1

        return None


def add_service(sendTest):
    def response_handler(req, code, flags):
        logging.debug("Received transaction: ", code)
        reader = req.init_reader()
        local_response = response.new_reply()
        if code == TRANSACTION_sendTest:
            arg1 = reader.read_string16()
            ret1 = sendTest(arg1)
            local_response.append_string16(ret1)

        return local_response, 0

    def binder_presence():
        if serviceManager.is_present():
            status = serviceManager.add_service_sync(SERVICE_NAME, response)

            if status:
                logging.error("Failed to add service " + SERVICE_NAME)
                loop.quit()

    response = serviceManager.new_local_object(INTERFACE, response_handler)
    loop = GLib.MainLoop()
    binder_presence()
    status = serviceManager.add_presence_handler(binder_presence)
    if status:
        loop.run()
    else:
        logging.error("Failed to add presence handler: {}".format(status))


def get_service():
    tries = 1000

    remote, status = serviceManager.get_service_sync(SERVICE_NAME)
    while(not remote):
        if tries > 0:
            logging.warning(
                "Failed to get service {}, trying again...".format(SERVICE_NAME))
            time.sleep(1)
            remote, status = serviceManager.get_service_sync(SERVICE_NAME)
            tries = tries - 1
        else:
            return None

    return ITest(remote)
