//
//  AppDelegate.m
//  MachXPCTestApp
//
//  Created by Jeremy on 10/15/20.
//

#import "AppDelegate.h"
#import <MachXPC/MachXPC.h>
#import <Shared/Protocols.h>
#import <spawn.h>

@interface AppDelegate () <MainAppProtocol>

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSProgressIndicator *indicator;
@property (strong) MachXPCHost *host;
@property (strong) NSXPCConnection *con;
@end

@implementation AppDelegate
pid_t p;

- (void)updateProgress:(double)currentProgress {
    NSLog(@"Progress %.2f", currentProgress);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.indicator.doubleValue = currentProgress;
    });
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.host = [[MachXPCHost alloc] initWithConnectionHandler:^(NSString *serviceIdentifier, NSXPCListenerEndpoint *listener) {
        NSLog(@"Connecting to %@", serviceIdentifier);
        
        self.con = [[NSXPCConnection alloc] initWithListenerEndpoint:listener];
        self.con.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ServiceProtocol)];
        self.con.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(MainAppProtocol)];
        self.con.exportedObject = self;
        id<ServiceProtocol> proxy = self.con.remoteObjectProxy;
        [self.con resume];
        
        [proxy doProcessing: ^(NSString *response) {
            NSLog(@"Received response: %@", response);
         }];
    }];
    
    [self.host resume];

    NSString *processPath = [[NSBundle mainBundle] pathForResource:@"MachXPCBackgroundProcess" ofType:nil];

    posix_spawnattr_t attr;
    int status = posix_spawnattr_init(&attr);
    if (status != 0) {
        perror("can't init spawnattr");
        exit(status);
    }

     /*
      posix_spawnattr_setexceptionports_np could be useful here
      ....
      */
    
    p = 0;
    char *args[] = {"MachXPCBackgroundProcess", (char*)NSBundle.mainBundle.bundleIdentifier.UTF8String, NULL};
    posix_spawn(&p, processPath.UTF8String, NULL, &attr, args, NULL);
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    if(p) {
        kill(p, SIGTERM);
    }
}


@end
