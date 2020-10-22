//
//  main.m
//  MachXPCBackgroundProcess
//
//  Created by Jeremy on 10/15/20.
//

#import <Foundation/Foundation.h>
#import <Shared/Protocols.h>
#import <MachXPC/MachXPC.h>
#import <servers/bootstrap.h>

@interface XPCService : NSObject <NSXPCListenerDelegate, ServiceProtocol>
//@property (weak) NSXPCListener *listener;
@property (weak) NSXPCConnection *hostConnection;
@end

@implementation XPCService
- (void) doProcessing: (void (^)(NSString *g))reply {
    
    reply(@"Starting");
    
    dispatch_async(dispatch_get_global_queue(0,0), ^{
      for(int index = 0; index < 60; ++index) {
          [NSThread sleepForTimeInterval: 1];
          [self->_hostConnection.remoteObjectProxy updateProgress: (double)index / (double)60 * 100];
      }
        
    });
}

//- (id)init {
//    self = [super init];
//    if (self != nil) {
//        self.listener = [NSXPCListener anonymousListener];
//        self.listener.delegate = self;
//        [self.listener resume];
//    }
//    return self;
//}

#pragma mark XPCListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ServiceProtocol)];
    newConnection.exportedObject = self;
    _hostConnection = newConnection;

    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol: @protocol(MainAppProtocol)];
    [newConnection resume];
    return YES;
}

@end


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        XPCService *service = [XPCService new];
        [MachXPCService registerObject:service
                        withIdentifier:[NSString stringWithUTF8String:argv[0]]
                               forHost:[NSString stringWithUTF8String:argv[1]]
                     completionHandler:^(BOOL success) { NSLog(@"Success? %d", success); }];
        
//        MachXPCService *mxsService = [[MachXPCService alloc] initWithListener:service.listener
//                                                               withIdentifier:[NSString stringWithUTF8String:argv[0]]
//                                                                      forHost:[NSString stringWithUTF8String:argv[1]]
//                                                            completionHandler:^(BOOL success) {
//            NSLog(@"Success? %d", success);
//        }];

//        NSLog(@"%@", mxsService);

        BOOL shouldKeepRunning = YES; // global
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        while (shouldKeepRunning && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    }
    return 0;
}
