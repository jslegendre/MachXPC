//
//  Protocols.h
//  MachXPC
//
//  Created by Jeremy on 10/15/20.
//

#ifndef Protocols_h
#define Protocols_h

#import <Foundation/Foundation.h>

@protocol ServiceProtocol

- (void) doProcessing: (void (^)(NSString *response))reply;

@end

@protocol MainAppProtocol

- (void)updateProgress:(double)progress;

@end

@protocol ListenerAppProtocol <NSObject>

- (void)setLabelText:(NSString *)label;
- (void)getLabelText:(void(^)(NSString *connection))reply;

@end

#endif /* Protocols_h */
