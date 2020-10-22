//
//  MachXPCHost.h
//  MachXPC
//
//  Created by Jeremy on 10/15/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MachXPCHost : NSObject
@property (readonly) NSString *name;

- (instancetype)initWithName:(NSString *)name connectionHandler:(void(^)(NSString *serviceIdentifier, NSXPCListenerEndpoint *listener))handler;

- (instancetype)initWithConnectionHandler:(void(^)(NSString *serviceIdentifier, NSXPCListenerEndpoint *listener))handler;

- (void)suspend;

- (void)resume;
@end

NS_ASSUME_NONNULL_END
