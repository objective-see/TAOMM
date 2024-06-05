//
//  protect.m
//  ESPlayground
//


#import "main.h"

#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <SystemConfiguration/SCDynamicStoreCopySpecific.h>

extern es_client_t* client;
BOOL isNotarized(es_process_t* process);

//protect user's home directory
BOOL protect(void)
{
    BOOL started = NO;
    es_return_t result = 0;
    es_new_client_result_t clientResult = 0;
    
    NSString* consoleUser = (__bridge_transfer NSString *)SCDynamicStoreCopyConsoleUser(NULL, NULL, NULL);
    NSString* homeDirectory = NSHomeDirectoryForUser(consoleUser);
    
    es_event_type_t events[] = {ES_EVENT_TYPE_AUTH_OPEN, ES_EVENT_TYPE_AUTH_UNLINK};

    clientResult = es_new_client(&client, ^(es_client_t *client, const es_message_t *message) {

        BOOL isTrusted = NO;
        
        es_string_token_t* procPath = &message->process->executable->path;
        es_string_token_t* filePath = NULL;
        
        printf("platform: %d\n", message->process->is_platform_binary);
        
        isTrusted = ( (YES == message->process->is_platform_binary) || (YES == isNotarized(message->process)) );


        switch (message->event_type) {
                
            case ES_EVENT_TYPE_AUTH_OPEN:
                
                filePath = &message->event.open.file->path;
                
                printf("\nevent: ES_EVENT_TYPE_AUTH_OPEN\n");
                printf("responsible process: %.*s\n", (int)procPath->length, procPath->data);
                printf("target file path: %.*s\n", (int)filePath->length, filePath->data);
                
                if(YES == isTrusted) {
                    printf("process is trusted, so will allow event\n");
                    es_respond_flags_result(client, message, UINT32_MAX, false);
                }
                else {
                    printf("process is *not* trusted, so will deny event\n");
                    es_respond_flags_result(client, message, 0, false);
                }

                break;
                
            case ES_EVENT_TYPE_AUTH_UNLINK:
                
                filePath = &message->event.unlink.target->path;
                
                printf("\nevent: ES_EVENT_TYPE_AUTH_UNLINK\n");
                printf("responsible process: %.*s\n", (int)procPath->length, procPath->data);
                printf("target file path: %.*s\n", (int)filePath->length, filePath->data);
                
                if(YES == isTrusted) {
                    printf("process is trusted, so will allow event\n");
                    es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false);
                }
                else {
                    printf("process is *not* trusted, so will deny event\n");
                    es_respond_auth_result(client, message, ES_AUTH_RESULT_DENY, false);
                }

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
    
    result = es_unmute_all_target_paths(client);
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_unmute_all_target_paths' failed with %#x\n", result);
        goto bail;
    }
    
    result = es_invert_muting(client, ES_MUTE_INVERSION_TYPE_TARGET_PATH);
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_invert_muting' failed with %#x\n", result);
        goto bail;
    }
    
    result = es_mute_path(client, homeDirectory.UTF8String, ES_MUTE_PATH_TYPE_TARGET_PREFIX);
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_mute_path' failed with %#x\n", result);
        goto bail;
    }
    
    printf("protecting directory: %s\n", homeDirectory.UTF8String);
    
    //time for msg to show up
    sleep(3);

    result = es_subscribe(client, events, sizeof(events)/sizeof(events[0]));
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
    {
        printf("\n\nERROR: 'es_mute_path' failed with %#x\n", result);
        goto bail;
    }
    
    //happy
    started = YES;
    
bail:

    return started;
}

//check if process is notarized
BOOL isNotarized(es_process_t* process)
{
    //flag
    BOOL isNotarized = NO;
    
    //audit token
    audit_token_t token;
    NSData* auditToken = nil;
    
    //dynamic code ref
    SecCodeRef dynamicCode = NULL;
    
    //extract (audit) token
    token = process->audit_token;
    
    auditToken = [NSData dataWithBytes:&token length:sizeof(audit_token_t)];
    
    //attribues
    NSDictionary* attributes = NULL;
    
    //status
    OSStatus status = -1;
    
    printf("checking process....\n");

    //is notarized requirement
    static SecRequirementRef notarizedReq = nil;

    //init attributes
    attributes = @{(__bridge NSString *)kSecGuestAttributeAudit:auditToken};
    
    status = SecCodeCopyGuestWithAttributes(0, (__bridge CFDictionaryRef _Nullable)(attributes), kSecCSDefaultFlags, &dynamicCode);
    if(errSecSuccess != status)
    {
        //err msg
        NSLog(@"ERROR: 'SecCodeCopyGuestWithAttributes' failed with %d/%#x", status, status);
        goto bail;
    }
    
    printf("SecCodeCopyGuestWithAttributes ok....\n");
    
    //validate code
    status = SecCodeCheckValidity(dynamicCode, kSecCSDefaultFlags, NULL);
    if(errSecSuccess != status)
    {
        //bail
        NSLog(@"ERROR: 'SecCodeCheckValidity 1' failed with %d/%#x", status, status);
        goto bail;
    }
    
    printf("SecCodeCheckValidity ok....\n");
    
    //init requirement string
    status = SecRequirementCreateWithString(CFSTR("notarized"), kSecCSDefaultFlags, &notarizedReq);
    if(errSecSuccess != status)
    {
        //bail
        NSLog(@"ERROR: 'SecRequirementCreateWithString' failed with %d/%#x", status, status);
        goto bail;
    }
    
    //check notarization status
    status = SecCodeCheckValidity(dynamicCode, kSecCSDefaultFlags, notarizedReq);
    if(errSecSuccess != status)
    {
        //bail
        NSLog(@"ERROR: 'SecCodeCheckValidity 2' failed with %d/%#x", status, status);
        goto bail;
    }
    
    //happy
    isNotarized = YES;
        
    
    
bail:
    
    //free static code
    if(NULL != dynamicCode)
    {
        CFRelease(dynamicCode);
        dynamicCode = NULL;
    }
    
    return isNotarized;
}
