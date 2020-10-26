//
//  MachXPCService.m
//  MachXPC
//
//  Created by Jeremy on 10/15/20.
//

#import "MachXPCService.h"
#import <MachXPC/MachXPC-Internal.h>
#import <servers/bootstrap.h>

@interface NSXPCListenerEndpoint (Private)
-(xpc_endpoint_t)_endpoint;
@end


@interface MachXPCService ()
@property (weak) NSXPCListener *listener;
@end

@implementation MachXPCService

+ (void)registerListener:(NSXPCListener*)listener withIdentifier:(NSString*)identifier forHost:(NSString*)hostId completionHandler:(void(^)(BOOL success))handler {
    
    NSXPCListenerEndpoint *nsEndpoint = listener.endpoint;
    xpc_endpoint_t xpcEndpoint = [nsEndpoint _endpoint];
    // Offset 0x18 is where the mach_port_t is stored in what I imagine to be `struct xpc_endpoint`
    mach_port_t endpointPort = *(mach_port_t*)(((__bridge void*)xpcEndpoint) + 0x18);
    if(endpointPort == -1) {
        NSLog(@"MachXPCService: Endpoint invalid");
        handler(NO);
    }
    mach_port_t server_port = MACH_PORT_NULL;
    kern_return_t kr = KERN_SUCCESS;

    kr = bootstrap_look_up(bootstrap_port, hostId.UTF8String, &server_port);
    if(kr) {
        NSLog(@"MachXPCService: Could not find host %@", hostId);
        handler(NO);
    }
    
    dispatch_async(dispatch_get_global_queue(0,0), ^{
        msg_format_response_t  send_msg;
        mach_msg_header_t     *send_hdr;
        
        const char *serviceID = identifier.UTF8String;
        
        send_hdr = &(send_msg.header);
        send_hdr->msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND);
        send_hdr->msgh_bits |= MACH_MSGH_BITS_COMPLEX;
        send_hdr->msgh_size = sizeof(send_msg);
        send_hdr->msgh_local_port = MACH_PORT_NULL;
        send_hdr->msgh_remote_port = server_port;
        send_msg.body.msgh_descriptor_count = 2;
        send_msg.data.name = endpointPort;
        send_msg.data.disposition = (MACH_MSG_TYPE_COPY_SEND);
        send_msg.data.type = MACH_MSG_PORT_DESCRIPTOR;
        send_msg.ool.address = (uint64_t)(void*)serviceID;
        send_msg.ool.size = (mach_msg_size_t)(strlen(serviceID) + 1);
        send_msg.ool.deallocate = false;
        send_msg.ool.copy = MACH_MSG_VIRTUAL_COPY;
        send_msg.ool.type = MACH_MSG_OOL_DESCRIPTOR;
        kern_return_t kr = mach_msg(send_hdr,
                                    MACH_SEND_MSG,
                                    send_hdr->msgh_size,
                                    0,
                                    MACH_PORT_NULL,
                                    5000,
                                    MACH_PORT_NULL);
        
        if(kr) {
            NSLog(@"MachXPCService: Could not send endpoint to host");
            handler(NO);
        } else {
            handler(YES);
        }
        mach_port_deallocate(mach_task_self(), server_port);
    });
}

+ (void)registerObject:(id<NSXPCListenerDelegate>)serviceInstance withIdentifier:(NSString*)identifier forHost:(NSString*)hostId completionHandler:(void(^)(BOOL success))handler {
    NSXPCListener *listener = [NSXPCListener anonymousListener];
    listener.delegate = serviceInstance;
    [listener resume];
    
    [MachXPCService registerListener:listener withIdentifier:identifier forHost:hostId completionHandler:handler];
}

@end
