//
//  mute.m
//  ESPlayground
//


#import "main.h"

extern es_client_t* client;
NSData* getAuditToken(pid_t pid);

#define MDS_STORE "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/Metadata.framework/Versions/A/Support/mds_stores"

BOOL mute(void)
{
    BOOL started = NO;
    NSData* auditToken = nil;
    char tmpDirectory[PATH_MAX] = {0};
    
    es_return_t result = 0;
    es_new_client_result_t clientResult = 0;
    
    es_event_type_t events[] = {ES_EVENT_TYPE_NOTIFY_OPEN, ES_EVENT_TYPE_NOTIFY_CLOSE};

    //create client
    clientResult = es_new_client(&client, ^(es_client_t *client, const es_message_t *message)
    {
        es_string_token_t* procPath = nil;
        es_string_token_t* filePath = nil;
        
        procPath = &message->process->executable->path;
        
        switch (message->event_type) {
                
            case ES_EVENT_TYPE_NOTIFY_OPEN:
                filePath = &message->event.open.file->path;
                
                printf("\nevent: ES_EVENT_TYPE_NOTIFY_OPEN\n");
                printf("process: %.*s\n", (int)procPath->length, procPath->data);
                printf("file path: %.*s\n", (int)filePath->length, filePath->data);
                
                break;
                
            case ES_EVENT_TYPE_NOTIFY_CLOSE:
                filePath = &message->event.close.target->path;
                
                printf("\nevent: ES_EVENT_TYPE_NOTIFY_CLOSE\n");
                printf("process: %.*s\n", (int)procPath->length, procPath->data);
                printf("file path: %.*s\n", (int)filePath->length, filePath->data);
                
                break;
        
            default:
                break;
        }
    });
    if(ES_NEW_CLIENT_RESULT_SUCCESS != clientResult)
    {
        printESClientError(clientResult);
        goto bail;
    }
    
    //get our own audit token
    auditToken = getAuditToken(getpid());
    
    //mute ourselves
    result = es_mute_process(client, auditToken.bytes);
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_mute_process' failed with %#x\n", result);
        goto bail;
    }
    
    printf("muted process: %s\n", [[NSProcessInfo.processInfo.arguments[0] lastPathComponent] UTF8String]);
    
    //mute mds
    result = es_mute_path(client, MDS_STORE, ES_MUTE_PATH_TYPE_LITERAL);
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_mute_path' failed with %#x\n", result);
        goto bail;
    }
    
    printf("muted process (via path): %s\n", MDS_STORE);
    

    //mute (root's) tmp dir
    realpath([NSTemporaryDirectory() UTF8String], tmpDirectory);
    result = es_mute_path(client, tmpDirectory, ES_MUTE_PATH_TYPE_TARGET_PREFIX);
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_mute_path' failed with %#x\n", result);
        goto bail;
    }
    
    printf("muted directory: %s\n", tmpDirectory);
    
    //time for msg to show up
    sleep(3);
    
    //subscribe
    result = es_subscribe(client, events, sizeof(events)/sizeof(events[0]));
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_subscribe' failed with %#x\n", result);
        goto bail;
    }
    
    //happy
    started = YES;
    
bail:
    
    return started;
}

//get audit token for a process
NSData* getAuditToken(pid_t pid)
{
    NSData* auditToken = nil;
    
    task_name_t task = {0};
    audit_token_t token = {0};
    kern_return_t status = 0;
    mach_msg_type_number_t info_size = TASK_AUDIT_TOKEN_COUNT;

    //get task for process
    status = task_name_for_pid(mach_task_self(), pid, &task);
    if(KERN_SUCCESS != status)
    {
        //err
        NSLog(@"ERROR: task_name_for_pid failed with %d/%#x", status, status);
        goto bail;
    }
    
    status = task_info(task, TASK_AUDIT_TOKEN, (integer_t *)&token, &info_size);
    if(KERN_SUCCESS != status)
    {
        //err
        NSLog(@"ERROR: 'task_info' failed with %d/%#x", status, status);
        goto bail;
    }

    auditToken = [NSData dataWithBytes:&token length:sizeof(audit_token_t)];
    
bail:
    
    return auditToken;
}
