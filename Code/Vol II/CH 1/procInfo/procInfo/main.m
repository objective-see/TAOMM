//
//  main.m
//  getProcessInfo_XPC
//
//  Created by Patrick Wardle on 2/25/22.
//

#import "launchdXPC.h"
#import <Foundation/Foundation.h>

NSMutableDictionary* parse(NSString* data);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        //pid
        pid_t pid = 0;
        
        //process info
        NSDictionary* processInfo = nil;
        
        //sanity check
        if(argc != 2)
        {
            return printf("ERROR: requires process identifier\n\n");
        }
        
        //extract pid
        pid = atoi(argv[1]);
        
        //get process info
        processInfo = getProcessInfo(pid);
        
        //dbg msg
        printf("process info (pid: %d): %s\n", atoi(argv[1]), processInfo.description.UTF8String);
        
        //submitted by
        printf("submitted by: %s\n", [processInfo[@"path"] UTF8String]);
    }
    return 0;
}
