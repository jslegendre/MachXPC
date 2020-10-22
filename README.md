# MachXPC
`launchd_get_out_of_my_way=0x1`

This is a framework to help establish an `NSXPCConnection` between two (or more) processes WITHOUT the need for a 3rd process to "broker" the `NSXPCEndpoint`s. An example of the issue is demonstrated in [OpenEmuXPCCommunicator](https://github.com/OpenEmu/OpenEmuXPCCommunicator) where another process is invoked and then registered with `launchd` via `launchctl` with a plist. With the `MachXPC` framework, you can greatly simplify and streamline the connection and distribution process.

MachXPC uses the host/service paradigm the same way `NSXPCConnection` does. General process is

- Register a host
- Background/secondary processes connect to the host


### Register a Host:

```
MachXPCHost *host = [[MachXPCHost alloc] initWithName:@"my.host.identifier" connectionHandler:^(NSString *serviceIdentifier, NSXPCListenerEndpoint *listener) {
 
  // Handle incoming connections here
 
}];
    
[host resume];
```

### Register a Service:

```
[MachXPCService registerObject:service
                withIdentifier:@"my.service.identifier"
                       forHost:@"my.host.identifier"
             completionHandler:^(BOOL success) { NSLog(@"Success? %d", success); }];
```

### Example
A full example/demo project has been included 
