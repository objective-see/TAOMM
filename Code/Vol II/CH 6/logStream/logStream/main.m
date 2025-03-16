

#import "LogMonitor.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

//log levels
typedef enum {Log_Level_Default, Log_Level_Info, Log_Level_Debug} LogLevels;

/*
https://zearfoss.wordpress.com/2011/04/14/objective-c-quickie-printing-all-declared-properties-of-an-object/ */

void inspectObject(id object)
{
    unsigned int propertyCount = 0 ;
    objc_property_t *properties = class_copyPropertyList([object class], &propertyCount);
     
    for(unsigned int i = 0; i < propertyCount; i++)
    {
        NSString *name = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        
        printf("\n%s: ", name.UTF8String);
         
        //NSLog(@"%@", [object valueForKey:name]);
        
        SEL sel = sel_registerName(name.UTF8String);
        const char *attr = property_getAttributes(properties[i]);
        
        switch(attr[1]) {
            case '@':
                printf("%s\n", [[ ((id (*)(id, SEL))objc_msgSend)(object, sel) description] UTF8String]);
                break;
            
            case 'i':
            case 'I':
                printf("%i\n", ((int (*)(id, SEL))objc_msgSend)(object, sel));
                break;
                
            case 'f':
                printf("%f\n", ((float (*)(id, SEL))objc_msgSend)(object, sel));
                break;
            
            case 'Q':
                printf("%llu\n", ((unsigned long long (*)(id, SEL))objc_msgSend)(object, sel));
                break;
        
            default:
                //printf("%d/%c is unknown type\n", attr[1], attr[1]);
                break;
        }
    }
     
    free(properties);
     
    return;
 
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        NSPredicate* predicate = nil;
        
        //was predicated specified?
        // if so, extract and convert to NSPredicate
        if(2 == argc)
        {
            //grab/init predicate
            // gotta wrap in try, as `predicateWithFormat:` can throw
            @try {
                predicate = [NSPredicate predicateWithFormat:NSProcessInfo.processInfo.arguments.lastObject];
            } @catch (NSException *exception) {
                printf("ERROR: predicate exception: %s\n", exception.description.UTF8String);
            }
            
            //sanity check
            if(nil == predicate)
            {
                //error
                printf("ERROR: invalid usage, please specify a valid predicate\n");
                goto bail;
            }
        }
        //no predicate
        else
        {
            printf("No predicated specified, will match all log messages\n");
            predicate = nil;
        }
        
        LogMonitor* logMonitor = [[LogMonitor alloc] init];

        /*
        [logMonitor start:predicate level:Log_Level_Debug eventHandler:^(OSLogEventProxy* event) {
            
            printf("\n\nNew Log Message:\n");
            inspectObject(event);
            
        }];
        */
        
        [logMonitor startQuery:predicate level:Log_Level_Debug eventHandler:^(OSLogEventProxy* event) {
            
            printf("\n\nExtracted Log Message:\n");
            inspectObject(event);
        
        }];
            
        [NSRunLoop.mainRunLoop run];
    }
    
bail:
    
    return 0;
}
