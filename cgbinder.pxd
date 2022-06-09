cdef extern from "gbinder/gbinder_types.h":
    ctypedef struct GBinderBridge:
        pass

    ctypedef struct GBinderClient:
        pass

    ctypedef struct GBinderIpc:
        pass

    ctypedef struct GBinderLocalObject:
        pass

    ctypedef struct GBinderLocalReply:
        pass

    ctypedef struct GBinderLocalRequest:
        pass

    ctypedef struct GBinderReader:
        pass
    
    ctypedef struct GBinderRemoteObject:
        pass

    ctypedef struct GBinderRemoteReply:
        pass

    ctypedef struct GBinderRemoteRequest:
        pass

    ctypedef struct GBinderServiceName:
        pass

    ctypedef struct GBinderServiceManager:
        pass

    ctypedef struct GBinderWriter:
        pass

    ctypedef GBinderLocalReply* (*GBinderLocalTransactFunc)(GBinderLocalObject* obj, GBinderRemoteRequest* req, unsigned int code, unsigned int flags, int* status, void* user_data)

cdef extern from "gbinder/gbinder_servicemanager.h":
    ctypedef void (*GBinderServiceManagerFunc)(GBinderServiceManager* sm, void* user_data)
    ctypedef bint (*GBinderServiceManagerListFunc)(GBinderServiceManager* sm, char** services, void* user_data)
    ctypedef void (*GBinderServiceManagerGetServiceFunc)(GBinderServiceManager* sm, GBinderRemoteObject* obj, int status, void* user_data)
    ctypedef void (*GBinderServiceManagerAddServiceFunc)(GBinderServiceManager* sm, int status, void* user_data)
    ctypedef void (*GBinderServiceManagerRegistrationFunc)(GBinderServiceManager* sm, const char* name, void* user_data)

    GBinderServiceManager* gbinder_servicemanager_new2(const char* dev, const char* sm_protocol, const char* rpc_protocol)
    GBinderServiceManager* gbinder_servicemanager_new(const char* dev)
    GBinderLocalObject* gbinder_servicemanager_new_local_object(GBinderServiceManager* sm, const char* iface, GBinderLocalTransactFunc handler, void* user_data)
    GBinderLocalObject* gbinder_servicemanager_new_local_object2(GBinderServiceManager* sm, const char* const* ifaces, GBinderLocalTransactFunc handler, void* user_data)

    GBinderServiceManager* gbinder_servicemanager_ref(GBinderServiceManager* sm)
    void gbinder_servicemanager_unref(GBinderServiceManager* sm)

    bint gbinder_servicemanager_is_present(GBinderServiceManager* sm)
    bint gbinder_servicemanager_wait(GBinderServiceManager* sm, long max_wait_ms)
    unsigned long gbinder_servicemanager_list(GBinderServiceManager* sm, GBinderServiceManagerListFunc func, void* user_data)
    char** gbinder_servicemanager_list_sync(GBinderServiceManager* sm)
    unsigned long gbinder_servicemanager_get_service(GBinderServiceManager* sm, const char* name, GBinderServiceManagerGetServiceFunc func, void* user_data)
    GBinderRemoteObject* gbinder_servicemanager_get_service_sync(GBinderServiceManager* sm, const char* name, int* status)

    unsigned long gbinder_servicemanager_add_service(GBinderServiceManager* sm, const char* name, GBinderLocalObject* obj, GBinderServiceManagerAddServiceFunc func, void* user_data)
    int gbinder_servicemanager_add_service_sync(GBinderServiceManager* sm, const char* name, GBinderLocalObject* obj)
    void gbinder_servicemanager_cancel(GBinderServiceManager* sm, unsigned long id)
    unsigned long gbinder_servicemanager_add_presence_handler(GBinderServiceManager* sm, GBinderServiceManagerFunc func, void* user_data)
    unsigned long gbinder_servicemanager_add_registration_handler(GBinderServiceManager* sm, const char* name, GBinderServiceManagerRegistrationFunc func, void* user_data)

    void gbinder_servicemanager_remove_handler(GBinderServiceManager* sm, unsigned long id)
    void gbinder_servicemanager_remove_handlers(GBinderServiceManager* sm, unsigned long* ids, unsigned int count)

cdef extern from "gbinder/gbinder_buffer.h":
    ctypedef struct GBinderBuffer:
        void* data
        unsigned long size

    void gbinder_buffer_free(GBinderBuffer* buf)

cdef extern from "gbinder/gbinder_bridge.h":
    GBinderBridge* gbinder_bridge_new(const char* name, const char* const* ifaces, GBinderServiceManager* src, GBinderServiceManager* dest)
    GBinderBridge* gbinder_bridge_new2(const char* src_name, const char* dest_name, const char* const* ifaces, GBinderServiceManager* src, GBinderServiceManager* dest)

    void gbinder_bridge_free(GBinderBridge* bridge)

cdef extern from "gbinder/gbinder_client.h":
    ctypedef struct GBinderClientIfaceInfo:
        const char* iface
        unsigned int last_code

    ctypedef void (*GBinderClientReplyFunc)(GBinderClient* client, GBinderRemoteReply* reply, int status, void* user_data)
    ctypedef void (*GDestroyNotify)(void* data)

    GBinderClient* gbinder_client_new(GBinderRemoteObject* object, const char* iface)
    GBinderClient* gbinder_client_new2(GBinderRemoteObject* object, const GBinderClientIfaceInfo* ifaces, unsigned long count)
    GBinderClient* gbinder_client_ref(GBinderClient* client)
    void gbinder_client_unref(GBinderClient* client)

    const char* gbinder_client_interface(GBinderClient* client)
    const char* gbinder_client_interface2(GBinderClient* client, unsigned int code)

    GBinderLocalRequest* gbinder_client_new_request(GBinderClient* client)
    GBinderLocalRequest* gbinder_client_new_request2(GBinderClient* client, unsigned int code)

    GBinderRemoteReply* gbinder_client_transact_sync_reply(GBinderClient* client, unsigned int code, GBinderLocalRequest* req, int* status)
    int gbinder_client_transact_sync_oneway(GBinderClient* client, unsigned int code, GBinderLocalRequest* req)
    unsigned long gbinder_client_transact(GBinderClient* client, unsigned int code, unsigned int flags, GBinderLocalRequest* req, GBinderClientReplyFunc reply, GDestroyNotify destroy, void* user_data)

    void gbinder_client_cancel(GBinderClient* client, unsigned long id)

cdef extern from "gbinder/gbinder_local_object.h":
    GBinderLocalObject* gbinder_local_object_new(GBinderIpc* ipc, const char* const* ifaces, GBinderLocalTransactFunc handler, void* user_data)

    GBinderLocalObject* gbinder_local_object_ref(GBinderLocalObject* obj)
    void gbinder_local_object_unref(GBinderLocalObject* obj)

    void gbinder_local_object_drop(GBinderLocalObject* obj)
    GBinderLocalReply* gbinder_local_object_new_reply(GBinderLocalObject* obj)

cdef extern from "gbinder/gbinder_local_reply.h":
    GBinderLocalReply* gbinder_local_reply_ref(GBinderLocalReply* reply)
    void gbinder_local_reply_unref(GBinderLocalReply* reply)

    void gbinder_local_reply_init_writer(GBinderLocalReply* reply, GBinderWriter* writer)
    void gbinder_local_reply_cleanup(GBinderLocalReply* reply, GDestroyNotify destroy, void* pointer)

    GBinderLocalReply* gbinder_local_reply_append_bool(GBinderLocalReply* reply, bint value)
    GBinderLocalReply* gbinder_local_reply_append_int32(GBinderLocalReply* reply, unsigned int value)
    GBinderLocalReply* gbinder_local_reply_append_int64(GBinderLocalReply* reply, unsigned long value)
    GBinderLocalReply* gbinder_local_reply_append_float(GBinderLocalReply* reply, float value)
    GBinderLocalReply* gbinder_local_reply_append_double(GBinderLocalReply* reply, double value)
    GBinderLocalReply* gbinder_local_reply_append_string8(GBinderLocalReply* reply, const char* str)
    GBinderLocalReply* gbinder_local_reply_append_string16(GBinderLocalReply* reply, const char* utf8)
    GBinderLocalReply* gbinder_local_reply_append_hidl_string(GBinderLocalReply* reply, const char* str)
    GBinderLocalReply* gbinder_local_reply_append_hidl_string_vec(GBinderLocalReply* reply, const char* strv[], signed long count)
    GBinderLocalReply* gbinder_local_reply_append_local_object(GBinderLocalReply* reply, GBinderLocalObject* obj)
    GBinderLocalReply* gbinder_local_reply_append_remote_object(GBinderLocalReply* reply, GBinderRemoteObject* obj)

cdef extern from "gbinder/gbinder_local_request.h":
    GBinderLocalRequest* gbinder_local_request_ref(GBinderLocalRequest* request)
    void gbinder_local_request_unref(GBinderLocalRequest* request)

    void gbinder_local_request_init_writer(GBinderLocalRequest* request, GBinderWriter* writer)
    void gbinder_local_request_cleanup(GBinderLocalRequest* request, GDestroyNotify destroy, void* pointer)

    GBinderLocalRequest* gbinder_local_request_append_bool(GBinderLocalRequest* request, bint value)
    GBinderLocalRequest* gbinder_local_request_append_int32(GBinderLocalRequest* request, unsigned int value)
    GBinderLocalRequest* gbinder_local_request_append_int64(GBinderLocalRequest* request, unsigned long value)
    GBinderLocalRequest* gbinder_local_request_append_float(GBinderLocalRequest* request, float value)
    GBinderLocalRequest* gbinder_local_request_append_double(GBinderLocalRequest* request, double value)
    GBinderLocalRequest* gbinder_local_request_append_string8(GBinderLocalRequest* request, const char* str)
    GBinderLocalRequest* gbinder_local_request_append_string16(GBinderLocalRequest* request, const char* utf8)
    GBinderLocalRequest* gbinder_local_request_append_hidl_string(GBinderLocalRequest* request, const char* str)
    GBinderLocalRequest* gbinder_local_request_append_hidl_string_vec(GBinderLocalRequest* request, const char* strv[], signed long count)
    GBinderLocalRequest* gbinder_local_request_append_local_object(GBinderLocalRequest* request, GBinderLocalObject* obj)
    GBinderLocalRequest* gbinder_local_request_append_remote_object(GBinderLocalRequest* request, GBinderRemoteObject* obj)

cdef extern from "gbinder/gbinder_reader.h":
    bint gbinder_reader_at_end(const GBinderReader* reader)
    bint gbinder_reader_read_byte(GBinderReader* reader, unsigned char* value)
    bint gbinder_reader_read_bool(GBinderReader* reader, bint* value)
    bint gbinder_reader_read_int32(GBinderReader* reader, signed int* value)
    bint gbinder_reader_read_uint32(GBinderReader* reader, unsigned int* value)
    bint gbinder_reader_read_int64(GBinderReader* reader, signed long* value)
    bint gbinder_reader_read_uint64(GBinderReader* reader, unsigned long* value)
    bint gbinder_reader_read_float(GBinderReader* reader, float* value)
    bint gbinder_reader_read_double(GBinderReader* reader, double* value)
    int gbinder_reader_read_fd(GBinderReader* reader)
    int gbinder_reader_read_dup_fd(GBinderReader* reader)
    bint gbinder_reader_read_nullable_object(GBinderReader* reader, GBinderRemoteObject** obj)

    GBinderRemoteObject* gbinder_reader_read_object(GBinderReader* reader)
    GBinderBuffer* gbinder_reader_read_buffer(GBinderReader* reader)

    const void* gbinder_reader_read_hidl_struct1(GBinderReader* reader, unsigned long size)
    const void* gbinder_reader_read_hidl_vec(GBinderReader* reader, unsigned long* count, unsigned long* elemsize)
    const void* gbinder_reader_read_hidl_vec1(GBinderReader* reader, unsigned long* count, unsigned int expected_elemsize)
    char* gbinder_reader_read_hidl_string(GBinderReader* reader)
    const char* gbinder_reader_read_hidl_string_c(GBinderReader* reader)
    char** gbinder_reader_read_hidl_string_vec(GBinderReader* reader)

    bint gbinder_reader_skip_buffer(GBinderReader* reader)

    const char* gbinder_reader_read_string8(GBinderReader* reader)
    char* gbinder_reader_read_string16(GBinderReader* reader)
    bint gbinder_reader_read_nullable_string16(GBinderReader* reader, char** out)
    #bint gbinder_reader_read_nullable_string16_utf16(GBinderReader* reader, const unsigned short** out, unsigned long* len)
    #const unsigned short* gbinder_reader_read_string16_utf16(GBinderReader* reader,unsigned long* len)
    bint gbinder_reader_skip_string16(GBinderReader* reader)
    const void* gbinder_reader_read_byte_array(GBinderReader* reader, unsigned long* len)
    unsigned long gbinder_reader_bytes_read(const GBinderReader* reader)
    unsigned long gbinder_reader_bytes_remaining(const GBinderReader* reader)
    #void gbinder_reader_copy(GBinderReader* dest, const GBinderReader* src)

cdef extern from "gbinder/gbinder_remote_object.h":
    ctypedef void (*GBinderRemoteObjectNotifyFunc)(GBinderRemoteObject* obj, void* user_data)

    GBinderRemoteObject* gbinder_remote_object_ref(GBinderRemoteObject* obj)
    void gbinder_remote_object_unref(GBinderRemoteObject* obj)

    GBinderIpc* gbinder_remote_object_ipc(GBinderRemoteObject* obj)
    bint gbinder_remote_object_is_dead(GBinderRemoteObject* obj)
    unsigned long gbinder_remote_object_add_death_handler(GBinderRemoteObject* obj, GBinderRemoteObjectNotifyFunc func, void* user_data)
    void gbinder_remote_object_remove_handler(GBinderRemoteObject* obj, unsigned long id)

cdef extern from "gbinder/gbinder_remote_reply.h":
    GBinderRemoteReply* gbinder_remote_reply_ref(GBinderRemoteReply* reply)
    void gbinder_remote_reply_unref(GBinderRemoteReply* reply)
    void gbinder_remote_reply_init_reader(GBinderRemoteReply* reply, GBinderReader* reader)
    GBinderLocalReply* gbinder_remote_reply_copy_to_local(GBinderRemoteReply* reply)

    bint gbinder_remote_reply_read_int32(GBinderRemoteReply* reply, signed int* value)
    bint gbinder_remote_reply_read_uint32(GBinderRemoteReply* reply, unsigned int* value)
    bint gbinder_remote_reply_read_int64(GBinderRemoteReply* reply, signed long* value)
    bint gbinder_remote_reply_read_uint64(GBinderRemoteReply* reply, unsigned long* value)
    const char* gbinder_remote_reply_read_string8(GBinderRemoteReply* reply)
    char* gbinder_remote_reply_read_string16(GBinderRemoteReply* reply)
    GBinderRemoteObject* gbinder_remote_reply_read_object(GBinderRemoteReply* reply)

cdef extern from "gbinder/gbinder_remote_request.h":
    GBinderRemoteRequest* gbinder_remote_request_ref(GBinderRemoteRequest* req)
    void gbinder_remote_request_unref(GBinderRemoteRequest* req)
    void gbinder_remote_request_init_reader(GBinderRemoteRequest* req, GBinderReader* reader)
    GBinderLocalRequest* gbinder_remote_request_copy_to_local(GBinderRemoteRequest* req)

    const char* gbinder_remote_request_interface(GBinderRemoteRequest* req)
    int gbinder_remote_request_sender_pid(GBinderRemoteRequest* req)
    short gbinder_remote_request_sender_euid(GBinderRemoteRequest* req)
    void gbinder_remote_request_block(GBinderRemoteRequest* req)
    void gbinder_remote_request_complete(GBinderRemoteRequest* req, GBinderLocalReply* reply, int status)

    bint gbinder_remote_request_read_int32(GBinderRemoteRequest* req, signed int* value)
    bint gbinder_remote_request_read_uint32(GBinderRemoteRequest* req, unsigned int* value)
    bint gbinder_remote_request_read_int64(GBinderRemoteRequest* req, signed long* value)
    bint gbinder_remote_request_read_uint64(GBinderRemoteRequest* req, unsigned long* value)
    const char* gbinder_remote_request_read_string8(GBinderRemoteRequest* req)
    char* gbinder_remote_request_read_string16(GBinderRemoteRequest* req)
    GBinderRemoteObject* gbinder_remote_request_read_object(GBinderRemoteRequest* self)

cdef extern from "gbinder/gbinder_writer.h":
    ctypedef struct GBinderParent:
        unsigned int index
        unsigned int offset

    void gbinder_writer_append_int32(GBinderWriter* writer, unsigned int value)
    void gbinder_writer_append_int64(GBinderWriter* writer, unsigned long value)
    void gbinder_writer_append_float(GBinderWriter* writer, float value)
    void gbinder_writer_append_double(GBinderWriter* writer, double value)
    void gbinder_writer_append_string16(GBinderWriter* writer, const char* utf8)
    void gbinder_writer_append_string16_len(GBinderWriter* writer, const char* utf8, signed long num_bytes)
    #void gbinder_writer_append_string16_utf16(GBinderWriter* writer, const unsigned short* utf16, signed long length)
    void gbinder_writer_append_string8(GBinderWriter* writer, const char* str)
    void gbinder_writer_append_string8_len(GBinderWriter* writer, const char* str, unsigned long len)
    void gbinder_writer_append_bool(GBinderWriter* writer, bint value)
    void gbinder_writer_append_bytes(GBinderWriter* writer, const void* data, unsigned long size)
    void gbinder_writer_append_fd(GBinderWriter* writer, int fd)

    unsigned long gbinder_writer_bytes_written(GBinderWriter* writer)

    void gbinder_writer_overwrite_int32(GBinderWriter* writer, unsigned long offset, signed int value)

    unsigned int gbinder_writer_append_buffer_object_with_parent(GBinderWriter* writer, const void* buf, unsigned long len, const GBinderParent* parent)
    unsigned int gbinder_writer_append_buffer_object(GBinderWriter* writer, const void* buf, unsigned long len)

    void gbinder_writer_append_hidl_vec(GBinderWriter* writer, const void* base, unsigned int count, unsigned int elemsize)
    void gbinder_writer_append_hidl_string(GBinderWriter* writer, const char* str)
    void gbinder_writer_append_hidl_string_vec(GBinderWriter* writer, const char* data[], signed long count)
    void gbinder_writer_append_local_object(GBinderWriter* writer, GBinderLocalObject* obj)
    void gbinder_writer_append_remote_object(GBinderWriter* writer, GBinderRemoteObject* obj)
    void gbinder_writer_append_byte_array(GBinderWriter* writer, const void* byte_array, signed int len)

    void* gbinder_writer_malloc(GBinderWriter* writer, unsigned long size)
    void* gbinder_writer_malloc0(GBinderWriter* writer, unsigned long size)
    void* gbinder_writer_memdup(GBinderWriter* writer, const void* buf, unsigned long size)
    void gbinder_writer_add_cleanup(GBinderWriter* writer, GDestroyNotify destroy, void* data)
