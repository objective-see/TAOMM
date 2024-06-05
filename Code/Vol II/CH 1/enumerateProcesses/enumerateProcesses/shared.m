//
//  shared.m
//  enumerateProcesses
//
//  Created by Patrick Wardle on 3/13/24.
//

#import "shared.h"

//exec a process with args
// if 'shouldWait' is set, wait and return stdout/in and termination status
NSMutableDictionary* execTask(NSString* binaryPath, NSArray* arguments)
{
    //task
    NSTask* task = nil;
    
    //output pipe for stdout
    NSPipe* stdOutPipe = nil;
    
    //output pipe for stderr
    NSPipe* stdErrPipe = nil;
    
    //read handle for stdout
    NSFileHandle* stdOutReadHandle = nil;
    
    //read handle for stderr
    NSFileHandle* stdErrReadHandle = nil;
    
    //results dictionary
    NSMutableDictionary* results = nil;
    
    //output for stdout
    NSMutableData *stdOutData = nil;
    
    //output for stderr
    NSMutableData *stdErrData = nil;
    
    //init dictionary for results
    results = [NSMutableDictionary dictionary];
    
    //init task
    task = [NSTask new];
    
    //init stdout pipe
    stdOutPipe = [NSPipe pipe];
    
    //init stderr pipe
    stdErrPipe = [NSPipe pipe];
    
    //init stdout read handle
    stdOutReadHandle = [stdOutPipe fileHandleForReading];
    
    //init stderr read handle
    stdErrReadHandle = [stdErrPipe fileHandleForReading];
    
    //init stdout output buffer
    stdOutData = [NSMutableData data];
    
    //init stderr output buffer
    stdErrData = [NSMutableData data];
    
    //set task's stdout
    task.standardOutput = stdOutPipe;
    
    //set task's stderr
    task.standardError = stdErrPipe;
    
    //set task's path
    task.launchPath = binaryPath;
    
    //set task's args
    if(nil != arguments)
    {
        //set
        task.arguments = arguments;
    }
    
    //wrap task launch
    @try
    {
        //launch
        [task launch];
    }
    @catch(NSException *exception)
    {
        //bail
        goto bail;
    }
    
    //read in stdout/stderr
    while(YES == [task isRunning])
    {
        //accumulate stdout
        [stdOutData appendData:[stdOutReadHandle readDataToEndOfFile]];
        
        //accumulate stderr
        [stdErrData appendData:[stdErrReadHandle readDataToEndOfFile]];
    }
    
    //grab any leftover stdout
    [stdOutData appendData:[stdOutReadHandle readDataToEndOfFile]];
    
    //grab any leftover stderr
    [stdErrData appendData:[stdErrReadHandle readDataToEndOfFile]];
    
    //add stdout
    if(0 != stdOutData.length)
    {
        //add
        results[STDOUT] = stdOutData;
    }
    
    //add stderr
    if(0 != stdErrData.length)
    {
        //add
        results[STDERR] = stdErrData;
    }
    
    //add exit code
    results[EXIT_CODE] = [NSNumber numberWithInteger:task.terminationStatus];
    
bail:
    
    return results;
}
