//
//  AppDelegate.h
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DockConnection;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuItemValidation> {
	IBOutlet NSMenuItem *mRendezvousMenuItem;
	IBOutlet NSTextField *mInfoVersionNumber;

	
    NSMutableArray      *dockConnections;
}

- (IBAction)showPreferences: (id)sender;
- (IBAction)changeRendezvousUse:(id)sender;
- (IBAction)showNewConnectionDialog:(id)sender;
- (IBAction)showConnectionDialog: (id)sender;
- (IBAction)showListenerDialog: (id)sender;
- (IBAction)showProfileManager: (id)sender;
- (IBAction)showHelp: (id)sender;
- (IBAction)setDiagnosticLogLevel:(id)sender;

/* Import RealVNC connection files into the address book. */
- (IBAction)importConnections:(id)sender;
/* Export the address book as RealVNC connection files. */
- (IBAction)exportConnections:(id)sender;



- (NSMenu *)applicationDockMenu:(NSApplication *)sender;
- (void)addDockConnection:(DockConnection *)conn;
- (void)removeDockConnection:(DockConnection *)conn;

@end
