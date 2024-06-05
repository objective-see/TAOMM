/*
 
 NOTE: This is PoC code
   ...don't use in production!
 
 Inspired by: http://newosxbook.com/src.jl?tree=listings&file=netbottom.c

*/

#import <netdb.h>
#import <net/if.h>
#import <Foundation/Foundation.h>
#include <arpa/inet.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

typedef void *NStatSourceRef;
typedef NSObject* NStatManagerRef;

NStatManagerRef NStatManagerCreate (const struct __CFAllocator *, dispatch_queue_t, void (^)(void *, int));


void NStatSourceSetRemovedBlock (NStatSourceRef arg,  void (^)(void));
void NStatSourceSetDescriptionBlock (NStatSourceRef arg,  void (^)(NSDictionary*));

void NStatManagerAddAllTCP(NStatManagerRef manager);
void NStatManagerAddAllUDP(NStatManagerRef manager);

void NStatManagerQueryAllSourcesDescriptions(NStatManagerRef manager, void (^)(void));

void NStatManagerDestroy(NStatManagerRef manager);
void *NStatSourceQueryDescription(NStatSourceRef);
void NStatSourceRemove(NStatSourceRef src);

CFDictionaryRef NStatSourceCopyCounts(NStatSourceRef src);

extern CFStringRef kNStatSrcKeyPID;
extern CFStringRef kNStatSrcKeyLocal;
extern CFStringRef kNStatSrcKeyRemote;
extern CFStringRef kNStatSrcKeyProvider;
extern CFStringRef kNStatSrcKeyTCPState;
extern CFStringRef kNStatSrcKeyInterface;
extern CFStringRef kNStatSrcKeyTxBytes;
extern CFStringRef kNStatSrcKeyRxBytes;

NSString* convertAddress(NSData* data)
{
    //port
    in_port_t port = 0;
    
    //address
    char address[INET6_ADDRSTRLEN] = {0};
    
    //ipv4 struct
    struct sockaddr_in *ipv4 = NULL;
    
    //ipv6 struct
    struct sockaddr_in6 *ipv6 = NULL;
    
    //sanity check
    if(data.length < sizeof(struct sockaddr))
    {
        goto bail;
    }
    
    //IPv4
    if(AF_INET == ((struct sockaddr *)data.bytes)->sa_family) {
        
        //typecast
        ipv4 = (struct sockaddr_in *)[data bytes];
        
        //port
        port = ntohs(ipv4->sin_port);
        
        //addr
        inet_ntop(AF_INET, (const void *)&ipv4->sin_addr, address, INET_ADDRSTRLEN);
    }
    
    //IPv6
    else if (AF_INET6 == ((struct sockaddr *)data.bytes)->sa_family) {
        
        //typecast
        ipv6 = (struct sockaddr_in6 *)[data bytes];
        
        //port
        port = ntohs(ipv6->sin6_port);
        
        //addr
        inet_ntop(AF_INET6, (const void *)&ipv6->sin6_addr, address, INET6_ADDRSTRLEN);
    }
    
bail:
       
    return [NSString stringWithFormat:@"%s:%d", address, port];
}

int main(int argc, const char * argv[]) {
    
    //manager
    NStatManagerRef manager = nil;
    
    //queue to process events
    dispatch_queue_t queue = NULL;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init queue
    queue = dispatch_queue_create("queue", NULL);
    
    //init (wait) semaphore
    semaphore = dispatch_semaphore_create(0);
    
    //init network stat manager
    manager = NStatManagerCreate(kCFAllocatorDefault, queue,
                                  ^(NStatSourceRef source, int unknown)
              {
                    
                    //set description block
                    // for now, just print out description of network
                    NStatSourceSetDescriptionBlock(source, ^(NSDictionary* description)
                    {
                        NSData* source = nil;
                        NSData* destination = nil;
                        
                        //print all
                        printf("%s\n", description.description.UTF8String);
                        
                        //extract/format source addr/port
                        source = description[(__bridge NSString *)kNStatSrcKeyLocal];
                        
                        //not UDP?
                        //extract/format destination addr/port
                        if(YES != [description[(__bridge NSString *)kNStatSrcKeyProvider] isEqualToString:@"UDP"])
                        {
                            //extract
                            destination = description[(__bridge NSString *)kNStatSrcKeyRemote];
                        }
                        
                        //print
                        printf("%s -> %s\n", convertAddress(source).UTF8String, convertAddress(destination).UTF8String);
                        
                    });
              });
        
    
    //watch UDP
    NStatManagerAddAllUDP(manager);
    
    //watch TCP
    NStatManagerAddAllTCP(manager);

    //query all to start
    // when query is done, signal semaphore
    NStatManagerQueryAllSourcesDescriptions(manager, ^{
        
        //trigger semaphore
        dispatch_semaphore_signal(semaphore);
        
    });
    
    //wait for query to complete
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    //cleanup
    NStatManagerDestroy(manager);
    
    return 0;
}
