cimport cgbinder
from libc.stdlib cimport malloc, free

def ensure_binary(s):
    if isinstance(s, bytes):
        return s
    if isinstance(s, str):
        return s.encode()
    raise TypeError("not expecting type '%s'" % type(s))

cdef class Bridge:
    cdef cgbinder.GBinderBridge* _bridge

    def __cinit__(self, src_name, dest_name, ifaces_list, ServiceManager src, ServiceManager dest):
        cdef size_t l = len(ifaces_list)
        cdef const char** ifaces = <const char**>malloc((l + 1) * sizeof(const char*))
        for i in range(l):
            ifaces[i] = ifaces_list[i]
        ifaces[l] = NULL

        if dest_name is None:
            self._bridge = cgbinder.gbinder_bridge_new(ensure_binary(src_name), ifaces, src._sm, dest._sm)
        else:
            self._bridge = cgbinder.gbinder_bridge_new2(ensure_binary(src_name), ensure_binary(dest_name), ifaces, src._sm, dest._sm)

    def __dealloc__(self):
        if self._bridge is not NULL:
            cgbinder.gbinder_bridge_free(self._bridge)

cdef class RemoteObject:
    cdef cgbinder.GBinderRemoteObject* _object
    cdef public object notify_func

    cdef set_c_object(self, cgbinder.GBinderRemoteObject* remote):
        self._object = remote
        if self._object is not NULL:
            cgbinder.gbinder_remote_object_ref(self._object)

    def __dealloc__(self):
        if self._object is not NULL:
            cgbinder.gbinder_remote_object_unref(self._object)

    def ipc(self):
        if self._object is NULL:
            return None
        ipc = Ipc()
        ipc._ipc = cgbinder.gbinder_remote_object_ipc(self._object)
        return ipc

    def is_dead(self):
        if self._object is not NULL:
            return cgbinder.gbinder_remote_object_is_dead(self._object)
        else:
            return True

    def add_death_handler(self, notify_func):
        if self._object is not NULL:
            self.notify_func = notify_func
            return cgbinder.gbinder_remote_object_add_death_handler(self._object, remote_object_local_notify_func, <void*>self)

    def notify_func_callback(self):
        self.notify_func()

    def remove_handler(self, id):
        if self._object is not NULL:
            cgbinder.gbinder_remote_object_remove_handler(self._object, id)

cdef void remote_object_local_notify_func(cgbinder.GBinderRemoteObject* obj, void* user_data) noexcept with gil:
    (<object>user_data).notify_func_callback()

cdef class RemoteReply:
    cdef cgbinder.GBinderRemoteReply* _reply

    cdef set_c_reply(self, cgbinder.GBinderRemoteReply* reply):
        self._reply = reply
        if self._reply is not NULL:
            cgbinder.gbinder_remote_reply_ref(self._reply)

    def __dealloc__(self):
        if self._reply is not NULL:
            cgbinder.gbinder_remote_reply_unref(self._reply)

    def init_reader(self):
        if self._reply is NULL:
            return None
        reader = Reader()
        cgbinder.gbinder_remote_reply_init_reader(self._reply, &reader._reader)
        return reader

    def copy_to_local(self):
        if self._reply is NULL:
            return None
        reply = LocalReply()
        c_reply = cgbinder.gbinder_remote_reply_copy_to_local(self._reply)
        reply.set_c_reply(c_reply)
        return reply

    def read_int32(self):
        if self._reply is NULL:
            return None
        cdef signed int value
        cdef bint status
        status = cgbinder.gbinder_remote_reply_read_int32(self._reply, &value)
        return status, value

    def read_uint32(self):
        if self._reply is NULL:
            return None
        cdef unsigned int value
        cdef bint status
        status = cgbinder.gbinder_remote_reply_read_uint32(self._reply, &value)
        return status, value

    def read_int64(self):
        if self._reply is NULL:
            return None
        cdef signed long value
        cdef bint status
        status = cgbinder.gbinder_remote_reply_read_int64(self._reply, &value)
        return status, value

    def read_uint64(self):
        if self._reply is NULL:
            return None
        cdef unsigned long value
        cdef bint status
        status = cgbinder.gbinder_remote_reply_read_uint64(self._reply, &value)
        return status, value

    def read_string8(self):
        if self._reply is NULL:
            return None
        return cgbinder.gbinder_remote_reply_read_string8(self._reply).decode()

    def read_string16(self):
        if self._reply is NULL:
            return None
        return cgbinder.gbinder_remote_reply_read_string16(self._reply).decode()

    def read_object(self):
        if self._reply is NULL:
            return None
        cdef cgbinder.GBinderRemoteObject* c_object = cgbinder.gbinder_remote_reply_read_object(self._reply)
        cdef RemoteObject remote = None
        if c_object is not NULL:
            remote = RemoteObject()
            remote.set_c_object(c_object)

        return remote

cdef class Client:
    cdef cgbinder.GBinderClient* _client
    cdef public object reply_func, destroy_notif

    def __cinit__(self, RemoteObject object, ifaces_list):
        cdef size_t l = len(ifaces_list)
        cdef cgbinder.GBinderClientIfaceInfo* ifaces = <cgbinder.GBinderClientIfaceInfo*>malloc((l) * sizeof(cgbinder.GBinderClientIfaceInfo))
        if isinstance(ifaces_list, list):
            for i in range(l):
                iface = ensure_binary(ifaces_list[i][0])
                ifaces[i].iface = iface
                ifaces[i].last_code = ifaces_list[i][1]

            self._client = cgbinder.gbinder_client_new2(object._object, ifaces, l)
        else:
            free(ifaces)
            self._client = cgbinder.gbinder_client_new(object._object, ensure_binary(ifaces_list))

    def __dealloc__(self):
        if self._client is not NULL:
            cgbinder.gbinder_client_unref(self._client)

    def new_request(self, code = None):
        local = LocalRequest()
        if code is None:
            local._req = cgbinder.gbinder_client_new_request(self._client)
        else:
            local._req = cgbinder.gbinder_client_new_request2(self._client, code)

        return local

    def transact_sync_reply(self, unsigned int code, LocalRequest req):
        cdef int status
        reply = RemoteReply()
        reply._reply = cgbinder.gbinder_client_transact_sync_reply(self._client, code, req._req, &status)
        return reply, status

    def transact_sync_oneway(self, unsigned int code, LocalRequest req):
        return cgbinder.gbinder_client_transact_sync_oneway(self._client, code, req._req)

    def transact(self, unsigned int code, unsigned int flags, LocalRequest req, reply_func, destroy_notif):
        self.reply_func = reply_func
        self.destroy_notif = destroy_notif
        return cgbinder.gbinder_client_transact(self._client, code, flags, req._req, client_reply_func, local_destroy_notif, <void*>self)

    def reply_func_callback(self, reply, status):
        self.reply_func(reply, status)

    def destroy_notif_callback(self):
        self.destroy_notif()

    def cancel(self, unsigned long id):
        return cgbinder.gbinder_client_cancel(self._client, id)

cdef void client_reply_func(cgbinder.GBinderClient* client, cgbinder.GBinderRemoteReply* c_reply, int status, void* user_data) noexcept with gil:
    reply = RemoteReply()
    reply.set_c_reply(c_reply)
    (<object>user_data).reply_func_callback(reply, status)

cdef void local_destroy_notif(void* user_data) noexcept with gil:
    (<object>user_data).destroy_notif_callback()

cdef class LocalRequest:
    cdef cgbinder.GBinderLocalRequest* _req
    cdef public object destroy_notif

    cdef set_c_req(self, cgbinder.GBinderLocalRequest* req):
        self._req = req
        if self._req is not NULL:
            cgbinder.gbinder_local_request_ref(self._req)

    def __dealloc__(self):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_unref(self._req)

    def init_writer(self):
        if self._req is NULL:
            return None
        writer = Writer()
        cgbinder.gbinder_local_request_init_writer(self._req, &writer._writer)
        return writer

    def cleanup(self, destroy_notif):
        if self._req is not NULL:
            self.destroy_notif = destroy_notif
            cgbinder.gbinder_local_request_cleanup(self._req, local_destroy_notif, <void*>self)

    def destroy_notif_callback(self):
        self.destroy_notif()

    def append_bool(self, bint value):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_bool(self._req, value)

    def append_int32(self, unsigned int value):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_int32(self._req, value)

    def append_int64(self, unsigned long value):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_int64(self._req, value)
    
    def append_float(self, float value):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_float(self._req, value)
    
    def append_double(self, double value):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_double(self._req, value)

    def append_string8(self, value):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_string8(self._req, ensure_binary(value))

    def append_string16(self, value):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_string16(self._req, ensure_binary(value))

    def append_hidl_string(self, value):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_hidl_string(self._req, ensure_binary(value))

    def append_hidl_string_vec(self, values_list):
        cdef signed long count = len(values_list)
        cdef const char** strv = <const char**>malloc(count * sizeof(const char*))
        for i in range(count):
            value = ensure_binary(values_list[i])
            strv[i] = value

        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_hidl_string_vec(self._req, strv, count)
        else:
            free(strv)

    def append_local_object(self, LocalObject obj):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_local_object(self._req, obj._object)

    def append_remote_object(self, RemoteObject obj):
        if self._req is not NULL:
            cgbinder.gbinder_local_request_append_remote_object(self._req, obj._object)

cdef class Ipc:
    cdef cgbinder.GBinderIpc* _ipc

cdef class LocalReply:
    cdef cgbinder.GBinderLocalReply* _reply
    cdef public object destroy_notif

    cdef set_c_reply(self, cgbinder.GBinderLocalReply* reply):
        self._reply = reply
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_ref(self._reply)

    def __dealloc__(self):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_unref(self._reply)

    def init_writer(self):
        if self._reply is NULL:
            return None
        writer = Writer()
        cgbinder.gbinder_local_reply_init_writer(self._reply, &writer._writer)
        return writer

    def cleanup(self, destroy_notif):
        if self._reply is not NULL:
            self.destroy_notif = destroy_notif
            cgbinder.gbinder_local_reply_cleanup(self._reply, local_destroy_notif, <void*>self)

    def destroy_notif_callback(self):
        self.destroy_notif()

    def append_bool(self, bint value):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_bool(self._reply, value)

    def append_int32(self, unsigned int value):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_int32(self._reply, value)

    def append_int64(self, unsigned long value):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_int64(self._reply, value)
    
    def append_float(self, float value):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_float(self._reply, value)
    
    def append_double(self, double value):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_double(self._reply, value)

    def append_string8(self, value):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_string8(self._reply, ensure_binary(value))

    def append_string16(self, value):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_string16(self._reply, ensure_binary(value))

    def append_hidl_string(self, value):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_hidl_string(self._reply, ensure_binary(value))

    def append_hidl_string_vec(self, values_list):
        cdef signed long count = len(values_list)
        cdef const char** strv = <const char**>malloc(count * sizeof(const char*))
        for i in range(count):
            value = ensure_binary(values_list[i])
            strv[i] = value

        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_hidl_string_vec(self._reply, strv, count)
        else:
            free(strv)

    def append_local_object(self, LocalObject obj):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_local_object(self._reply, obj._object)

    def append_remote_object(self, RemoteObject obj):
        if self._reply is not NULL:
            cgbinder.gbinder_local_reply_append_remote_object(self._reply, obj._object)

cdef class RemoteRequest:
    cdef cgbinder.GBinderRemoteRequest* _req

    cdef set_c_req(self, cgbinder.GBinderRemoteRequest* req):
        self._req = req
        if self._req is not NULL:
            cgbinder.gbinder_remote_request_ref(self._req)

    def __dealloc__(self):
        if self._req is not NULL:
            cgbinder.gbinder_remote_request_unref(self._req)

    def init_reader(self):
        if self._req is NULL:
            return None
        reader = Reader()
        cgbinder.gbinder_remote_request_init_reader(self._req, &reader._reader)
        return reader

    def copy_to_local(self):
        if self._req is NULL:
            return None
        request = LocalRequest()
        request._req = cgbinder.gbinder_remote_request_copy_to_local(self._req)
        return request

    def interface(self):
        if self._req is NULL:
            return None
        return cgbinder.gbinder_remote_request_interface(self._req)

    def sender_pid(self):
        if self._req is NULL:
            return None
        return cgbinder.gbinder_remote_request_sender_pid(self._req)

    def sender_euid(self):
        if self._req is NULL:
            return None
        return cgbinder.gbinder_remote_request_sender_euid(self._req)

    def block(self):
        if self._req is not NULL:
            cgbinder.gbinder_remote_request_block(self._req)

    def complete(self, LocalReply reply, int status):
        if self._req is not NULL:
            cgbinder.gbinder_remote_request_complete(self._req, reply._reply, status)

    def read_int32(self):
        if self._req is NULL:
            return None
        cdef signed int value
        cdef bint status
        status = cgbinder.gbinder_remote_request_read_int32(self._req, &value)
        return status, value

    def read_uint32(self):
        if self._req is NULL:
            return None
        cdef unsigned int value
        cdef bint status
        status = cgbinder.gbinder_remote_request_read_uint32(self._req, &value)
        return status, value

    def read_int64(self):
        if self._req is NULL:
            return None
        cdef signed long value
        cdef bint status
        status = cgbinder.gbinder_remote_request_read_int64(self._req, &value)
        return status, value

    def read_uint64(self):
        if self._req is NULL:
            return None
        cdef unsigned long value
        cdef bint status
        status = cgbinder.gbinder_remote_request_read_uint64(self._req, &value)
        return status, value

    def read_string8(self):
        if self._req is NULL:
            return None
        return cgbinder.gbinder_remote_request_read_string8(self._req).decode()

    def read_string16(self):
        if self._req is NULL:
            return None
        return cgbinder.gbinder_remote_request_read_string16(self._req).decode()

    def read_object(self):
        if self._req is NULL:
            return None
        cdef cgbinder.GBinderRemoteObject* c_object = cgbinder.gbinder_remote_request_read_object(self._req)
        cdef RemoteObject remote = None
        if c_object is not NULL:
            remote = RemoteObject()
            remote.set_c_object(c_object)

        return remote

cdef class LocalObject:
    cdef cgbinder.GBinderLocalObject* _object
    cdef public object handler

    def __cinit__(self, Ipc ipc, ifaces_list = [], handler = None):
        cdef size_t l = len(ifaces_list)
        cdef const char** ifaces = <const char**>malloc((l + 1) * sizeof(const char*))
        if handler is not None:
            self.handler = handler
        if ipc is not None:
            for i in range(l):
                iface = ensure_binary(ifaces_list[i])
                ifaces[i] = iface
            ifaces[l] = NULL
            self._object = cgbinder.gbinder_local_object_new(ipc._ipc, ifaces, local_transact_callback, <void*>self)

    def __dealloc__(self):
        if self._object is not NULL:
            cgbinder.gbinder_local_object_unref(self._object)

    def callback(self, req, code, flags):
        return self.handler(req, code, flags)

    cdef set_c_object(self, cgbinder.GBinderLocalObject* object):
        self._object = object
        if self._object is not NULL:
            cgbinder.gbinder_local_object_ref(self._object)

    def drop(self):
        if self._object is not NULL:
            cgbinder.gbinder_local_object_drop(self._object)

    def new_reply(self):
        if self._object is not NULL:
            reply = LocalReply()
            c_reply = cgbinder.gbinder_local_object_new_reply(self._object)
            reply.set_c_reply(c_reply)
            return reply

cdef cgbinder.GBinderLocalReply* local_transact_callback(cgbinder.GBinderLocalObject* obj, cgbinder.GBinderRemoteRequest* c_req, unsigned int code, unsigned int flags, int* status, void* user_data) noexcept with gil:
    req = RemoteRequest()
    req.set_c_req(c_req)
    reply, status_ret = (<object>user_data).callback(req, code, flags)
    cdef int stat = status_ret
    status[0] = stat
    if reply is None or status_ret < 0:
        return NULL
    return (<LocalReply>reply)._reply

cdef class ServiceManager:
    cdef cgbinder.GBinderServiceManager* _sm
    cdef public object func, list_func, get_service_func

    def __cinit__(self, dev, sm_protocol=None, rpc_protocol=None):
        if sm_protocol and rpc_protocol:
            self._sm = cgbinder.gbinder_servicemanager_new2(ensure_binary(dev), ensure_binary(sm_protocol), ensure_binary(rpc_protocol))
        else:
            self._sm = cgbinder.gbinder_servicemanager_new(ensure_binary(dev))

    def __dealloc__(self):
        if self._sm is not NULL:
            cgbinder.gbinder_servicemanager_unref(self._sm)

    def new_local_object(self, ifaces_list, handler):
        if self._sm is NULL:
            return None

        local_object = LocalObject(None, [], handler)
        cdef size_t l = len(ifaces_list)
        cdef const char** ifaces = <const char**>malloc((l + 1) * sizeof(const char*))

        if isinstance(ifaces_list, list):
            for i in range(l):
                iface = ensure_binary(ifaces_list[i])
                ifaces[i] = iface
            ifaces[l] = NULL
            local_object._object = cgbinder.gbinder_servicemanager_new_local_object2(self._sm, ifaces, local_transact_callback, <void*>local_object)
        else:
            free(ifaces)
            local_object._object = cgbinder.gbinder_servicemanager_new_local_object(self._sm, ensure_binary(ifaces_list), local_transact_callback, <void*>local_object)

        return local_object

    def is_present(self):
        if self._sm is NULL:
            return False
        status = cgbinder.gbinder_servicemanager_is_present(self._sm)
        return status

    def wait(self, max_wait_ms):
        if self._sm is NULL:
            return None
        status = cgbinder.gbinder_servicemanager_wait(self._sm, max_wait_ms)
        return status

    def list(self, list_func):
        if self._sm is NULL:
            return None
        self.list_func = list_func
        status = cgbinder.gbinder_servicemanager_list(self._sm, service_manager_list_func, <void*>self)
        return status

    def list_func_callback(self, services_list):
        return self.list_func(services_list)

    def list_sync(self):
        if self._sm is NULL:
            return None
        cdef char** services = cgbinder.gbinder_servicemanager_list_sync(self._sm)
        services_list = []
        if services == NULL:
            return services_list

        i = 0
        while services[i] != NULL:
            services_list.append(services[i].decode())
            i += 1
        return services_list

    def get_service(self, name, get_service_func):
        if self._sm is NULL:
            return None
        self.get_service_func = get_service_func
        cdef int status = cgbinder.gbinder_servicemanager_get_service(self._sm, ensure_binary(name), service_manager_get_service_func, <void*>self)
        return status

    def get_service_func_callback(self, remote, status):
        self.get_service_func(remote, status)

    def get_service_sync(self, name):
        if self._sm is NULL:
            return None, None
        cdef int status
        cdef cgbinder.GBinderRemoteObject* c_object = cgbinder.gbinder_servicemanager_get_service_sync(self._sm, ensure_binary(name), &status)

        cdef RemoteObject remote = None
        if c_object is not NULL:
            remote = RemoteObject()
            remote.set_c_object(c_object)

        return remote, status

    def add_service(self, name, LocalObject obj, add_service_func):
        if self._sm is NULL:
            return None
        self.add_service_func = add_service_func
        cdef int status = cgbinder.gbinder_servicemanager_add_service(self._sm, ensure_binary(name), obj._object, service_manager_add_service_func, <void*>self)
        return status

    def add_service_func_callback(self, status):
        self.add_service_func(status)

    def add_service_sync(self, name, LocalObject obj):
        if self._sm is NULL:
            return None
        cdef int status = cgbinder.gbinder_servicemanager_add_service_sync(self._sm, ensure_binary(name), obj._object)
        return status

    def cancel(self, id):
        cgbinder.gbinder_servicemanager_cancel(self._sm, id)

    def add_presence_handler(self, func):
        if self._sm is NULL:
            return None
        self.func = func
        cdef unsigned long status = cgbinder.gbinder_servicemanager_add_presence_handler(self._sm, service_manager_func, <void*>self)
        return status

    def func_callback(self):
        self.func()

    def add_registration_handler(self, name, registration_func):
        if self._sm is NULL:
            return None
        self.registration_func = registration_func
        cdef unsigned long status = cgbinder.gbinder_servicemanager_add_registration_handler(self._sm, ensure_binary(name), service_manager_registration_func, <void*>self)
        return status

    def registration_func_callback(self, name):
        self.registration_func(ensure_binary(name))

    def remove_handler(self, id):
        if self._sm is not NULL:
            cgbinder.gbinder_servicemanager_remove_handler(self._sm, id)

    def remove_handlers(self, ids_list):
        cdef unsigned int count = len(ids_list)
        cdef unsigned long* ids = <unsigned long*>malloc((count) * sizeof(unsigned long))
        for i in range(count):
            ids[i] = ids_list[i]

        if self._sm is not NULL:
            cgbinder.gbinder_servicemanager_remove_handlers(self._sm, ids, count)
        else:
            free(ids)

cdef void service_manager_get_service_func(cgbinder.GBinderServiceManager* sm, cgbinder.GBinderRemoteObject* c_object, int status, void* user_data) noexcept with gil:
    remote = RemoteObject()
    remote.set_c_object(c_object)
    (<object>user_data).get_service_func_callback(remote, status)

cdef bint service_manager_list_func(cgbinder.GBinderServiceManager* sm, char** services, void* user_data) noexcept with gil:
    services_list = []
    if services == NULL:
        return services_list

    i = 0
    while services[i] != NULL:
        services_list.append(services[i].decode())
        i += 1
    return (<object>user_data).list_func_callback(services_list)

cdef void service_manager_add_service_func(cgbinder.GBinderServiceManager* sm, int status, void* user_data) noexcept with gil:
    (<object>user_data).add_service_func_callback(status)

cdef void service_manager_func(cgbinder.GBinderServiceManager* sm, void* user_data) noexcept with gil:
    (<object>user_data).func_callback()

cdef void service_manager_registration_func(cgbinder.GBinderServiceManager* sm, const char* name, void* user_data) noexcept with gil:
    (<object>user_data).registration_func_callback(name)

cdef class Buffer:
    cdef cgbinder.GBinderBuffer* _buffer

    cdef set_c_buffer(self, cgbinder.GBinderBuffer* buff):
        self._buffer = buff

    def __dealloc__(self):
        if self._buffer is not NULL:
            cgbinder.gbinder_buffer_free(self._buffer)

    def get_buffer_tuple(self):
        if self._buffer is not NULL:
            return <object>self._buffer.data, self._buffer.size

cdef class Writer:
    cdef cgbinder.GBinderWriter _writer
    cdef public object destroy_notif

    def append_int32(self, unsigned int value):
        cgbinder.gbinder_writer_append_int32(&self._writer, value)

    def append_int64(self, unsigned long value):
        cgbinder.gbinder_writer_append_int64(&self._writer, value)
    
    def append_float(self, float value):
        cgbinder.gbinder_writer_append_float(&self._writer, value)
    
    def append_double(self, double value):
        cgbinder.gbinder_writer_append_double(&self._writer, value)

    def append_string16(self, value):
        cgbinder.gbinder_writer_append_string16(&self._writer, ensure_binary(value))

    def append_string16_len(self, value, signed long num_bytes):
        cgbinder.gbinder_writer_append_string16_len(&self._writer, ensure_binary(value), num_bytes)

    def append_string8(self, value):
        cgbinder.gbinder_writer_append_string8(&self._writer, ensure_binary(value))

    def append_string8_len(self, value, unsigned long len):
        cgbinder.gbinder_writer_append_string8_len(&self._writer, ensure_binary(value), len)

    def append_bool(self, bint value):
        cgbinder.gbinder_writer_append_bool(&self._writer, value)

    def append_bytes(self, value, unsigned long size):
        cgbinder.gbinder_writer_append_bytes(&self._writer, <const void*>value, size)

    def append_fd(self, int fd):
        cgbinder.gbinder_writer_append_fd(&self._writer, fd)

    def bytes_written(self):
        return cgbinder.gbinder_writer_bytes_written(&self._writer)

    def overwrite_int32(self, unsigned long offset, signed int value):
        cgbinder.gbinder_writer_overwrite_int32(&self._writer, offset, value)

    def append_buffer_object_with_parent(self, buf, unsigned long len, parent_tuple):
        cdef cgbinder.GBinderParent* parent = NULL
        parent.index = parent_tuple[0]
        parent.offset = parent_tuple[1]
        return cgbinder.gbinder_writer_append_buffer_object_with_parent(&self._writer, <const void*>buf, len, parent)

    def gbinder_writer_append_buffer_object(self, buf, unsigned long len):
        return cgbinder.gbinder_writer_append_buffer_object(&self._writer, <const void*>buf, len)

    def append_hidl_vec(self, base, unsigned int count, unsigned int elemsize):
        cgbinder.gbinder_writer_append_hidl_vec(&self._writer, <const void*>base, count, elemsize)

    def append_hidl_string(self, value):
        cgbinder.gbinder_writer_append_hidl_string(&self._writer, ensure_binary(value))

    def append_hidl_string_vec(self, values_list):
        cdef signed long count = len(values_list)
        cdef const char** strv = <const char**>malloc(count * sizeof(const char*))
        for i in range(count):
            value = ensure_binary(values_list[i])
            strv[i] = value

        cgbinder.gbinder_writer_append_hidl_string_vec(&self._writer, strv, count)

    def append_local_object(self, LocalObject obj):
        cgbinder.gbinder_writer_append_local_object(&self._writer, obj._object)

    def append_remote_object(self, RemoteObject obj):
        cgbinder.gbinder_writer_append_remote_object(&self._writer, obj._object)

    def append_byte_array(self, byte_array, signed int len):
        cgbinder.gbinder_writer_append_byte_array(&self._writer, <const void*>byte_array, len)

    def malloc(self, byte_array, unsigned long size):
        cdef void* alloc_buf = cgbinder.gbinder_writer_malloc(&self._writer, size)
        return <object>alloc_buf

    def malloc0(self, byte_array, unsigned long size):
        cdef void* alloc_buf = cgbinder.gbinder_writer_malloc0(&self._writer, size)
        return <object>alloc_buf

    def memdup(self, buf, unsigned long size):
        cdef void* dup_buf = cgbinder.gbinder_writer_memdup(&self._writer, <const void*>buf, size)
        return <object>dup_buf

    def add_cleanup(self, destroy_notif):
        self.destroy_notif = destroy_notif
        cgbinder.gbinder_writer_add_cleanup(&self._writer, local_destroy_notif, <void*>self)

    def destroy_notif_callback(self):
        self.destroy_notif()

cdef class Reader:
    cdef cgbinder.GBinderReader _reader

    def at_end(self):
        cgbinder.gbinder_reader_at_end(&self._reader)

    def read_byte(self):
        cdef unsigned char value
        cdef bint status
        status = cgbinder.gbinder_reader_read_byte(&self._reader, &value)
        return status, value

    def read_bool(self):
        cdef bint value
        cdef bint status
        status = cgbinder.gbinder_reader_read_bool(&self._reader, &value)
        return status, value

    def read_int32(self):
        cdef signed int value
        cdef bint status
        status = cgbinder.gbinder_reader_read_int32(&self._reader, &value)
        return status, value

    def read_uint32(self):
        cdef unsigned int value
        cdef bint status
        status = cgbinder.gbinder_reader_read_uint32(&self._reader, &value)
        return status, value

    def read_int64(self):
        cdef signed long value
        cdef bint status
        status = cgbinder.gbinder_reader_read_int64(&self._reader, &value)
        return status, value

    def read_uint64(self):
        cdef unsigned long value
        cdef bint status
        status = cgbinder.gbinder_reader_read_uint64(&self._reader, &value)
        return status, value

    def read_float(self):
        cdef float value
        cdef bint status
        status = cgbinder.gbinder_reader_read_float(&self._reader, &value)
        return status, value

    def read_double(self):
        cdef double value
        cdef bint status
        status = cgbinder.gbinder_reader_read_double(&self._reader, &value)
        return status, value

    def read_fd(self):
        return cgbinder.gbinder_reader_read_fd(&self._reader)

    def read_dup_fd(self):
        return cgbinder.gbinder_reader_read_dup_fd(&self._reader)

    def read_nullable_object(self):
        cdef cgbinder.GBinderRemoteObject* obj
        cdef bint status
        status = cgbinder.gbinder_reader_read_nullable_object(&self._reader, &obj)
        remote = RemoteObject()
        remote.set_c_object(obj)
        return status, remote

    def read_object(self):
        cdef cgbinder.GBinderRemoteObject* obj = cgbinder.gbinder_reader_read_object(&self._reader)
        remote = RemoteObject()
        remote.set_c_object(obj)
        return remote

    def read_buffer(self):
        cdef cgbinder.GBinderBuffer* value = cgbinder.gbinder_reader_read_buffer(&self._reader)
        buff = Buffer()
        buff.set_c_buffer(value)
        return buff

    def read_hidl_struct1(self, unsigned long size):
        cdef const void* value = cgbinder.gbinder_reader_read_hidl_struct1(&self._reader, size)
        return <object>value

    def read_hidl_vec(self):
        cdef unsigned long count, elemsize
        cdef const void* value = cgbinder.gbinder_reader_read_hidl_vec(&self._reader, &count, &elemsize)
        return <object>value, count, elemsize

    def read_hidl_vec1(self, unsigned int expected_elemsize):
        cdef unsigned long count
        cdef const void* value = cgbinder.gbinder_reader_read_hidl_vec1(&self._reader, &count, expected_elemsize)
        return <object>value, count

    def read_hidl_string(self):
        return cgbinder.gbinder_reader_read_hidl_string_c(&self._reader).decode()

    def read_hidl_string_vec(self):
        cdef char** value = cgbinder.gbinder_reader_read_hidl_string_vec(&self._reader)
        string_list = []
        i = 0

        while value[i] != NULL:
            string_list.append(value[i].decode())
            i += 1
        return string_list

    def skip_buffer(self):
        return cgbinder.gbinder_reader_skip_buffer(&self._reader)

    def read_string8(self):
        return cgbinder.gbinder_reader_read_string8(&self._reader).decode()

    def read_string16(self):
        return cgbinder.gbinder_reader_read_string16(&self._reader).decode()

    def nullable_string16(self):
        cdef char* value
        cdef bint status
        status = cgbinder.gbinder_reader_read_nullable_string16(&self._reader, &value)
        return status, value.decode()

    def skip_string16(self):
        return cgbinder.gbinder_reader_skip_string16(&self._reader)

    def read_byte_array(self):
        cdef unsigned long len
        cdef const void* value = cgbinder.gbinder_reader_read_byte_array(&self._reader, &len)
        return <object>value, len

    def bytes_read(self):
        return cgbinder.gbinder_reader_bytes_read(&self._reader)

    def bytes_remaining(self):
        return cgbinder.gbinder_reader_bytes_remaining(&self._reader)
