//
//  muteInvert.m
//  ESPlayground
//

#import "main.h"
#import <SystemConfiguration/SCDynamicStoreCopySpecific.h>

extern es_client_t* client;

BOOL muteInvert(void)
{
    BOOL started = NO;

    es_return_t result = 0;
    es_new_client_result_t clientResult = 0;

    NSString* consoleUser = nil;
    NSString* docsDirectory = nil;
    
    es_event_type_t events[] = {ES_EVENT_TYPE_NOTIFY_OPEN};
    
    consoleUser = (__bridge_transfer NSString *)SCDynamicStoreCopyConsoleUser(NULL, NULL, NULL);
    docsDirectory = [NSHomeDirectoryForUser(consoleUser) stringByAppendingPathComponent:@"Documents"];

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
        
            default:
                break;
        }
    });
    if(ES_NEW_CLIENT_RESULT_SUCCESS != clientResult)
    {
        printESClientError(clientResult);
        goto bail;
    }
    
    //first unmute all
    result = es_unmute_all_target_paths(client);
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_unmute_all_target_paths' failed with %#x\n", result);
        goto bail;
    }
    
    printf("unmuted all (default) paths\n");
    
    //invert
    result = es_invert_muting(client, ES_MUTE_INVERSION_TYPE_TARGET_PATH);
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_invert_muting' failed with %#x\n", result);
        goto bail;
    }
    
    //mute (invert)
    // to watch user's docs directory
    result = es_mute_path(client, docsDirectory.UTF8String, ES_MUTE_PATH_TYPE_TARGET_PREFIX);
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_mute_path' failed with %#x\n", result);
        goto bail;
    }
    
    printf("mute (inverted) %s\n", docsDirectory.UTF8String);

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
