//
//  MachXPCConnection.m
//  MachXPC
//
//  Created by Jeremy on 11/18/20.
//

#import "MachXPCConnection.h"
#import <MachXPC/MachXPC-Internal.h>
#import <servers/bootstrap.h>
#import <MachXPC/SymRez/SymRez.h>

extern xpc_endpoint_t (*_xpc_endpoint_create)(mach_port_t);

@interface MachXPCConnection ()
@property (strong) NSXPCConnection *connection;
@property (retain) NSString *listenerIdentifier;
@end

@implementation MachXPCConnection

- (instancetype)initWithListenerIdentifier:(NSString *)identifier {
    self = [super init];
    _listenerIdentifier = identifier;
    
    return self;
}

+ (void)connectionFromMachXPCListener:(NSString *)identifier handler:(void(^)(NSXPCConnection *connection))handler {
    
    mach_port_t server_port = MACH_PORT_NULL;
    mach_port_t client_port = MACH_PORT_NULL;
    
    kern_return_t kr = bootstrap_look_up(bootstrap_port, identifier.UTF8String, &server_port);
    if(kr != KERN_SUCCESS) {
        handler(NULL);
        return;
    }
    
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &client_port);
    if(kr != KERN_SUCCESS) {
        handler(NULL);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(0,0), ^{
        mach_msg_header_t header;
        header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND);
        header.msgh_local_port = client_port;
        header.msgh_remote_port = server_port;
        header.msgh_size = sizeof(mach_msg_header_t);
        header.msgh_id = 888;
        mach_msg(&header,
                 MACH_SEND_MSG,
                 header.msgh_size,
                 0, MACH_PORT_NULL,
                 MACH_MSG_TIMEOUT_NONE,
                 MACH_PORT_NULL);
        
        msg_format_response_r_t  recv_msg;
        mach_msg_header_t *recv_hdr;

        recv_hdr                   = &(recv_msg.header);
        recv_hdr->msgh_remote_port = server_port;
        recv_hdr->msgh_local_port  = MACH_PORT_NULL;
        recv_hdr->msgh_size = sizeof(recv_msg);
        recv_msg.data.name = 0;
        kern_return_t kr = mach_msg(recv_hdr,
                                    MACH_RCV_MSG,
                                    0,
                                    recv_hdr->msgh_size,
                                    client_port,
                                    5000,
                                    MACH_PORT_NULL);
        
        if(kr != KERN_SUCCESS) {
            handler(NULL);
            return;
        }
        
        mach_port_t endpoint_port = recv_msg.data.name;
        xpc_endpoint_t xpcEndpoint = _xpc_endpoint_create(endpoint_port);
        NSXPCListenerEndpoint *listener = [[NSXPCListenerEndpoint alloc] init];
        [listener _setEndpoint:xpcEndpoint];
        handler([[NSXPCConnection alloc] initWithListenerEndpoint:listener]);
    });
}

@end
