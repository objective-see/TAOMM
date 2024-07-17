/*
 
 NOTE: This is PoC code
   ...don't use in production!

*/

#import "main.h"

/* ARGS */
#define OPTION_MUTE @"-mute"
#define OPTION_MONITOR @"-monitor"
#define OPTION_PROTECT @"-protect"
#define OPTION_MUTE_INVERT @"-muteinvert"
#define OPTION_AUTHORIZATION @"-authorization"

/* GLOBALS */

//endpoint client
es_client_t* client = NULL;

int main(int argc, const char * argv[]) {
    
    //return var
    int status = -1;
    
    @autoreleasepool {
        
        //args
        NSArray* arguments = nil;
        
        //grab args
        arguments = NSProcessInfo.processInfo.arguments;
        
        printf("ES Playground\n");
    
        //handle '-h' or '-help'
        if( (YES == [arguments containsObject:@"-h"]) ||
            (YES == [arguments containsObject:@"-help"]) )
        {
            //print usage
            usage();
            
            //done
            goto bail;
        }
        
        //monitor?
        if(YES == [arguments containsObject:OPTION_MONITOR])
        {
            printf("Executing (process) 'monitoring' logic\n");
            if(YES != monitor())
            {
                goto bail;
            }
        }
        
        //protect
        else if(YES == [arguments containsObject:OPTION_PROTECT])
        {
            printf("Executing (process) 'monitoring' logic\n");
            if(YES != protect())
            {
                goto bail;
            }
        }
        
        //mute?
        else if(YES == [arguments containsObject:OPTION_MUTE])
        {
            printf("Executing 'mute' logic\n");
            if(YES != mute())
            {
                goto bail;
            }
        }
        
        //mute invert
        else if(YES == [arguments containsObject:OPTION_MUTE_INVERT])
        {
            printf("Executing 'mute inversion' logic\n");
            if(YES != muteInvert())
            {
                goto bail;
            }
        }
        
        //authorization
        else if(YES == [arguments containsObject:OPTION_AUTHORIZATION])
        {
            printf("Executing 'authorization' logic\n");
            if(YES != authorization())
            {
                goto bail;
            }
        }
        
        //protect
        else if(YES == [arguments containsObject:OPTION_PROTECT])
        {
            printf("Executing 'protect' logic\n");
            if(YES != protect())
            {
                goto bail;
            }
        }
        
        else
        {
            //print usage
            usage();
            
            //done
            goto bail;
        }
        
        //run loop
        // as don't want to exit
        [[NSRunLoop currentRunLoop] run];
        
    } //pool
    
bail:
        
    return status;
}

//print usage
void usage(void)
{
    //name
    NSString* name = nil;
    
    //version
    NSString* version = nil;
    
    //extract name
    name = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    
    //extract version
    version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];

    //usage
    printf("\n%s (v%s) usage:\n", name.UTF8String, version.UTF8String);
    printf(" -h or -help      display this usage info\n\n");
    
    printf(" -monitor         execute (processing) monitoring logic\n\n");
    
    printf(" -mute            execute muting logic\n");
    printf(" -muteinvert      execute muting inversion logic \n");
    printf(" -authorization   execute authorization logic\n\n");
    
    return;
}

void printESClientError(es_new_client_result_t result)
{
    //err msg
    printf("ERROR: 'es_new_client()' failed with %#x\n", result);
    switch(result){
            
        //not entitled
        case ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED:
            printf("ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED: \"The caller is not properly entitled to connect\"\n\n");
            break;
                  
        //not permitted
        case ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED:
            printf("ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED: \"The caller is not permitted to connect. They lack Transparency, Consent, and Control (TCC) approval form the user.\"\n\n");
            break;
                  
        //not privileged
        case ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED:
            printf("ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED: \"The caller is not running as root\"\n\n");
            break;
            
        default:
            break;
    }
    
    return;
}
