//
//  AppDelegate.m
//  FileMonitor
//
//  Created by Patrick Wardle on 10/17/19.
//  Copyright © 2020 Patrick Wardle. All rights reserved.
//

#import "AppDelegate.h"

/* DEFINES */
@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

//center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    return;
}

//make close button first responder
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    //first responder
    [self.window makeFirstResponder:[self.window.contentView viewWithTag:1]];
}

//exit on window close
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

//close app
-(IBAction)close:(id)sender {
    
    //close
    // will trigger exit
    [self.window close];
}

@end
