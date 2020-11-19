//
//  AppDelegate.m
//  MachXPCListenerApp
//
//  Created by Jeremy on 11/18/20.
//

#import "AppDelegate.h"
#import <MachXPC/MachXPC.h>
#import <Shared/Protocols.h>

@interface AppDelegate () <NSXPCListenerDelegate, ListenerAppProtocol>

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSTextField *label;
@end

@implementation AppDelegate

- (void)setLabelText:(NSString *)label {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.label.stringValue = label;
    });
}

- (void)getLabelText:(void (^)(NSString *))reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        reply(self.label.stringValue);
    });
}

#pragma mark XPCListenerDelegate
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ListenerAppProtocol)];
    newConnection.exportedObject = self;
    [newConnection resume];
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    MachXPCListener *listener = [[MachXPCListener alloc] initWithObject:self identifier:@"com.listener.app"];
    [listener resume];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
