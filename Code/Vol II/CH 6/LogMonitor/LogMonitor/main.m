/*
 
 NOTE: This is PoC code
   ...don't use in production!

*/

@import Foundation;
#import "LogMonitor.h"

int main(int argc, const char * argv[]) {
    
    int status = 0;
    
    @autoreleasepool {
        
        //log monitor
        LogMonitor* logMonitor = nil;
        
        //log predicate
        NSPredicate* predicate = nil;
        //sanity check
        if(2 != argc)
        {
            printf("\nERROR: please specify a predicate for the log monitor\n\n");
            
            status = -1;
            goto bail;
        }
        
        //init predicate to capture log message from extension
        @try {
            predicate = [NSPredicate predicateWithFormat:[NSString stringWithUTF8String:argv[1]]];
        } @catch (NSException* exception) {
            printf("\nERROR: %s is an invalid predicate\n", argv[1]);
            printf("\nERROR: %s \n\n", exception.description.UTF8String);
            status = -1;
            goto bail;
        }
        
        //init log monitor
        logMonitor = [[LogMonitor alloc] init];
        
        //start log monitor
        // ...and (forevers) print out any messages from extension
        [logMonitor start:predicate level:Log_Level_Default eventHandler:^(OSLogEventProxy* event) {
            
            NSString* output = [NSString stringWithFormat:@"process: %@ / sender: %@ / category: %@ / subsystem: %@ / message: %@", event.process, event.sender, event.category, event.subsystem, event.composedMessage];
            
            printf("%s\n\n", output.UTF8String);
            
        }];
        
        //run
        [NSRunLoop.currentRunLoop run];
    }
    
bail:
    
    return status;
}
