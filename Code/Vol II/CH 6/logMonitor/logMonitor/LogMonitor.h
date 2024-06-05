/*
 
 NOTE: This is PoC code
   ...don't use in production!

*/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//log levels
typedef enum {Log_Level_Default, Log_Level_Info, Log_Level_Debug} LogLevels;

#define LOGGING_SUPPORT @"/System/Library/PrivateFrameworks/LoggingSupport.framework"

//private log stream object
@interface OSLogEventLiveStream : NSObject

- (void)activate;
- (void)invalidate;
- (void)setFilterPredicate:(NSPredicate*)predicate;
- (void)setDroppedEventHandler:(void(^)(id))callback;
- (void)setInvalidationHandler:(void(^)(int, id))callback;
- (void)setEventHandler:(void(^)(id))callback;

@property(nonatomic) unsigned long long flags;

@end

//private log event object
//implementation in framework
@interface OSLogEventProxy : NSObject

@property(readonly, nonatomic) NSString *process;
@property(readonly, nonatomic) int processIdentifier;
@property(readonly, nonatomic) NSString *processImagePath;

@property(readonly, nonatomic) NSString *sender;
@property(readonly, nonatomic) NSString *senderImagePath;

@property(readonly, nonatomic) NSString *category;
@property(readonly, nonatomic) NSString *subsystem;

@property(readonly, nonatomic) NSDate *date;

@property(readonly, nonatomic) NSString *composedMessage;

-(NSString*)description;

@end


//(our) log monitor object
@interface LogMonitor : NSObject

//instance of live stream
@property(nonatomic, retain, nullable)OSLogEventLiveStream* liveStream;

/* METHODS */

//start
-(BOOL)start:(NSPredicate*)predicate level:(NSUInteger)level eventHandler:(void(^)(OSLogEventProxy*))eventHandler;

//stop
-(void)stop;

@end

NS_ASSUME_NONNULL_END
