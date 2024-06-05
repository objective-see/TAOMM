//
//  shared.d
//  enumerateProcesses
//
//  Created by Patrick Wardle on 3/13/24.
//

#ifndef shared_h
#define shared_h

#import <Foundation/Foundation.h>

#define STDERR @"stdError"
#define STDOUT @"stdOutput"
#define EXIT_CODE @"exitCode"

NSMutableDictionary* execTask(NSString* binaryPath, NSArray* arguments);


#endif /* shared__h */
