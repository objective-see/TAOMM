//
//  logMonitor.h
//  logAPI
//
//  Created by Patrick Wardle on 4/30/21.
//  Copyright © 2021 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define LOGGING_SUPPORT @"/System/Library/PrivateFrameworks/LoggingSupport.framework"

//OSLogEvent
@interface OSLogEvent : NSObject
@property NSString *process;
@property NSNumber* processIdentifier;
@property NSString *processImagePath;
@property NSString *sender;
@property NSString *senderImagePath;
@property NSString *category;
@property NSString *subsystem;
@property NSDate *date;
@property NSString *composedMessage;
@end

//OSLogEventLiveStream
@interface OSLogEventLiveStream : NSObject
-(void)activate;
-(void)invalidate;
-(void)setFilterPredicate:(NSPredicate*)predicate;
-(void)setDroppedEventHandler:(void(^)(id))callback;
-(void)setInvalidationHandler:(void(^)(int, id))callback;
-(void)setEventHandler:(void(^)(id))callback;
@property(nonatomic) unsigned long long flags;
@end

//OSLogEventSource
@interface OSLogEventSource : NSObject

@end

//OSLogEventStream
@interface OSLogEventStream : NSObject
-(id)initWithSource:(OSLogEventSource*)source;
-(void)setFilterPredicate:(NSPredicate*)predicate;
-(void)setInvalidationHandler:(void(^)(int, id))callback;
-(void)setEventHandler:(void(^)(id))callback;
-(void)activateStreamFromDate:(NSDate*)date toDate:(NSDate*)date;
@property(nonatomic) unsigned long long flags;
@end

//OSLogEventStore
@interface OSLogEventStore : NSObject
+(id)localStore;
-(OSLogEventSource*)prepareWithCompletionHandler:(void (^)(OSLogEventSource *source, NSError *error))completionHandler;
@property(nonatomic) id localStore;
@end

//OSLogEventProxy
@interface OSLogEventProxy : NSObject
@property(readonly, nonatomic) NSDate *date;
@property(readonly, nonatomic) NSString *process;
@property(readonly, nonatomic) int processIdentifier;
@property(readonly, nonatomic) NSString *processImagePath;
@property(readonly, nonatomic) NSString *sender;
@property(readonly, nonatomic) NSString *senderImagePath;
@property(readonly, nonatomic) NSString *category;
@property(readonly, nonatomic) NSString *subsystem;
@property(readonly, nonatomic) NSString *composedMessage;
@end

//(our) log monitor object
@interface LogMonitor : NSObject

//instance of live stream
@property(nonatomic, retain, nullable)OSLogEventLiveStream* liveStream;

//instance of (query) stream
@property(nonatomic, retain, nullable)OSLogEventStream* quertyStream;

/* METHODS */

//start (stream)
-(BOOL)start:(NSPredicate*)predicate level:(NSUInteger)level eventHandler:(void(^)(OSLogEventProxy*))eventHandler;

//stop (stream)
-(void)stop;

//start query
-(BOOL)startQuery:(NSPredicate*)predicate level:(NSUInteger)level eventHandler:(void(^)(OSLogEventProxy*))eventHandler;

@end

NS_ASSUME_NONNULL_END
