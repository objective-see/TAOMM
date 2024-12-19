/*
 
 NOTE: This is PoC code
   ...don't use in production!
 
 Based on https://github.com/palominolabs/get_process_handles
    and osquery's process_open_descriptors.cpp

 */

#include <stdio.h>
#include <stdlib.h>
#include <libproc.h>
#include <sys/proc_info.h>

#include <arpa/inet.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>


#import <Foundation/Foundation.h>

//resolve name via (reverse) dns
// based on https://stackoverflow.com/a/3575383
NSString* hostForAddress(char* address)
{
    //name
    NSString* resolvedName = nil;
    
    //results
    struct addrinfo* results = NULL;
    
    //resolved name
    char hostname[NI_MAXHOST] = {0};
    
    //sanity check
    if( (NULL == address) ||
        (0 == strlen(address)) )
    {
        //bail
        goto bail;
    }

    //get addr info
    if(0 == getaddrinfo(address, NULL, NULL, &results)) {
        
        //iterate over each
        // get name info, for host name
        for(struct addrinfo *r = results; r; r = r->ai_next) {
            
            //get name info
            if(0 == getnameinfo(r->ai_addr, r->ai_addrlen, hostname, sizeof(hostname), NULL, 0 , 0)) {
            
                resolvedName = [NSString stringWithUTF8String:hostname];
                break;
            }
        }
    }
    
    //cleanup
    if(NULL != results)
    {
        freeaddrinfo(results);
        results = NULL;
    }
    
bail:
    
    return resolvedName;
}

int main(int argc, const char * argv[]) {
    
    //pid
    pid_t pid = 0;
    
    //size
    int size = 0;
    
    //file descriptor info
    struct proc_fdinfo *fdInfo = NULL;
            
    //grab pid
    pid = NSProcessInfo.processInfo.arguments.lastObject.intValue;
    if(0 == pid)
    {
        //error
        NSLog(@"ERROR: invalid usage, please specify a process identifier (pid)");
        goto bail;
    }
    
    //get size needed to hold list of file descriptors
    size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, 0, 0);
    if(size <= 0)
    {
        //error
        NSLog(@"ERROR: failed to get size for file descriptors (Invalid pid?)");
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
    proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fdInfo, size);
    
    //printf("found %lu file descriptors\n", size/PROC_PIDLISTFD_SIZE);
    
    //iterate over all file descriptors
    // any sockets? extract/parse each one
    for(int i = 0; i < (size/PROC_PIDLISTFD_SIZE); i++) {
            
        //socket info
        struct socket_fdinfo socketInfo = {0};
        
        //UDP
        struct in_sockinfo sockInfo_IN = {0};
        
        //TCP
        struct tcp_sockinfo sockInfo_TCP = {0};
        
        //host
        NSString* host = nil;
        
        //details
        NSMutableDictionary* details = nil;
        
        //source addr
        char source[INET6_ADDRSTRLEN] = {0};
    
        //destination addr
        char destination[INET6_ADDRSTRLEN] = {0};
            
        //only care about sockets
        if(PROX_FDTYPE_SOCKET != fdInfo[i].proc_fdtype) {
                
            //skip
            continue;
        }
            
        //get socket info
        // ignore/skip any that error out
        if(PROC_PIDFDSOCKETINFO_SIZE != proc_pidfdinfo(pid, fdInfo[i].proc_fd, PROC_PIDFDSOCKETINFO, &socketInfo, PROC_PIDFDSOCKETINFO_SIZE)) {
            
            //skip
            continue;
        }

        //only care about AF_INET/6 sockets
        // other types include unix sockets, etc...
        if( (AF_INET != socketInfo.psi.soi_family) &&
            (AF_INET6 != socketInfo.psi.soi_family) )
        {
            //dbg msg
            //printf("skipping non AF_INET/6 socket (family: %d)\n", socketInfo.psi.soi_family);
            
            //skip
            continue;
        }
        
        //printf("file descriptor %d, is a PROX_FDTYPE_SOCKET socket of type AF_INET || AF_INET6\n", fdInfo[i].proc_fd);
            
        details = [NSMutableDictionary dictionary];
        
        //set family
        details[@"family"] = (AF_INET == socketInfo.psi.soi_family) ? @"IPv4" : @"IPv6";
        
        //UDP socket
        if(socketInfo.psi.soi_kind == SOCKINFO_IN) {
            
            //extract
            sockInfo_IN = socketInfo.psi.soi_proto.pri_in;
            
            //save details
            details[@"protocol"] = @"UDP";
            details[@"localPort"] = [NSNumber numberWithUnsignedShort:ntohs(sockInfo_IN.insi_lport)];
            details[@"remotePort"] = [NSNumber numberWithUnsignedShort:ntohs(sockInfo_IN.insi_fport)];
            
            //IPv4
            // get source/destination
            if(AF_INET == socketInfo.psi.soi_family) {
                inet_ntop(AF_INET, &(sockInfo_IN.insi_laddr.ina_46.i46a_addr4), source, sizeof(source));
                inet_ntop(AF_INET, &(sockInfo_IN.insi_faddr.ina_46.i46a_addr4), destination, sizeof(destination));
            }
            
            //IPv6
            // get source/destination
            else {
                inet_ntop(AF_INET6, &(sockInfo_IN.insi_laddr.ina_6), source, sizeof(source));
                inet_ntop(AF_INET6, &(sockInfo_IN.insi_faddr.ina_6), destination, sizeof(destination));
            }
            
            //save details
            details[@"localIP"] = [NSString stringWithUTF8String:source];
            details[@"remoteIP"] = [NSString stringWithUTF8String:destination];
            
            //try get host for address
            host = hostForAddress(destination);
            if(nil != host)
            {
                //set remote host
                details[@"destination host"] = host;
            }
        }
        
        //TCP
        else if (socketInfo.psi.soi_kind == SOCKINFO_TCP) {
           
            //extract
            sockInfo_TCP = socketInfo.psi.soi_proto.pri_tcp;
            
            //save details
            details[@"protocol"] = @"TCP";
            details[@"localPort"] = [NSNumber numberWithUnsignedShort:ntohs(sockInfo_TCP.tcpsi_ini.insi_lport)];
            details[@"remotePort"] = [NSNumber numberWithUnsignedShort:ntohs(sockInfo_TCP.tcpsi_ini.insi_fport)];
            
            //IPv4
            // get source/destination
            if(AF_INET == socketInfo.psi.soi_family) {
                inet_ntop(AF_INET, &(sockInfo_TCP.tcpsi_ini.insi_laddr.ina_46.i46a_addr4), source, sizeof(source));
                inet_ntop(AF_INET, &(sockInfo_TCP.tcpsi_ini.insi_faddr.ina_46.i46a_addr4), destination, sizeof(destination));
            }
            
            //IPv6
            // get source/destination
            else {
                inet_ntop(AF_INET6, &(sockInfo_TCP.tcpsi_ini.insi_laddr.ina_6), source, sizeof(source));
                inet_ntop(AF_INET6, &(sockInfo_TCP.tcpsi_ini.insi_faddr.ina_6), destination, sizeof(destination));
            }
            
            //save details
            details[@"localIP"] = [NSString stringWithUTF8String:source];
            details[@"remoteIP"] = [NSString stringWithUTF8String:destination];
            
            //try get host for address
            host = hostForAddress(destination);
            if(nil != host)
            {
                //set remote host
                details[@"resolved"] = host;
            }
            
            //set (common) states
            // note, we don't check alll states here
            switch(sockInfo_TCP.tcpsi_state) {
                
                case TSI_S_CLOSED:
                    details[@"state"] = @"CLOSED";
                    break;
                
                case TSI_S_LISTEN:
                    details[@"state"] = @"LISTEN";
                    break;
                    
                case TSI_S_SYN_SENT:
                    details[@"state"] = @"SYN_SENT";
                    break;
                
                case TSI_S_ESTABLISHED:
                    details[@"state"] = @"ESTABLISHED";
                    break;
                    
                default:
                    details[@"state"] = [NSString stringWithFormat:@"UNKNOWN (%d)", socketInfo.psi.soi_proto.pri_tcp.tcpsi_state];
                    break;
            }
        }
        
        printf("Socket details: %s\n", details.description.UTF8String);
        
    }

bail:

    //cleanup
    if(NULL != fdInfo)
    {
        free(fdInfo);
        fdInfo = NULL;
    }
    
    return 0;
}
