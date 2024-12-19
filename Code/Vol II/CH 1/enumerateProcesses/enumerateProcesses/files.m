//
//  main.m
//  enumerateFiles
//
//  Created by Patrick Wardle on 4/11/22.
//
//  Inspired by https://github.com/palominolabs/get_process_handles

#import "shared.h"

#import <libproc.h>
#import <Foundation/Foundation.h>

#define LSOF @"/usr/sbin/lsof"

//get (open) files via proc_pidinfo
NSMutableArray* getFiles(pid_t pid)
{
    //size
    int size = 0;
    
    //file
    NSString* file = nil;
    
    //files
    NSMutableArray* files = nil;
    
    //file descriptor info
    struct proc_fdinfo *fdInfo = NULL;
            
    //init
    files = [NSMutableArray array];
    
    //get size needed to hold list of file descriptors
    size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if(size <= 0)
    {
        //error
        printf("\nERROR: 'proc_pidinfo' failed with %d\n\n", errno);
        goto bail;
    }
    
    //alloc list for open file descriptors
    fdInfo = (struct proc_fdinfo *)malloc(size);
    if(NULL == fdInfo)
    {
        //bail
        goto bail;
    }
    
    //get list of open file descriptors
    size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fdInfo, size);
    if(size <= 0)
    {
        //error
        printf("\nERROR: 'proc_pidinfo' failed with %d\n\n", errno);
        goto bail;
    }
    
    //iterate over file descriptors
    // extract / parse files (vnodes)
    for(int i = 0; i < (size/PROC_PIDLISTFD_SIZE); i++)
    {
        struct vnode_fdinfowithpath vnodeInfo = {0};
        
        //only care about files
        if(PROX_FDTYPE_VNODE != fdInfo[i].proc_fdtype)
        {
            continue;
        }
        
        //get (more) info about file
        if(PROC_PIDFDVNODEPATHINFO_SIZE == proc_pidfdinfo(pid, fdInfo[i].proc_fd, PROC_PIDFDVNODEPATHINFO, &vnodeInfo, PROC_PIDFDVNODEPATHINFO_SIZE))
        {
            //extract path
            file = [NSString stringWithUTF8String:vnodeInfo.pvip.vip_path];
            if(0 != file.length)
            {
                [files addObject:file];
            }
        }
    }
    
bail:

    //cleanup
    if(NULL != fdInfo)
    {
        free(fdInfo);
        fdInfo = NULL;
    }
    
    return files;
}

//get (open) files via lsof
NSMutableArray* getFiles2(pid_t pid)
{
    //file
    NSString* file = nil;
    
    //files
    NSMutableArray* files = nil;
    
    //results split on '\n'
    NSArray* splitResults = nil;
    
    //results from 'lsof' cmd
    NSMutableDictionary* results = nil;
    
    //init array for unqiue files
    files = [NSMutableArray array];
    
    //exec 'file' to get file type
    results = execTask(LSOF, @[@"-Fn", @"-p", [NSNumber numberWithInt:pid].stringValue]);
    if( (nil == results[EXIT_CODE]) ||
        (0 != [results[EXIT_CODE] integerValue]) )
    {
        //bail
        goto bail;
    }
    
    //split results into array
    splitResults = [[[NSString alloc] initWithData:results[STDOUT] encoding:NSUTF8StringEncoding] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if( (nil == splitResults) ||
        (0 == splitResults.count) )
    {
        //bail
        goto bail;
    }

    //iterate over all
    // save each file path
    for(NSString* result in splitResults)
    {
        //skip any odd/weird/short lines
        // lsof outpupt will be in format: 'n<filePath'>
        if( (YES != [result hasPrefix:@"n"]) ||
            (result.length < 0x2) )
        {
            //skip
            continue;
        }
        
        //init file path
        // result, minus first (lsof-added) char
        file = [result substringFromIndex:0x1];
        
        //skip 'non files'
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:file])
        {
            //skip
            continue;
        }
        
        //also skip files such as '/', /dev/null, etc
        if( (YES == [file isEqualToString:@"/"]) ||
            (YES == [file isEqualToString:@"/dev/null"]) )
        {
            //skip
            continue;
        }
        
        //save
        [files addObject:file];

    }
    
bail:
    
    return files;
}
