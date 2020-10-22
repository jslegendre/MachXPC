//
//  MachXPCService.h
//  MachXPC
//
//  Created by Jeremy on 10/15/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MachXPCService : NSObject
@property (readonly) NSString *identifier;
@property (readonly) NSString *hostIdentifier;

+ (void)registerListener:(NSXPCListener*)listener withIdentifier:(NSString*)identifier forHost:(NSString*)hostId completionHandler:(void(^)(BOOL success))handler;

+ (void)registerObject:(id<NSXPCListenerDelegate>)serviceInstance withIdentifier:(NSString*)identifier forHost:(NSString*)hostId completionHandler:(void(^)(BOOL success))handler;

@end

NS_ASSUME_NONNULL_END
