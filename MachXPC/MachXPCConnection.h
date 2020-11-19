//
//  MachXPCConnection.h
//  MachXPC
//
//  Created by Jeremy on 11/18/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MachXPCConnection : NSObject
+ (void)connectionFromMachXPCListener:(NSString *)identifier handler:(void(^)(NSXPCConnection *connection))handler;
@end

NS_ASSUME_NONNULL_END
