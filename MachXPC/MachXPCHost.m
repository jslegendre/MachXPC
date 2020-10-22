//
//  MachXPCHost.m
//  MachXPC
//
//  Created by Jeremy on 10/15/20.
//

#import <MachXPC/MachXPC.h>
#import <MachXPC/MachXPC-Internal.h>
#import <MachXPC/MachXPCHost.h>
#import <MachXPC/SymRez/SymRez.h>
#include <servers/bootstrap.h>

xpc_endpoint_t (*_xpc_endpoint_create)(mach_port_t);

@interface NSXPCListenerEndpoint (Private)
-(void)_setEndpoint:(xpc_endpoint_t)xpcEndpoint;
-(xpc_endpoint_t)_endpoint;
@end;

@interface MachXPCHost ()
@property (nonatomic, copy, nonnull) void (^handler)(NSString *serviceIdentifier, NSXPCListenerEndpoint *);
@property (nonnull) dispatch_queue_t listenerQueue;
@property (nonnull) dispatch_source_t   dispatchSrc;
@end

@implementation MachXPCHost {
    mach_port_t         _server_port;
}

- (void)_setupEndpointWithPort:(mach_port_t)port forService:(NSString *)service {
    if(port == -1 || port == 0) {
        _handler(nil, nil);
        return;
    }
    
    xpc_endpoint_t xpcEndpoint = _xpc_endpoint_create(port);
    NSXPCListenerEndpoint *listener = [[NSXPCListenerEndpoint alloc] init];
    [listener _setEndpoint:xpcEndpoint];
    
    _handler(service, listener);
}

- (instancetype)initWithName:(NSString *)name connectionHandler:(void(^)(NSString *serviceIdentifier, NSXPCListenerEndpoint *listener))handler {
    self = [super init];
    _name = name;
    _handler = handler;
    _listenerQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@/machXPC_host_q", name] UTF8String],
                                           DISPATCH_QUEUE_SERIAL);

    kern_return_t kr = bootstrap_check_in(bootstrap_port, name.UTF8String, &_server_port);
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

        if(kr != KERN_SUCCESS) {
            NSLog(@"MachXPC: Host could not receive service port");
            return;
        }
        
        char *serviceName = (char*)(void*)recv_msg.ool.address;
        [self _setupEndpointWithPort:recv_msg.data.name forService:[NSString stringWithUTF8String:serviceName]];
    });
    
    return self;
}

- (instancetype)initWithConnectionHandler:(void(^)(NSString *serviceIdentifier, NSXPCListenerEndpoint *listener))handler {
    return [self initWithName:[[NSBundle mainBundle] bundleIdentifier] connectionHandler:handler];
}

- (void)suspend {
    dispatch_suspend(_dispatchSrc);
}

- (void)resume {
    dispatch_resume(_dispatchSrc);
}

- (void)dealloc {
    dispatch_source_cancel(_dispatchSrc);
}

+ (void)load {
    // For the love of god Apple just export the symbols so I don't have to keep doing this
    symrez_t sr_xpc = symrez_new("libxpc.dylib");
    _xpc_endpoint_create = sr_resolve_symbol(sr_xpc, "__xpc_endpoint_create");
    free(sr_xpc);
}
@end
