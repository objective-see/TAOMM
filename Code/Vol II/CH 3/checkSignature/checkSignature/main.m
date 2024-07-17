/*
 
 NOTE: This is PoC code
   ...don't use in production!

 */

#import "packageKit.h"

#import <libproc.h>
#import <sys/types.h>
#import <sys/proc_info.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

//from: codesign.h / cs_blobs.h
#define CS_ADHOC  0x0000002

//signature keys
#define KEY_SIGNING_FLAGS @"flags"
#define KEY_SIGNING_NOTARIZED @"notarized"
#define KEY_SIGNATURE_STATUS @"signatureStatus"
#define KEY_SIGNING_AUTHORITIES @"signingAuthorities"

typedef uint64_t SecAssessmentTicketFlags;
enum {
    kSecAssessmentTicketFlagDefault = 0,                // default behavior, offline check
    kSecAssessmentTicketFlagForceOnlineCheck = 1 << 0,    // force an online check
    kSecAssessmentTicketFlagLegacyListCheck = 1 << 1, // Check the DeveloperID Legacy list
};

Boolean SecAssessmentTicketLookup(CFDataRef hash, SecCSDigestAlgorithm hashType, SecAssessmentTicketFlags flags, double *date, CFErrorRef *errors);

typedef struct _SecAssessment *SecAssessmentRef;
typedef uint64_t SecAssessmentFlags;

SecAssessmentRef SecAssessmentCreate(CFURLRef path,
    SecAssessmentFlags flags,
    CFDictionaryRef context,
    CFErrorRef *errors);

enum {
    kSecAssessmentDefaultFlags = 0,                    // default behavior

    kSecAssessmentFlagDirect = 1 << 30,                // in-process evaluation
    kSecAssessmentFlagAsynchronous = 1 << 29,        // request asynchronous operation
    kSecAssessmentFlagIgnoreCache = 1 << 28,        // do not search cache
    kSecAssessmentFlagNoCache = 1 << 27,            // do not populate cache
    kSecAssessmentFlagEnforce = 1 << 26,            // force on (disable bypass switches)
    kSecAssessmentFlagAllowWeak = 1 << 25,            // allow weak signatures
    kSecAssessmentFlagIgnoreWhitelist = 1 << 24,    // do not search weak signature whitelist
    // 1 << 23 removed (was kSecAssessmentFlagDequarantine)
    kSecAssessmentFlagIgnoreActiveAssessments = 1 << 22, // permit parallel re-assessment of the same target
    kSecAssessmentFlagLowPriority = 1 << 21,        // run the assessment in low priority
};

//function defs
NSData* getAuditToken(NSNumber* pid);

NSMutableDictionary* checkItem(NSString* item);
NSMutableDictionary* checkPackage(NSString* package);
NSMutableDictionary* checkProcess(NSData* auditToken);

NSNumber* isPackageNotarized(PKArchiveSignature* signature);

int main(int argc, const char * argv[]) {
    
    //return
    int status = -1;
    
    //signature status
    int signingStatus = -1;
        
    //item
    NSString* item = nil;
    
    //pid
    NSNumber* pid = nil;
    
    //results
    NSMutableDictionary* results = nil;
    
    //sanity check
    if(2 != argc)
    {
        printf("\nERROR: please specify a path to item to check\n\n");
        goto bail;
    }
    
    //user-specified item
    item = NSProcessInfo.processInfo.arguments.lastObject;
    
    //maybe its a pid
    pid = [[[NSNumberFormatter alloc] init] numberFromString:item];
    
    //dbg msg
    printf("Checking: %s\n\n", item.lastPathComponent.UTF8String);
    
    //pkg?
    if(NSOrderedSame == [item.pathExtension caseInsensitiveCompare:@"pkg"])
    {
        //check pkg
        results = checkPackage(item);
    }
    //pid?
    else if(nil != pid)
    {
        results = checkProcess(getAuditToken(pid));
    }
    //everything else...
    else
    {
        //check
        results = checkItem(item);
    }
    
    //error?
    if(nil == results[KEY_SIGNATURE_STATUS])
    {
        printf("ERROR: failed to check signature\n\n");
        goto bail;
    }
    
    //print results
    switch (signingStatus = [results[KEY_SIGNATURE_STATUS] intValue]) {
        
        case errSecSuccess:
            
            //ad-hoc?
            if([results[KEY_SIGNING_FLAGS] intValue] & CS_ADHOC)
            {
                printf("Status: signed, but ad-hoc\n");
            }
            else
            {
                printf("Status: signed\n");
            }
            
            //notarization
            switch([results[KEY_SIGNING_NOTARIZED] intValue])
            {
                case YES:
                    printf("Notarized: yes\n");
                    break;
                case NO:
                    printf("Notarized: no\n");
                    break;
                case CSSMERR_TP_CERT_REVOKED:
                case errSecCSRevokedNotarization:
                    printf("Notarized: revoked\n");
                    break;
            }
            
            //signing auths
            if(NULL != results[KEY_SIGNING_AUTHORITIES])
            {
                printf("Signing authorities: %s\n", [[results[KEY_SIGNING_AUTHORITIES] description] UTF8String]);
            }
            break;
        
        case errSecCSUnsigned:
            printf("Status: unsigned\n");
            break;
        
        case CSSMERR_TP_CERT_REVOKED:
        case errSecCSRevokedNotarization:
            printf("Status: certificate revoked\n");
            
            if(NULL != results[KEY_SIGNING_AUTHORITIES])
            {
                printf("Signing authorities: %s\n", [[results[KEY_SIGNING_AUTHORITIES] description] UTF8String]);
            }
            break;
            
        default:
            printf("Status: unknown (%d/%#x)\n", signingStatus, signingStatus);
            break;
    }
    
    status = 0;
        
bail:
    return status;
}

//get signing info of item
// e.g. disk image, app, binary
NSMutableDictionary* checkItem(NSString* item)
{
    //info dictionary
    NSMutableDictionary* signingInfo = nil;
    
    //item url
    CFURLRef itemURL = NULL;
    
    //code ref
    SecStaticCodeRef staticCode = NULL;
    
    //status
    OSStatus status = -1;
    
    //flags
    SecCSFlags flags = 0;
    
    //TODO:?
    //extracted flags
    NSNumber* csFlags = nil;
    
    //sec assesment
    SecAssessmentRef secAssesment = NULL;
    
    //signing information
    CFDictionaryRef signingDetails = NULL;
    
    //is notarized requirement
    static SecRequirementRef isNotarized = nil;

    //init signing status
    signingInfo = [NSMutableDictionary dictionary];
    
    //convert to url
    itemURL = (__bridge CFURLRef)([NSURL fileURLWithPath:item]);
    
    //create static code ref
    status = SecStaticCodeCreateWithPath(itemURL, kSecCSDefaultFlags, &staticCode);
    if(errSecSuccess != status)
    {
        //err msg
        printf("ERROR: SecStaticCodeCreateWithPath failed with %d/%#x\n\n", status, status);
        goto bail;
    }
    
    //set flags
    flags = kSecCSEnforceRevocationChecks;
    
    //not .dmg?
    // likely app/binary, check all archs
    if(NSOrderedSame != [item.pathExtension caseInsensitiveCompare:@"dmg"])
    {
        flags |= kSecCSCheckAllArchitectures;
    }
    
    //check signature
    status = SecStaticCodeCheckValidity(staticCode, flags, NULL);
    
    //save signature status
    signingInfo[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    if(errSecSuccess != status)
    {
        //bail
        goto bail;
    }

    //save signing auths
    status = SecCodeCopySigningInformation(staticCode, kSecCSSigningInformation, &signingDetails);
    if(errSecSuccess != status)
    {
        //err msg
        printf("ERROR: SecCodeCopySigningInformation failed with %d/%#x\n\n", status, status);
        goto bail;
    }
    
    //grab flags
    signingInfo[KEY_SIGNING_FLAGS] = [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoFlags];
    
    //grab certificate authority chain
    signingInfo[KEY_SIGNING_AUTHORITIES] = [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoCertificates];
    
    //init requirement string
    SecRequirementCreateWithString(CFSTR("notarized"), kSecCSDefaultFlags, &isNotarized);
    
    //check notarization status
    if(errSecSuccess == SecStaticCodeCheckValidity(staticCode, flags, isNotarized))
    {
        //notarized
        signingInfo[KEY_SIGNING_NOTARIZED] = [NSNumber numberWithBool:YES];
    }
    //failed
    // but maybe cuz it's revoked?
    else
    {
        //error
        CFErrorRef error = nil;
        
        //default to no
        signingInfo[KEY_SIGNING_NOTARIZED] = [NSNumber numberWithBool:NO];
        
        //asses
        secAssesment = SecAssessmentCreate(itemURL, kSecAssessmentDefaultFlags, (__bridge CFDictionaryRef)(@{}), &error);
        if(NULL == secAssesment)
        {
            if( (CSSMERR_TP_CERT_REVOKED == CFErrorGetCode(error)) ||
                (errSecCSRevokedNotarization == CFErrorGetCode(error)) )
            {
                signingInfo[KEY_SIGNING_NOTARIZED] = [NSNumber numberWithInteger:errSecCSRevokedNotarization];
            }
        }
    }

bail:
    
    //free assement
    if(NULL != secAssesment)
    {
        CFRelease(secAssesment);
        secAssesment = NULL;
    }
    
    //free signing info
    if(NULL != signingDetails)
    {
        //free
        CFRelease(signingDetails);
        signingDetails = NULL;
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
        staticCode = NULL;
    }
    
    return signingInfo;
}

//get signing info of item
// e.g. disk image, app, binary
NSMutableDictionary* checkProcess(NSData* auditToken)
{
    //dynamic code ref
    SecCodeRef dynamicCode = NULL;
    
    //attribues
    NSDictionary* attributes = NULL;
    
    //path
    CFURLRef path = nil;
    
    //info dictionary
    NSMutableDictionary* signingInfo = nil;
    
    //status
    OSStatus status = -1;
    
    //flags
    SecCSFlags flags = 0;
    
    //sec assesment
    SecAssessmentRef secAssesment = NULL;
    
    //signing information
    CFDictionaryRef signingDetails = NULL;
    
    //is notarized requirement
    static SecRequirementRef isNotarized = nil;

    //init signing status
    signingInfo = [NSMutableDictionary dictionary];
    
    /*
    //init attributes with pid
    attributes = @{(__bridge NSString *)kSecGuestAttributePid:pid};
    */
    
    attributes = @{(__bridge NSString *)kSecGuestAttributeAudit:auditToken};
    
    status = SecCodeCopyGuestWithAttributes(0, (__bridge CFDictionaryRef _Nullable)(attributes), kSecCSDefaultFlags, &dynamicCode);
    if(errSecSuccess != status)
    {
        //err msg
        NSLog(@"ERROR: SecCodeCopyGuestWithAttributes failed with %d/%#x", status, status);
        goto bail;
    }
    
    //validate code
    status = SecCodeCheckValidity(dynamicCode, flags, NULL);
    signingInfo[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    if(errSecSuccess != status)
    {
        //bail
        goto bail;
    }
    
    //save signing auths
    status = SecCodeCopySigningInformation(dynamicCode, kSecCSSigningInformation, &signingDetails);
    if(errSecSuccess != status)
    {
        //error
        NSLog(@"ERROR: SecCodeCopySigningInformation failed with %d/%#x", status, status);
        goto bail;
    }
        
    //grab certificate authority chain
    signingInfo[KEY_SIGNING_AUTHORITIES] = [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoCertificates];
    
    //init requirement string
    SecRequirementCreateWithString(CFSTR("notarized"), kSecCSDefaultFlags, &isNotarized);
    
    //check notarization status
    if(errSecSuccess == SecCodeCheckValidity(dynamicCode, kSecCSDefaultFlags, isNotarized))
    {
        //notarized
        signingInfo[KEY_SIGNING_NOTARIZED] = [NSNumber numberWithBool:YES];
    }
    //failed
    // ...can't be running if revoked, so just set to 'NO'
    else
    {
        //default to no
        signingInfo[KEY_SIGNING_NOTARIZED] = [NSNumber numberWithBool:NO];
    }

bail:
    
    //free assement
    if(NULL != secAssesment)
    {
        CFRelease(secAssesment);
        secAssesment = NULL;
    }
    
    //free signing info
    if(NULL != signingDetails)
    {
        CFRelease(signingDetails);
        signingDetails = NULL;
    }
    
    //free static code
    if(NULL != dynamicCode)
    {
        CFRelease(dynamicCode);
        dynamicCode = NULL;
    }
    
    //free path
    if(NULL != path)
    {
        CFRelease(path);
        path = NULL;
    }
    
    return signingInfo;
}

//check signing info for .pkg
NSMutableDictionary* checkPackage(NSString* package)
{
    //info dictionary
    NSMutableDictionary* info = nil;
    
    //bundle
    NSBundle* packageKit = nil;
    
    //class
    Class PKArchiveCls = nil;
    
    //archive
    PKXARArchive* archive = nil;
    
    //error
    NSError* error = nil;
    
    //signatures
    NSArray* signatures = nil;
    
    //(leaf?) signature
    PKArchiveSignature* signature = nil;
    
    //signature trust ref
    struct __SecTrust* trustRef = NULL;
    
    //class
    Class PKTrustCls = nil;
    
    //trust
    PKTrust* pkTrust = nil;
   
    //init
    info = [NSMutableDictionary dictionary];
    
    //default
    // covers error cases
    info[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:errSecCSInternalError];
    
    //load packagekit framework
    if(YES != [packageKit = [NSBundle bundleWithPath:PACKAGE_KIT] load])
    {
        //bail
        goto bail;
    }
    
    //`PKArchive` class
    if(nil == (PKArchiveCls = NSClassFromString(@"PKArchive")))
    {
        //bail
        goto bail;
    }
    
    //sanity check
    // method: 'archiveWithPath:'
    if(YES != [PKArchiveCls respondsToSelector:@selector(archiveWithPath:)])
    {
        //bail
        goto bail;
    }
    
    //init archive from .pkg
    if(nil == (archive = [PKArchiveCls archiveWithPath:package]))
    {
        //bail
        goto bail;
    }
    
    //sanity check
    // method: 'verifyReturningError:'
    if(YES != [archive respondsToSelector:@selector(verifyReturningError:)])
    {
        //bail
        goto bail;
    }
    
    //basic validation
    // this checks checksum, etc
    if(YES != [archive verifyReturningError:&error])
    {
        //bail
        goto bail;
    }
    
    //sanity check
    // iVar: `archiveSignatures`
    if(YES != [archive respondsToSelector:NSSelectorFromString(@"archiveSignatures")])
    {
        //bail
        goto bail;
    }

    //extract signatures
    signatures = archive.archiveSignatures;
    if(0 == signatures.count)
    {
        //unsigned!
        info[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:errSecCSUnsigned];
        
        //bail
        goto bail;
    }
    
    //extract leaf signature
    signature = signatures.firstObject;
    
    //sanity check
    if(YES != [signature respondsToSelector:@selector(verifySignedDataReturningError:)])
    {
        //bail
        goto bail;
    }
    
    //validate leaf (child?) signature
    if(YES != [signature verifySignedDataReturningError:&error])
    {
        //bail
        goto bail;
    }
    
    //sanity check
    if(YES != [signature respondsToSelector:NSSelectorFromString(@"verificationTrustRef")])
    {
        //bail
        goto bail;
    }
    
    //'PKTrust' class
    PKTrustCls = NSClassFromString(@"PKTrust");
    if(nil == PKTrustCls)
    {
        //bail
        goto bail;
    }
    
    //alloc pk trust
    pkTrust = [PKTrustCls alloc];
    
    //extract signature trust ref
    trustRef = [signature verificationTrustRef];
    
    //validate via trust ref
    if(nil != trustRef)
    {
        //sanity check
        if(YES != [pkTrust respondsToSelector:@selector(initWithSecTrust:usingAppleRoot:signatureDate:)])
        {
            //bail
            goto bail;
        }
        
        //init
        pkTrust = [pkTrust initWithSecTrust:trustRef usingAppleRoot:YES signatureDate:archive.archiveSignatureDate];
        if(NULL == pkTrust)
        {
            //bail
            goto bail;
        }
    }
    //validate via certs
    else
    {
        //sanity check
        if(YES != [pkTrust respondsToSelector:@selector(initWithCertificates:usingAppleRoot:signatureDate:)])
        {
            //bail
            goto bail;
        }
        
        //init
        pkTrust = [pkTrust initWithCertificates:signature.certificateRefs usingAppleRoot:YES signatureDate:archive.archiveSignatureDate];
        if(NULL == pkTrust)
        {
            //bail
            goto bail;
        }
    }
    
    //sanity check
    // object support: `evaluateTrustReturningError`?
    if(YES != [pkTrust respondsToSelector:@selector(evaluateTrustReturningError:)])
    {
        //bail
        goto bail;
    }
    
    //validate
    if(YES != [pkTrust evaluateTrustReturningError:&error])
    {
        //save error
        info[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInteger:error.code];
    }
    //happily signed
    else
    {
        //save
        info[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:errSecSuccess];
    }
    
    //add signing certs
    // want these even if they are revoked
    if(nil != signature.certificateRefs)
    {
        //add
        info[KEY_SIGNING_AUTHORITIES] = signature.certificateRefs;
    }
    
    //set notarization
    info[KEY_SIGNING_NOTARIZED] = [NSNumber numberWithBool:isPackageNotarized(signature)];
    
bail:
    
    return info;
}

//check if pkg is notarized
NSNumber* isPackageNotarized(PKArchiveSignature* signature)
{
    //error
    CFErrorRef error = nil;
    
    //flag
    NSNumber* notarizated = nil;

    //date
    double notarizationDate = 0;

    //hash
    NSData* itemHash = nil;
    
    //algo type
    SecCSDigestAlgorithm hashType = 0;
    
    //get hash
    itemHash = [signature signedDataReturningAlgorithm:0x0];
    if(0 == itemHash.length)
    {
        //bail
        goto bail;
    }
        
    //SHA1 hash
    if(CC_SHA1_DIGEST_LENGTH == itemHash.length)
    {
        //SHA1
        hashType = kSecCodeSignatureHashSHA1;
    }
    //SHA256 hash
    else if(CC_SHA256_DIGEST_LENGTH == itemHash.length)
    {
        //SHA256
        hashType = kSecCodeSignatureHashSHA256;
    }
    
    //sanity check
    if(0 == hashType)
    {
        //bail
        goto bail;
    }
    
    //notarization check
    // first via kSecAssessmentTicketFlagDefault
    if(YES == SecAssessmentTicketLookup((__bridge CFDataRef)(itemHash), hashType, kSecAssessmentTicketFlagDefault, &notarizationDate, &error))
    {
        //set
        notarizated = @1;
    }
    //notarization check
    // also via kSecAssessmentTicketFlagForceOnlineCheck
    else if(YES == SecAssessmentTicketLookup((__bridge CFDataRef)(itemHash), hashType, kSecAssessmentTicketFlagForceOnlineCheck, &notarizationDate, &error))
    {
        //set
        notarizated = @1;
    }
    
    //error?
    else if(NULL != error)
    {
        notarizated = @0;
        
        //revoked?
        if(EACCES == CFErrorGetCode(error))
        {
            notarizated = [NSNumber numberWithInteger:errSecCSRevokedNotarization];
        }
    }

bail:

    return notarizated;
}

NSData* getAuditToken(NSNumber* pid)
{
    task_name_t task = {0};
    kern_return_t status = 0;
    mach_msg_type_number_t info_size = TASK_AUDIT_TOKEN_COUNT;
    
    audit_token_t token = { 0 };
    NSData* auditToken = nil;

    status = task_name_for_pid(mach_task_self(), pid.intValue, &task);
    if(KERN_SUCCESS != status)
    {
        printf("ERROR: task_name_for_pid failed with %d/%#x\n\n", status, status);
        goto bail;
    }
    
    status = task_info(task, TASK_AUDIT_TOKEN, (integer_t *)&token, &info_size);
    if(KERN_SUCCESS != status) 
    {
        printf("ERROR: task_info failed with %d/%#x\n\n", status, status);
        goto bail;
    }

    auditToken = [NSData dataWithBytes:&token length:sizeof(audit_token_t)];
    
bail:
    
    return auditToken;
}
