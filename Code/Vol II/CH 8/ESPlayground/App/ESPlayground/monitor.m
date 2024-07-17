//
//  monitor.m
//  ESPlayground
//

#import "main.h"
#import <bsm/libbsm.h>
#import <kernel/kern/cs_blobs.h>

extern es_client_t* client;

BOOL monitor(void)
{
    BOOL started = NO;
    es_new_client_result_t result = 0;
    es_event_type_t events[] = {ES_EVENT_TYPE_NOTIFY_EXEC, ES_EVENT_TYPE_NOTIFY_EXIT};

    //create client
    result = es_new_client(&client, ^(es_client_t *client, const es_message_t *message)
    {
        es_process_t* process = NULL;
        NSString* path = nil;
        
        u_int32_t event = message->event_type;
        
        switch (event) {
                
            case ES_EVENT_TYPE_NOTIFY_EXEC:
            {
                NSString* script = NULL;
                cpu_type_t cpuType = 0;
                
                process = message->event.exec.target;
                
                path = [[NSString alloc] initWithBytes:process->executable->path.data length:process->executable->path.length encoding:NSUTF8StringEncoding];

                NSData* auditToken = [NSData dataWithBytes:&process->audit_token length:sizeof(audit_token_t)];
                
                pid_t pid = audit_token_to_pid(process->audit_token);
                
                pid_t ppid = process->ppid;

                NSData* parentToken = nil;
                NSData* responsibleToken = nil;

                if(message->version >= 4) {

                parentToken = [NSData dataWithBytes:&process->parent_audit_token
                 length:sizeof(audit_token_t)];

                responsibleToken = [NSData dataWithBytes:&process->responsible_audit_token
                length:sizeof(audit_token_t)];

                }

                if(message->version >= 2) {
                  es_string_token_t* token = &message->event.exec.script->path;
                    if(NULL != token) {
                     script = [[NSString alloc] initWithBytes:token->data
                     length:token->length encoding:NSUTF8StringEncoding];
                    }
                }
                
                if(message->version >= 6) {
                    cpuType = message->event.exec.image_cputype;
                }
                
                uint32_t csFlags = process->codesigning_flags;
                NSNumber* isPlatformBinary = [NSNumber numberWithBool:process->is_platform_binary];
                
                printf("\nevent: ES_EVENT_TYPE_NOTIFY_EXEC\n");
                printf("(new) process\n");
                printf(" pid: %d\n", pid);
                printf(" path: %s\n", path.UTF8String);
                if(NULL != script)
                {
                    printf(" script: %s\n", script.UTF8String);
                }
                if(0 != cpuType)
                {
                    printf(" cpu type: %#x/%d\n", cpuType, cpuType);
                }
      
                printf(" code signing flags: %#x\n", csFlags);
                if(CS_VALID & csFlags) {
                    printf(" code signing flag 'CS_VALID' is set\n");
                }
                if(CS_SIGNED & csFlags) {
                    printf(" code signing flag 'CS_SIGNED' is set\n");
                }
                if(CS_ADHOC & csFlags) {
                    printf(" code signing flag 'CS_ADHOC' is set\n");
                }
                if(CS_HARD & csFlags)
                {
                    printf(" code signing flag 'CS_HARD' is set\n");
                }

                printf("\n");
                
                NSMutableArray* arguments = [NSMutableArray array];
                const es_event_exec_t* exec = &message->event.exec;
                
                    
                for(uint32_t i = 0; i < es_exec_arg_count(exec); i++) {
                    es_string_token_t token = es_exec_arg(exec, i);
                    NSString* argument = [[NSString alloc] initWithBytes:token.data
                                length:token.length encoding:NSUTF8StringEncoding];

                    [arguments addObject:argument];
                }
                
                if(arguments.count > 1)
                {
                    printf("arguments: %s\n", arguments.description.UTF8String);
                }

                
                break;
            }
                
            case ES_EVENT_TYPE_NOTIFY_EXIT:
            {
                int status = message->event.exit.stat;
                
                process = message->process;
                
                path = [[NSString alloc] initWithBytes:process->executable->path.data length:process->executable->path.length encoding:NSUTF8StringEncoding];
                
                printf("\nevent: ES_EVENT_TYPE_NOTIFY_EXIT\n");
                printf("process: %s\n", path.UTF8String);
                printf("exited with: %d\n", status);
                printf("\n");
                
                break;
            }
        
            default:
                break;
        }
    });
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printESClientError(result);
        goto bail;
    }
    
    //subscribe
    if(ES_NEW_CLIENT_RESULT_SUCCESS != es_subscribe(client, events, sizeof(events)/sizeof(events[0])))
    {
        printf("\n\nERROR: 'es_subscribe' failed\n");
        goto bail;
    }
    
    //happy
    started = YES;
    
bail:
    
    return started;
}
