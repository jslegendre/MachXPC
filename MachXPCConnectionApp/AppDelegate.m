//
//  AppDelegate.m
//  MachXPCConnectionApp
//
//  Created by Jeremy on 11/18/20.
//

#import "AppDelegate.h"
#import <MachXPC/MachXPC.h>
#import <Shared/Protocols.h>

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (retain) id<ListenerAppProtocol> proxy;
@property (strong) IBOutlet NSTextField *connectionStatus;
@property (strong) IBOutlet NSTextField *labelField;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [MachXPCConnection connectionFromMachXPCListener:@"com.listener.app" handler:^(NSXPCConnection *connection) {
        if (!connection) {
            NSLog(@"Could not establish connection");
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSApp terminate:nil];
            });
        }
        
        connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ListenerAppProtocol)];
        self.proxy = connection.remoteObjectProxy;
        
        [connection setInterruptionHandler:^ {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSApp terminate:nil];
            });
        }];
        
        [connection setInvalidationHandler:^ {
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSApp terminate:nil];
            });
        }];
        
        [connection resume];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.connectionStatus.stringValue = @"Connected";
        });
    }];
}

- (IBAction)getRemoteLabelText:(id)sender {
    [self.proxy getLabelText:^(NSString *label){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.labelField.stringValue = label;
        });
    }];
}

- (IBAction)setRemoteLabelText:(id)sender {
    [self.proxy setLabelText:self.labelField.stringValue];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
