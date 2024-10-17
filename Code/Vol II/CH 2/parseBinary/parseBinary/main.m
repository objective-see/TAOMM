/* 
 
 NOTE: This is PoC code
   ...don't use in production!

 */

#import <mach-o/fat.h>
#import <mach-o/arch.h>
#import <mach-o/swap.h>
#import <mach-o/loader.h>
#import <mach-o/fixup-chains.h>

#if __has_include(<mach-o/utils.h>)
#import <mach-o/utils.h>
#endif

#import <Foundation/Foundation.h>

//fat function definitions
void printFatArch(struct fat_arch* arch);
struct fat_arch* parseFat(const char* file, struct fat_header* header);

//mach-o function definitions
void parseMachO(struct mach_header_64* header, NSUInteger size);
BOOL isEncrypted(struct mach_header_64* header);
void printMachOHeader(struct mach_header_64* header);

BOOL isPackedByEntropy(struct mach_header_64* header, NSUInteger size);
NSMutableSet* isPackedByName(NSMutableArray* segsAndSects);

NSMutableArray* extractSymbols(struct mach_header_64* header);
NSMutableArray* extractChainedSymbols(struct mach_header_64* header);
NSMutableArray* extractDependencies(struct mach_header_64* header);
NSMutableArray* extractSegmentsAndSections(struct mach_header_64* header);
NSMutableArray* findLoadCommand(struct mach_header_64* header, uint32_t cmd);

float calcEntropy(unsigned char* data, NSUInteger length);

int main(int argc, const char * argv[]) {
    
    //binary's data
    NSData* data = nil;

    //fat header
    struct fat_header* fatHeader = NULL;
    
    //best matching architecture
    struct fat_arch* bestArch = NULL;
    
    //mach-O header
    struct mach_header_64* machoHeader = nil;
    
    //size of machO
    NSUInteger machOSize = 0;
    
    //sanity check
    if(2 != argc)
    {
        printf("ERROR: please specify the path to a file\n\n");
        goto bail;
    }
    
    printf("\nParsing: %s\n", argv[1]);
    
    //read in binary
    data = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
    
    //typecast
    fatHeader = (struct fat_header*)data.bytes;
    
    //typecast
    machoHeader = (struct mach_header_64*)data.bytes;
    
    //universal binary?
    // parse and grab best arch and slice
    if( (FAT_MAGIC == fatHeader->magic) ||
        (FAT_CIGAM == fatHeader->magic) )
    {
        printf("\nBinary is universal (fat)\n");
        
        //parse fat
        bestArch = parseFat(argv[1], fatHeader);
        if(NULL == bestArch)
        {
            printf("ERROR: failed to parse/find best slice from universal binary\n\n");
            goto bail;
        }
        
        printf(" Best slice:\n");
        printFatArch(bestArch);
        
        //init best slice
        machoHeader = (struct mach_header_64*)(data.bytes + bestArch->offset);
    
    }
    //for stand-alone mach-O
    // there is only one slice...
    
    if( (MH_MAGIC_64 != machoHeader->magic) ||
        (MH_CIGAM_64 != machoHeader->magic) )
    {
        printf("binary is Mach-O\n");
        
        //set size
        if(NULL != bestArch)
        {
            machOSize = bestArch->size;
        }
        else
        {
            machOSize = data.length;
        }
        
        //parse
        parseMachO(machoHeader, machOSize);
    }
    //invalid file type
    else
    {
        printf("ERROR: file does not appear to a universal nor (64-bit) a Mach-O\n\n");
        goto bail;
    }

    
bail:
    
    return 0;
}

//parse a fat binary
// returning the best arch
struct fat_arch* parseFat(const char* file, struct fat_header* header)
{
    //fat stuff
    struct fat_arch* arch = NULL;
    
    //local architecture
    const NXArchInfo *localArch = NULL;
    
    //best matching slice
    struct fat_arch *bestSlice = NULL;
    
    //get local architecture
    localArch = NXGetLocalArchInfo();

    //swap?
    if(FAT_CIGAM == header->magic)
    {
        //swap fat header
        swap_fat_header(header, localArch->byteorder);
        
        //swap (all) fat arch
        swap_fat_arch((struct fat_arch*)((unsigned char*)header + sizeof(struct fat_header)), header->nfat_arch, localArch->byteorder);
    }
    
    printf("Fat headers\n");
    printf("fat_magic %#x\n", header->magic);
    printf("nfat_arch %x\n",  header->nfat_arch);
    
    arch = (struct fat_arch*)((unsigned char*)header + sizeof(struct fat_header));
    
    //print out each fat_arch structure
    for(uint32_t i = 0; i < header->nfat_arch; i++)
    {
        printf("architecture %d\n", i);
        printFatArch(&arch[i]);
    }
    
    //get best slice
    bestSlice = NXFindBestFatArch(localArch->cputype, localArch->cpusubtype, arch, header->nfat_arch);
    
    //macOS 13+
    // macho_for_each_slice is your friend
    if(@available(macOS 13.0, *)) {
        
        int result = -1;
        __block int count = 0;
        
        printf("\nResults from 'macho_for_each_slice' \n\n");
        
        //iterate over each slice
        result = macho_for_each_slice(file, ^(const struct mach_header *slice, uint64_t offset, size_t size, bool *stop) {
            
            printf("architecture %d\n", count++);
            printf("offset %llu (%#llx)\n", offset, offset);
            printf("size %zu (%#zx)\n", size, size);
            
            printf("name %s\n\n", macho_arch_name_for_mach_header(slice));
            
        });
        if(0 != result) {
            printf("ERROR: macho_for_each_slice failed with %d\n", result);
            
            //more info
            switch (result) {
        
                case EFTYPE:
                    printf("EFTYPE: path exists but it is not a mach-o or fat file\n\n");
                    break;
                    
                case EBADMACHO:
                    printf("EBADMACHO: path is a mach-o file, but it is malformed\n\n");
                    break;
                    
                default:
                    break;
            }
            
            goto bail;
        }
    }

bail:
    
    return bestSlice;
}

//print out a fat (universal) header
void printFatArch(struct fat_arch* arch)
{
    int32_t cpusubtype = 0;
    cpusubtype = arch->cpusubtype & ~CPU_SUBTYPE_MASK;
    
    printf(" cputype %u (%#x)\n", arch->cputype, arch->cputype);
    printf(" cpusubtype %u (%#x)\n", cpusubtype, cpusubtype);
    printf(" capabilities 0x%#x\n", (arch->cpusubtype & CPU_SUBTYPE_MASK) >> 24);
    printf(" offset %u (%#x)\n", arch->offset, arch->offset);
    printf(" size %u (%#x)\n", arch->size, arch->size);
    printf(" align 2^%u (%d)\n", arch->align, (int)pow(2, arch->align));
    
    return;
}

//parse machO
void parseMachO(struct mach_header_64* header, NSUInteger size)
{
    //dependencies (dylibs)
    NSMutableArray* dependencies = nil;
    
    //symbols
    NSMutableArray* symbols = nil;
    
    //segments and sections
    NSMutableArray* segsAndSects = nil;
    
    //packer-related segments or sections
    NSMutableSet* packerSegsOrSects = nil;
    
    //swap?
    if(MH_CIGAM_64 == header->magic)
    {
        //swap
        swap_mach_header_64(header, ((NXArchInfo*)NXGetLocalArchInfo())->byteorder);
    }
    
    //print header
    printMachOHeader(header);
    
    //encrypted?
    printf("is encrypted %d\n", isEncrypted(header));
    
    //extract dependencies
    dependencies = extractDependencies(header);
    printf("Dependencies (count: %lu) %s\n", (unsigned long)dependencies.count, dependencies.description.UTF8String);
    
    //extract symbols
    // default (older) method uses 'LC_SYMTAB'
    if(NULL != [findLoadCommand(header, LC_SYMTAB) firstObject])
    {
        symbols = extractSymbols(header);
    }
    //extract symbols
    // newer method uses 'LC_DYLD_CHAINED_FIXUPS'
    else
    {
        symbols = extractChainedSymbols(header);
    }
    
    printf("Symbols (count %lu) %s\n", (unsigned long)symbols.count, symbols.description.UTF8String);
    
    segsAndSects = extractSegmentsAndSections(header);
    printf("Segments and sections %s\n", segsAndSects.description.UTF8String);
    
    packerSegsOrSects = isPackedByName(segsAndSects);
    if(0 != packerSegsOrSects.count)
    {
        printf("binary appears to be packed\n");
        printf("packer-related section or segment %s detected\n", packerSegsOrSects.description.UTF8String);
    }
    else
    {
        printf("binary does not appear to be packed\n");
        printf("no packer-related section or segment detected\n");
    }
    
    if(YES == isPackedByEntropy(header, size))
    {
        printf("binary appears to be packed\n");
        printf("significant amount of high-entropy data detected\n");
    }
    else
    {
        printf("binary does not appear to be packed\n");
        printf("no signification amount of high-entropy data detected\n");
    }
}

//print out a mach-O header
void printMachOHeader(struct mach_header_64* header)
{
    int32_t cpusubtype = 0;
    cpusubtype = header->cpusubtype & ~CPU_SUBTYPE_MASK;
    
    printf("\nMach-O header\n");
    printf(" magic %#x\n", header->magic);
    printf(" cputype %u (%#x)\n", header->cputype, header->cputype);
    printf(" cpusubtype %u (%#x)\n", cpusubtype, cpusubtype);
    printf(" capabilities %#x\n", (header->cpusubtype & CPU_SUBTYPE_MASK) >> 24);
    
    printf(" filetype %u (%#x)\n", header->filetype, header->filetype);
    
    printf(" ncmds %u\n", header->ncmds);
    printf(" sizeofcmds %u\n", header->sizeofcmds);
    
    printf(" flags %#x\n", header->flags);
    
    return;
}

//all instances of a load command type
NSMutableArray* findLoadCommand(struct mach_header_64* header, uint32_t type)
{
    //load commands
    NSMutableArray* commands = nil;
    
    //current load command
    struct load_command *command = NULL;

    //init
    commands = [NSMutableArray array];
    
    //get first load command
    // ...immediately follows mach-o header
    command = (struct load_command*)((unsigned char*)header + sizeof(struct mach_header_64));
        
    //iterate over all load commands
    for(uint32_t i = 0; i < header->ncmds; i++)
    {
        //match?
        if(type == command->cmd)
        {
            //save
            [commands addObject:[NSValue valueWithPointer:command]];
        }
        
        //got to next load command
        command = (struct load_command *)((unsigned char*)command + command->cmdsize);
    }
    
    return commands;
}

NSMutableSet* isPackedByName(NSMutableArray* segsAndSects)
{
    //command packet section/segments
    NSSet* packers = [NSSet setWithObjects:@"__XHDR", @"upxTEXT", @"__MPRESS__", nil];
    
    //init with all
    NSMutableSet* packedNames = [NSMutableSet setWithArray:segsAndSects];
    [packedNames intersectSet:packers];
    
    return packedNames;

}

BOOL isPackedByEntropy(struct mach_header_64* header, NSUInteger size)
{
    //flag
    BOOL isPacked = NO;
    
    NSMutableArray* commands = nil;
    
    float compressedData = 0.0f;
    
    //get LC_LOAD_DYLIB load command
    commands = findLoadCommand(header, LC_SEGMENT_64);
    
    for(NSValue* command in commands)
    {
        NSString* name = nil;
        float segmentEntropy = 0.0f;
        struct segment_command_64* segment = NULL;
        
        //typecast
        segment = command.pointerValue;
        
        //init name
        name = [[NSString alloc] initWithBytes:segment->segname length:sizeof(segment->segname) encoding:NSASCIIStringEncoding];

        segmentEntropy = calcEntropy(((unsigned char*)header + segment->fileoff), segment->filesize);
        if(segmentEntropy > 7.0f)
        {
            compressedData += segment->filesize;
        }
        
        printf("segment (size: %llu) %s's entropy %f\n", segment->filesize, name.UTF8String, segmentEntropy);
        
    }
    
    printf("total compressed data %f\n", compressedData);
    printf("total compressed data vs. size %f\n", compressedData/size);
    
    //final calculation for architecture
    if((compressedData/size) > .2)
    {
        //set
        isPacked = YES;
    
    }
    
    return isPacked;
}

float calcEntropy(unsigned char* data, NSUInteger length)
{
    //entropy
    float entropy = 0.0f;
    
    //occurances array
    unsigned int occurrences[256] = {0};
    
    //intermediate var
    float pX = 0.0f;
    
    //sanity check
    if(0 == length)
    {
        //bail
        goto bail;
    }
    
    //count all occurances
    for(NSUInteger i = 0; i<length; i++)
    {
        //inc
        occurrences[0xFF & (int)data[i]]++;
    }
    
    //calc entropy
    for(NSUInteger i = 0; i<sizeof(occurrences)/sizeof(occurrences[0]); i++)
    {
        //skip non-occurances
        if(0 == occurrences[i])
        {
            //skip
            continue;
        }
        
        //calc
        pX = occurrences[i]/(float)length;
        entropy -= pX*log2(pX);
    }
    
bail:
    
    return entropy;
}

BOOL isEncrypted(struct mach_header_64* header)
{
    //flag
    BOOL isEncrypted = NO;
    
    //load commands
    NSMutableArray* commands = nil;
    
    //get LC_LOAD_DYLIB load command
    commands = findLoadCommand(header, LC_SEGMENT_64);
    
    for(NSValue* command in commands)
    {
        NSString* name = nil;
        struct segment_command_64* segment = NULL;
        
        //typecast
        segment = command.pointerValue;
        
        name = [[NSString alloc] initWithBytes:segment->segname length:sizeof(segment->segname) encoding:NSASCIIStringEncoding];
        
        printf("segment %s's flags %x\n", name.UTF8String, segment->flags);
        
        //check if segment is protected
        if(SG_PROTECTED_VERSION_1 == (segment->flags & SG_PROTECTED_VERSION_1)) {
             
            //binary has protected (encrypted) segments!
            isEncrypted = YES;
            
            //dbg msg
            printf("'SG_PROTECTED_VERSION_1' set on %s\n", name.UTF8String);
        }
        
    }
    
    return isEncrypted;
}

//extract dependencies
NSMutableArray* extractDependencies(struct mach_header_64* header)
{
    //dependencies
    NSMutableArray* dependencies = nil;
    
    //load command
    NSMutableArray* commands = nil;
    
    //init
    dependencies = [NSMutableArray array];
    
    //get LC_LOAD_DYLIB load command
    commands = findLoadCommand(header, LC_LOAD_DYLIB);
    
    for(NSValue* command in commands)
    {
        char* bytes = NULL;
        uint32_t offset = 0;
        NSString* path = nil;
        NSUInteger length = 0;
        
        struct dylib_command* dependency = NULL;
        
        //typecast
        dependency = command.pointerValue;
        
        //init offset
        offset = dependency->dylib.name.offset;
        
        //init pointer to path's bytes
        bytes = (char*)dependency + offset;
        
        //compute length
        length = dependency->cmdsize-offset;
        
        //covert to string
        path = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
        
        //save
        [dependencies addObject:path];
    }
    
    return dependencies;
}


//extract symbols
// just from LC_SYMTAB (but not from LC_DYSYMTAB)
NSMutableArray* extractSymbols(struct mach_header_64* header)
{
    //symbols
    NSMutableArray* symbols = nil;
    
    //load command
    NSMutableArray* commands = nil;
    
    //LC_SYMTAB load command
    // which is a symtab_command struct
    struct symtab_command* symTableCmd = NULL;
    
    //symbol table
    void* symbolTable = NULL;
    
    //string table
    void* stringTable = NULL;
    
    //structures in symbol table
    struct nlist_64* nlist = NULL;
    
    //init
    symbols = [NSMutableArray array];
    
    //get LC_SYMTAB load command
    commands = findLoadCommand(header, LC_SYMTAB);
    
    //extract LC_SYMTAB command
    symTableCmd = ((NSValue*)commands.firstObject).pointerValue;
    if(NULL == symTableCmd)
    {
        //bail
        goto bail;
    }
    
    //init symbol table
    symbolTable = (((void*)header) + symTableCmd->symoff);
    
    //init string table
    stringTable = (((void*)header) + symTableCmd->stroff);
        
    //init first nlist struct
    nlist = (struct nlist_64*)symbolTable;
    
    //iterate thru all nlists structs
    for(uint32_t i = 0; i < symTableCmd->nsyms; i++)
    {
        //symbol
        char* symbol = NULL;
        symbol = (char*)stringTable + nlist->n_un.n_strx;
        
        //save (non-NULL) symbols
        if(0 != symbol[0])
        {
            //save
            [symbols addObject:[NSString stringWithUTF8String:symbol]];
        }
        
        //next
        nlist++;
    }
   
bail:
    
    return symbols;
}

//extract symbols
// from LC_DYLD_CHAINED_FIXUPS (on newer binaries)
NSMutableArray* extractChainedSymbols(struct mach_header_64* header)
{
    //symbols
    NSMutableArray* symbols = nil;
    
    //load command
    NSMutableArray* commands = nil;
    
    //LC_DYLD_CHAINED_FIXUPS load command
    // which is a linkedit_data_command struct
    struct linkedit_data_command* chainedFixupsCmd = NULL;
    
    //header of the LC_DYLD_CHAINED_FIXUPS
    struct dyld_chained_fixups_header* chainedFixupsHeader = NULL;
    
    //DYLD_CHAINED_IMPORT(s)
    struct dyld_chained_import *imports = NULL;
    
    //chained symbols
    char* chainedSymbols = NULL;
    
    //init
    symbols = [NSMutableArray array];
    
    //get LC_DYLD_CHAINED_FIXUPS load commands
    commands = findLoadCommand(header, LC_DYLD_CHAINED_FIXUPS);
    
    //extract LC_DYLD_CHAINED_FIXUPS command
    chainedFixupsCmd = ((NSValue*)commands.firstObject).pointerValue;
    if(NULL == chainedFixupsCmd)
    {
        goto bail;
    }

    //init header
    chainedFixupsHeader = (((void*)header) + chainedFixupsCmd->dataoff);
    
    //don't support compressed symbols (for now)
    if(1 == chainedFixupsHeader->symbols_format)
    {
        printf("ERROR: extracting of compressed symbols in not currently supported\n\n");
        goto bail;
    }
    
    //init imports
    // from 'imports_offset'
    imports = (struct dyld_chained_import *)((void*)chainedFixupsHeader + chainedFixupsHeader->imports_offset);
    
    //init chained symbols
    // from 'symbols_offset'
    chainedSymbols = (((void*)chainedFixupsHeader) + chainedFixupsHeader->symbols_offset);
    
    //iterate over all
    // grab all symbols
    for (int i = 0; i < chainedFixupsHeader->imports_count; i++) {
        
        char* symbol = chainedSymbols + imports[i].name_offset;
        if(0 != symbol[0])
        {
            //save
            [symbols addObject:[NSString stringWithUTF8String:symbol]];
        }
    }
    
    //TODO: compressed?
    
   
bail:
    
    return symbols;
}

//extract segments
NSMutableArray* extractSegmentsAndSections(struct mach_header_64* header)
{
    //names
    NSMutableArray* names = nil;
    
    //load commands
    NSMutableArray* commands = nil;
    
    //init
    names = [NSMutableArray array];
    
    //nulls
    NSCharacterSet* nullCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\0"];
    
    //get LC_LOAD_DYLIB load command
    commands = findLoadCommand(header, LC_SEGMENT_64);
    
    for(NSValue* command in commands)
    {
        NSString* name = nil;
        
        struct section_64* section = NULL;
        struct segment_command_64* segment = NULL;
    
        //typecast
        segment = command.pointerValue;
        
        //init name
        name = [[NSString alloc] initWithBytes:segment->segname length:sizeof(segment->segname) encoding:NSASCIIStringEncoding];
        name = [name stringByTrimmingCharactersInSet:nullCharacterSet];

        //save
        [names addObject:name];
        
        //first segment
        // starts right after load command
        section = (struct section_64 *)((unsigned char*)segment + sizeof(struct segment_command_64));
        
        for(uint32_t i = 0; i < segment->nsects; i++)
        {
            //init name
            name = [[NSString alloc] initWithBytes:section->sectname length:sizeof(section->sectname) encoding:NSASCIIStringEncoding];
            name = [name stringByTrimmingCharactersInSet:nullCharacterSet];
            
            //save
            [names addObject:name];
            
            //next
            section++;
        }
    }
    
    return names;
}
