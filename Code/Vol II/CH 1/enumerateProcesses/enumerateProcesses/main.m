/*
 
 NOTE: This is PoC code
   ...don't use in production!

 */

#import <dlfcn.h>
#import <libproc.h>
#import <sys/sysctl.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

//architectures
enum Architectures{ArchUnknown, ArchAppleSilicon, ArchIntel};

/* FUNCTION DEFS */

NSMutableArray* getFiles(pid_t pid);
NSMutableArray* getFiles2(pid_t pid);
NSMutableArray* getLibraries(pid_t pid);

//get a list of process ids
NSMutableArray* getProcessIDs(void)
{
    //process IDs
    NSMutableArray* processIDs = nil;
    
    //processes
    int32_t processesCount = 0;

    //length of variable
    size_t length = 0;
    
    //array of pids
    pid_t* pids = NULL;
    
    //init array
    processIDs = [NSMutableArray array];
    
    //get max number of processes
    length = sizeof(processesCount);
    if(0 != sysctlbyname("kern.maxproc", &processesCount, &length, NULL, 0))
    {
        //bail
        goto bail;
    }
    
    //alloc buffer for all processes
    pids = calloc((unsigned long)processesCount, sizeof(pid_t));
    if(NULL == pids)
    {
        //bail
        goto bail;
    }
    
    //get list of processes
    processesCount = proc_listallpids(pids, processesCount * (int)sizeof(pid_t));
    if(processesCount <= 0)
    {
        //bail
        goto bail;
    }
    
    //save each pid into an (NS)array
    for(int i = 0; i<processesCount; i++)
    {
        //add
        [processIDs addObject:[NSNumber numberWithInt:pids[i]]];
    }
    
bail:
    
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
        pids = NULL;
    }
    
    return processIDs;
}

//get audit token for a process
NSData* getAuditToken(pid_t pid)
{
    NSData* auditToken = nil;
    
    task_name_t task = MACH_PORT_NULL;
    
    audit_token_t token = {0};
    kern_return_t status = 0;
    mach_msg_type_number_t info_size = TASK_AUDIT_TOKEN_COUNT;

    //get task for process
    status = task_name_for_pid(mach_task_self(), pid, &task);
    if(KERN_SUCCESS != status)
    {
        //err
        printf("\nERROR: task_name_for_pid failed with %d/%#x\n\n", status, status);
        goto bail;
    }
    
    //get task info
    status = task_info(task, TASK_AUDIT_TOKEN, (integer_t *)&token, &info_size);
    if(KERN_SUCCESS != status)
    {
        //err
        printf("\nERROR: 'task_info' failed with %d/%#x\n\n", status, status);
        goto bail;
    }

    auditToken = [NSData dataWithBytes:&token length:sizeof(audit_token_t)];
    
bail:
    
    //deallocate task
    if(MACH_PORT_NULL != task)
    {
        mach_port_deallocate(mach_task_self(), task);
    }
    
    return auditToken;
}


//given a pid, get its parent (ppid)
pid_t getParent(pid_t pid)
{
    //parent id
    pid_t parent = 0;
    
    //kinfo_proc struct
    struct kinfo_proc processStruct;
    
    //size
    size_t procBufferSize = sizeof(processStruct);
    
    //syscall result
    int sysctlResult = -1;
    
    //init mib
    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    
    //clear buffer
    memset(&processStruct, 0x0, procBufferSize);
    
    //make syscall
    sysctlResult = sysctl(mib, sizeof(mib) / sizeof(mib[0]), &processStruct, &procBufferSize, NULL, 0);
    
    //check if got ppid
    if( (0 == sysctlResult) &&
        (0 != procBufferSize) )
    {
        //save ppid
        parent = processStruct.kp_eproc.e_ppid;
    }
    
    return parent;
}

//get responsible pid via 'responsibility_get_pid_responsible_for_pid'
pid_t getResponsibleParent(pid_t child)
{
    pid_t parent = 0;
    
    pid_t (*getRPID)(pid_t pid) = dlsym(RTLD_DEFAULT, "responsibility_get_pid_responsible_for_pid");
    if(NULL != getRPID)
    {
        parent = getRPID(child);
    }
    
    return parent;

}

//get (true) parent
pid_t getASParent(pid_t pid)
{
    pid_t parent = 0;
    
    //process info
    NSDictionary* processInfo = nil;
    
    //process serial number
    ProcessSerialNumber psn = {kNoProcess, kNoProcess};
    
    //(parent) process serial number
    ProcessSerialNumber ppsn = {kNoProcess, kNoProcess};
    
    OSStatus status = 0;

    status = GetProcessForPID(pid, &psn);
    if(noErr != status)
    {
        //error
        printf("\nERROR: 'GetProcessForPID' failed with %d\n\n", status);
        goto bail;
    }
    
    //get process (carbon) info
    processInfo = CFBridgingRelease(ProcessInformationCopyDictionary(&psn, (UInt32)kProcessDictionaryIncludeAllInformationMask));
    if(nil == processInfo)
    {
        //error
        printf("\nERROR: 'ProcessInformationCopyDictionary' failed\n\n");
        goto bail;
    }
    
    //extract/convert parent ppsn
    ppsn.lowLongOfPSN =  [processInfo[@"ParentPSN"] longLongValue] & 0x00000000FFFFFFFFLL;
    ppsn.highLongOfPSN = ([processInfo[@"ParentPSN"] longLongValue] >> 32) & 0x00000000FFFFFFFFLL;
    
    //get parent process (carbon) info
    processInfo = CFBridgingRelease(ProcessInformationCopyDictionary(&ppsn, (UInt32)kProcessDictionaryIncludeAllInformationMask));
    if(nil == processInfo)
    {
        //error
        printf("ERROR: 'ProcessInformationCopyDictionary' failed with %d\n\n", status);
        goto bail;
    }
    
    //extract pid
    parent = [processInfo[@"pid"] intValue];
    
bail:

    return parent;
}


//extract commandline args
// saves into 'arguments' ivar
NSMutableArray* getArguments(pid_t pid)
{
    //args
    NSMutableArray* arguments = nil;
    
    //'management info base' array
    int mib[3] = {0};
    
    //system's size for max args
    int systemMaxArgs = 0;
    
    //process's args
    char* processArgs = NULL;
    
    //# of args
    int numberOfArgs = 0;
    
    //arg
    NSString* argument = nil;
    
    //start of (each) arg
    char* argStart = NULL;
    
    //size of buffers, etc
    size_t size = 0;
    
    //parser pointer
    char* parser = NULL;
    
    //init
    arguments = [NSMutableArray array];
    
    //init mib
    // want system's size for max args
    mib[0] = CTL_KERN;
    mib[1] = KERN_ARGMAX;
    
    //set size
    size = sizeof(systemMaxArgs);
    
    //get system's size for max args
    if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0))
    {
        //bail
        goto bail;
    }
    
    //alloc space for args
    processArgs = malloc(systemMaxArgs);
    if(NULL == processArgs)
    {
        //bail
        goto bail;
    }
    
    //init mib
    // want process args
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROCARGS2;
    mib[2] = pid;
    
    //set size
    size = (size_t)systemMaxArgs;
    
    //get process's args
    if(-1 == sysctl(mib, 3, processArgs, &size, NULL, 0))
    {
        //bail
        goto bail;
    }
    
    //sanity check
    // ensure buffer is somewhat sane
    if(size <= sizeof(int))
    {
        //bail
        goto bail;
    }
    
    //extract number of args
    // found at start of buffer
    memcpy(&numberOfArgs, processArgs, sizeof(numberOfArgs));
    
    //init pointer to start of args
    // they start right after # of args
    parser = processArgs + sizeof(numberOfArgs);
    
    //scan until end of process's NULL-terminated path
    while(parser < &processArgs[size])
    {
        //scan till NULL-terminator
        if(0x0 == *parser)
        {
            //end of exe name
            break;
        }
        
        //next char
        parser++;
    }
    
    //sanity check
    // make sure end-of-buffer wasn't reached
    if(parser == &processArgs[size])
    {
        //bail
        goto bail;
    }
    
    //skip all trailing NULLs
    // scan will end when non-NULL is found
    while(parser < &processArgs[size])
    {
        //scan till NULL-terminator
        if(0x0 != *parser)
        {
            //ok, got to argv[0]
            break;
        }
        
        //next char
        parser++;
    }
    
    //sanity check
    // (again), make sure end-of-buffer wasn't reached
    if(parser == &processArgs[size])
    {
        //bail
        goto bail;
    }
    
    //parser should now point to argv[0], process name
    // init arg start
    argStart = parser;
    
    //keep scanning until all args are found
    // each is NULL-terminated
    while(parser < &processArgs[size])
    {
        //each arg is NULL-terminated
        // so scan till NULL, then save into array
        if(*parser == '\0')
        {
            //save arg
            if(NULL != argStart)
            {
                //try convert
                // ignore (if not UTF8, etc...)
                argument = [NSString stringWithUTF8String:argStart];
                if(nil != argument)
                {
                    //save
                    [arguments addObject:argument];
                }
            }
            
            //init string pointer to (possibly) next arg
            argStart = ++parser;
            
            //bail if we've hit arg cnt
            if(arguments.count == numberOfArgs)
            {
                //bail
                break;
            }
        }
        
        //next char
        parser++;
    }
    
bail:
    
    //free process args
    if(NULL != processArgs)
    {
        //free
        free(processArgs);
        
        //unset
        processArgs = NULL;
    }
    
    return arguments;
}

NSString* getProcessPath(pid_t pid)
{
    char path[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //get path
    proc_pidpath(pid, path, PROC_PIDPATHINFO_MAXSIZE);

    return [NSString stringWithUTF8String:path];
}


NSString* getProcessName(pid_t pid)
{
    NSString* name = nil;
    NSRunningApplication* application = nil;
    char path[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //try get app info
    application = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    if(nil != application)
    {
        //get bundle
        NSBundle* bundle = [NSBundle bundleWithURL:application.bundleURL];
        if(nil != bundle)
        {
            //name
            name = bundle.infoDictionary[@"CFBundleName"];
        }
    }

    //not an app
    else
    {
        //get path
        proc_pidpath(pid, path, PROC_PIDPATHINFO_MAXSIZE);
        
        //covert to string
        name = [NSString stringWithUTF8String:path].lastPathComponent;
    }
    
    return name;
}

//get start time
NSDate* getStartTime(pid_t pid)
{
    //start time
    NSDate* startTime = nil;
    
    //time value
    struct timeval timeVal = {0};
    
    //kinfo_proc struct
    struct kinfo_proc processStruct;
    
    //size
    size_t procBufferSize = sizeof(processStruct);

    //syscall result
    int sysctlResult = -1;
    
    //init mib
    int mib[0x4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    
    //clear buffer
    memset(&processStruct, 0x0, procBufferSize);
    
    //make syscall
    sysctlResult = sysctl(mib, 0x4, &processStruct, &procBufferSize, NULL, 0);
    if( (noErr == sysctlResult) &&
        (0 != procBufferSize) )
    {
        //save start time
        timeVal = processStruct.kp_proc.p_un.__p_starttime;
        
        //covert
        startTime = [NSDate dateWithTimeIntervalSince1970:timeVal.tv_sec + timeVal.tv_usec / 1.0e6];
    }
    
    return startTime;
}

//get process' architecture
NSUInteger getArchitecture(pid_t pid)
{
    //architecuture
    NSUInteger arch = ArchUnknown;
    
    //type
    cpu_type_t type = -1;
    
    //size
    size_t size = 0;
    
    //mib
    int mib[CTL_MAXNAME] = {0};
    
    //length
    size_t length = CTL_MAXNAME;
    
    //proc info
    struct kinfo_proc procInfo = {0};
    
    //get mib for 'proc_cputype'
    if(noErr != sysctlnametomib("sysctl.proc_cputype", mib, &length))
    {
        //bail
        goto bail;
    }
    
    //add pid
    mib[length] = pid;
    
    //inc length
    length++;
    
    //init size
    size = sizeof(cpu_type_t);
    
    //get CPU type
    if(noErr != sysctl(mib, (u_int)length, &type, &size, 0, 0))
    {
        //bail
        goto bail;
    }
    
    //reversing Activity Monitor
    // if CPU type is CPU_TYPE_X86_64, Apple sets architecture to 'Intel'
    if(CPU_TYPE_X86_64 == type)
    {
        //intel
        arch = ArchIntel;
        
        //done
        goto bail;
    }
    
    //reversing Activity Monitor
    // if CPU type is CPU_TYPE_ARM64, Apple checks proc's p_flags
    // if P_TRANSLATED is set, then they set architecture to 'Intel'
    if(CPU_TYPE_ARM64 == type)
    {
        //default to apple
        arch = ArchAppleSilicon;
        
        //(re)init mib
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROC;
        mib[2] = KERN_PROC_PID;
        mib[3] = pid;
        
        //(re)set length
        length = 4;
        
        //(re)set size
        size = sizeof(procInfo);
        
        //get proc info
        if(noErr != sysctl(mib, (u_int)length, &procInfo, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //'P_TRANSLATED' set?
        // set architecture to 'Intel'
        if(P_TRANSLATED == (P_TRANSLATED & procInfo.kp_proc.p_flag))
        {
            //intel
            arch = ArchIntel;
        }
    }
    
bail:
    
    return arch;
}

//get CPU usage
double getCPUUsage(pid_t pid, int delta)
{
    int status = -1;
    
    int64_t cpuTime = 0;
    double cpuUsage = 0.0f;

    mach_timebase_info_data_t timebase = {0};
    
    struct rusage_info_v0 resourceInfo_1 = {0};
    struct rusage_info_v0 resourceInfo_2 = {0};
    
    status = proc_pid_rusage((pid_t)pid, RUSAGE_INFO_V0, (rusage_info_t *)&resourceInfo_1);
    if(noErr != status)
    {
        //error
        printf("ERROR 'proc_pid_rusage' failed with %d/%#x", status, status);
        goto bail;
    }
    
    sleep(delta);
    
    status = proc_pid_rusage((pid_t)pid, RUSAGE_INFO_V0, (rusage_info_t *)&resourceInfo_2);
    if(noErr != status)
    {
        //error
        printf("ERROR 'proc_pid_rusage' failed with %d/%#x", status, status);
        goto bail;
    }
    
    //get time base info
    mach_timebase_info(&timebase);
    
    //compute CPU time
    cpuTime = (resourceInfo_2.ri_user_time - resourceInfo_1.ri_user_time) + (resourceInfo_2.ri_system_time - resourceInfo_1.ri_system_time);
    
    //convert to nanaseconds
    cpuTime = (cpuTime * timebase.numer) / timebase.denom;

    //convert to percentage
    cpuUsage = (double)cpuTime / delta / NSEC_PER_SEC * 100;
    
bail:
    
    return cpuUsage;
    
}

//get all the infoz
void examineProcess(pid_t pid)
{
    pid_t ppid = 0;
    pid_t rpid = 0;
    pid_t cpid = 0;
    
    NSData* auditToken = nil;
    
    double cpuUsage = 0;
    NSDate* startTime = nil;
    NSUInteger architecture = ArchUnknown;
    
    NSMutableArray* files = nil;
    NSMutableArray* libraries = nil;
    
    //get audit token
    // though here we don't do anything with it here...
    auditToken = getAuditToken(pid);
    
    printf("(%d):%s\n\n", pid, getProcessPath(pid).UTF8String);
    
    printf(" name: %s\n", getProcessName(pid).UTF8String);
    printf(" arguments: %s\n", getArguments(pid).description.UTF8String);
    
    architecture = getArchitecture(pid);
    printf(" architecture: %s\n", (architecture == ArchAppleSilicon) ? "Apple Silicon" : "Intel");
    
    ppid = getParent(pid);
    printf(" parent: (%d) %s\n", ppid, getProcessName(ppid).UTF8String);
    
    rpid = getResponsibleParent(pid);
    printf(" responsible parent: (%d) %s\n", rpid, getProcessName(rpid).UTF8String);
    
    cpid = getASParent(pid);
    if(0 != cpid)
    {
        printf(" application services parent: (%d) %s\n", cpid, getProcessName(cpid).UTF8String);
    }
    else
    {
        printf(" application services parent not found!\n");
    }
    
    startTime = getStartTime(pid);
    printf(" start time: %s\n", startTime.description.UTF8String);
    
    //uncomment if you want CPU usage
    
    /*
    cpuUsage = getCPUUsage(pid, 5);
    printf(" cpu usage: %f%%\n", cpuUsage);
    */
     
    //uncomment if you want loaded libraries and open files usage
    
    /*
    libraries = getLibraries(pid);
    printf(" loaded libraries: %s\n", libraries.description.UTF8String);
    
    files = getFiles(pid);
    printf(" open files (via 'proc_pidinfo'): %s\n", files.description.UTF8String);
    
    files = getFiles2(pid);
    printf(" open files (via 'lsof'): %s\n", files.description.UTF8String);
    */
    
    return;
}

int main(int argc, const char * argv[]) {
    
    NSNumber* pid = nil;
    NSMutableArray* pids = nil;

    //user specified a pid?
    if(2 == argc)
    {
        //maybe its a pid
        pid = [NSNumber numberWithInt:atoi(argv[1])];
        examineProcess(pid.intValue);
    }
    
    //enumerate all
    else
    {
        //get pids
        pids = getProcessIDs();
        printf("Found %lu running processes\n", (unsigned long)pids.count);
        
        //examine each pid
        for(NSNumber* pid in pids)
        {
            examineProcess(pid.intValue);
        }
    }
    return 0;
}


