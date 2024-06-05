//
//  main.h
//  ESPlayground
//

#ifndef main_h
#define main_h

@import Cocoa;
@import Foundation;
@import EndpointSecurity;

void usage(void);

BOOL monitor(void);

BOOL mute(void);
BOOL protect(void);
BOOL muteInvert(void);
BOOL authorization(void);

void printESClientError(es_new_client_result_t result);

#endif /* main_h */
