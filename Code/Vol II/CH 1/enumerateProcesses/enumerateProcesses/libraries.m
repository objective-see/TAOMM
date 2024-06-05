//
//  libraries.m
//  enumerateProcesses
//
//  Created by Patrick Wardle on 4/14/22.
//

#import "shared.h"
#import <Foundation/Foundation.h>

#define VMMAP @"/usr/bin/vmmap"

//enumerate dylibs via vmmap
NSMutableArray* getLibraries(pid_t pid)
{
    //dylibs
    NSMutableArray* dylibs = nil;

    //results from 'vmap' cmd
    NSMutableDictionary* results = nil;
    
    //output (stdout) from 'file' cmd
    NSString* output = nil;
    
    //path offset
    NSRange pathOffset = {0};
    
    //dylib
    NSString* dylib = nil;
    
    //match
    NSString* token = @"SM=COW";
    
    //alloc array for dylibs
    dylibs = [NSMutableArray array];
    
    //exec vmmap
    results = execTask(VMMAP, @[@"-w", [[NSNumber numberWithInt:pid] stringValue]]);
    
    //sanity check
    if( (nil == results[EXIT_CODE]) ||
        (0 != [results[EXIT_CODE] integerValue]) )
    {
        //bail
        goto bail;
    }
    
    //convert stdout data to string
    output = [[NSString alloc] initWithData:results[STDOUT] encoding:NSUTF8StringEncoding];
    
    //iterate over all results
    // ->line by line, looking for '__TEXT'
    for(NSString* line in [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
    {
        //ignore any line that doesn't start with '__TEXT'
        if(YES != [line hasPrefix:@"__TEXT"])
        {
            //skip
            continue;
        }
        
        //format of line is: __TEXT 00007fff63564000-00007fff6359b000 [  220K] r-x/rwx SM=COW  /usr/lib/dyld
        // grab path, by first finding: 'SM=COW'
        pathOffset = [line rangeOfString:token];
        if(NSNotFound == pathOffset.location)
        {
            //not found
            continue;
        }
        
        //extract dylib's path
        // trim leading whitespace
        dylib = [[line substringFromIndex:pathOffset.location+token.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if(nil == dylib)
        {
            //skip
            continue;
        }
        
        //add to results array
        [dylibs addObject:dylib];
    }
    
    //remove dups
    [dylibs setArray:[[[NSSet setWithArray:dylibs] allObjects] mutableCopy]];
    
bail:
    
    return dylibs;
    
}
