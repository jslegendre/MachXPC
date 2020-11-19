//
//  MachXPCListener.m
//  MachXPC
//
//  Created by Jeremy on 11/18/20.
//

#import "MachXPCListener.h"
#import <MachXPC/MachXPC-Internal.h>
#import <servers/bootstrap.h>

@interface MachXPCListener ()
@property (nonnull) dispatch_queue_t listenerQueue;
@property (nonnull) dispatch_source_t   dispatchSrc;
@end

@implementation MachXPCListener {
    mach_port_t _server_port;
    mach_port_t _endpoint_port;
}

kern_return_t _MSGetXPCListenerPort(mach_port_t server_port, mach_port_t *outPort) {
    return KERN_SUCCESS;
}

- (instancetype)initWithObject:(id<NSXPCListenerDelegate>)serviceInstance identifier:(NSString*)identifier {
    self = [super init];
    
    NSXPCListener *listener = [NSXPCListener anonymousListener];
    listener.delegate = serviceInstance;
    [listener resume];
    
    NSXPCListenerEndpoint *nsEndpoint = listener.endpoint;
    xpc_endpoint_t xpcEndpoint = [nsEndpoint _endpoint];
    // Offset 0x18 is where the mach_port_t is stored in what I imagine to be `struct xpc_endpoint`
    _endpoint_port = *(mach_port_t*)(((__bridge void*)xpcEndpoint) + 0x18);
    
    _listenerQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@/machXPC_host_q", identifier] UTF8String],
                                           DISPATCH_QUEUE_SERIAL);

    kern_return_t kr = bootstrap_check_in(bootstrap_port, identifier.UTF8String, &_server_port);
    if(kr != KERN_SUCCESS) {
        return NULL;
    }
    
    _dispatchSrc = dispatch_source_create(DISPATCH_SOURCE_TYPE_MACH_RECV, _server_port, 0, _listenerQueue);
    dispatch_source_set_event_handler(_dispatchSrc, ^{
        msg_format_response_r_t  recv_msg;
        mach_msg_header_t *recv_hdr;

        recv_hdr                   = &(recv_msg.header);
        recv_hdr->msgh_remote_port = self->_server_port;
        recv_hdr->msgh_local_port  = MACH_PORT_NULL;
        recv_hdr->msgh_size = sizeof(recv_msg);
        recv_msg.data.name = 0;
        kern_return_t kr = mach_msg(recv_hdr,
                                    MACH_RCV_MSG,
                                    0,
                                    recv_hdr->msgh_size,
                                    self->_server_port,
                                    MACH_MSG_TIMEOUT_NONE,
                                    MACH_PORT_NULL);

        msg_format_response_t  send_msg;
        mach_msg_header_t     *send_hdr;
        
        send_hdr = &(send_msg.header);
        send_hdr->msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND);
        send_hdr->msgh_bits |= MACH_MSGH_BITS_COMPLEX;
        send_hdr->msgh_size = sizeof(send_msg);
        send_hdr->msgh_local_port = MACH_PORT_NULL;
        send_hdr->msgh_remote_port = recv_hdr->msgh_remote_port;
        send_msg.body.msgh_descriptor_count = 2;
        send_msg.data.name = self->_endpoint_port;
        send_msg.data.disposition = (MACH_MSG_TYPE_COPY_SEND);
        send_msg.data.type = MACH_MSG_PORT_DESCRIPTOR;
        send_msg.ool.address = 0;
        send_msg.ool.size = 0;
        send_msg.ool.deallocate = false;
        send_msg.ool.copy = MACH_MSG_VIRTUAL_COPY;
        send_msg.ool.type = MACH_MSG_OOL_DESCRIPTOR;
        kr = mach_msg(send_hdr,
                      MACH_SEND_MSG,
                      send_hdr->msgh_size,
                      0,
                      MACH_PORT_NULL,
                      5000,
                      MACH_PORT_NULL);
        
        
    });
    
    return self;
}

- (void)suspend {
    dispatch_suspend(_dispatchSrc);
}

- (void)resume {
    dispatch_resume(_dispatchSrc);
}

- (void)dealloc {
    dispatch_source_cancel(_dispatchSrc);
    mach_port_deallocate(mach_task_self(), _server_port);
}

@end
