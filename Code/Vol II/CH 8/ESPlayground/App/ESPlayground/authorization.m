//
//  authorization.m
//  ESPlayground
//
//  Created by Patrick Wardle on 3/24/24.
//  Copyright © 2024 Patrick Wardle. All rights reserved.
//

#import "main.h"
#import <SystemConfiguration/SCDynamicStoreCopySpecific.h>

extern es_client_t* client;

BOOL authorization(void)
{
    BOOL started = NO;

    es_return_t result = 0;
    es_new_client_result_t clientResult = 0;

    es_event_type_t events[] = {ES_EVENT_TYPE_AUTH_EXEC};

    //create client
    clientResult = es_new_client(&client, ^(es_client_t *client, const es_message_t *message)
    {
        es_process_t* process = nil;
        es_string_token_t* procPath = nil;
        
        //sanity check
        // should never happen though
        if(ES_EVENT_TYPE_AUTH_EXEC != message->event_type) {
            
            return;
        }
              
        process = message->event.exec.target;
        
        procPath = &process->executable->path;
        
        printf("\nevent: ES_EVENT_TYPE_AUTH_EXEC\n");
        printf("process: %.*s\n", (int)procPath->length, procPath->data);

        //always allow
        es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false);
    });
    if(ES_NEW_CLIENT_RESULT_SUCCESS != clientResult)
    {
        printESClientError(clientResult);
        goto bail;
    }
    
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
