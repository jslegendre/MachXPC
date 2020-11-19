//
//  MachXPCListener.h
//  MachXPC
//
//  Created by Jeremy on 11/18/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MachXPCListener : NSObject

- (instancetype)initWithObject:(id<NSXPCListenerDelegate>)serviceInstance identifier:(NSString*)identifier;
- (void)resume;
- (void)suspend;

@end

NS_ASSUME_NONNULL_END
