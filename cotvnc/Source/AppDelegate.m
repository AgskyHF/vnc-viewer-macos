//
//  AppDelegate.m
//  Chicken of the VNC
//
//  Created by Jason Harris on 8/18/04.
//  Copyright 2004 Geekspiff. All rights reserved.
//

#import "AppDelegate.h"
#import "debug.h"
#import "KeyEquivalentManager.h"
#import "PrefController.h"
#import "ProfileManager.h"
#import "RFBConnectionManager.h"
#import "ListenerController.h"
#import "ServerDataManager.h"
#import "DockConnection.h"
#import "TouchBarController.h"
#import "ServerDataViewController.h"
#import "ServerStandAlone.h"
#import "IServerData.h"
#import "VNCProfileBridge.h"
#import "VNCAddressBook.h"

@implementation AppDelegate

- (id) init
{
    if (self = [super init])
        dockConnections = [[NSMutableArray alloc] init];

    return self;
}

/* This will copy the Chicken of the VNC preferences file to a Chicken file, if
 * the former exists and the latter doesn't. This allows us to inherit Chicken
 * of the VNC preferences the first time we're run. This has to be called before
 * any call to NSUserDefaults. */
- (void)copyCotvncPrefs
{
    NSArray         *libDirs;
    int             i;
    NSFileManager   *fileManager = [NSFileManager defaultManager];

    libDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                  NSUserDomainMask, YES);

    for (i = 0; i < [libDirs count]; i++) {
        NSString    *path = [libDirs objectAtIndex:i];
        NSString    *cotvncPref;
        NSString    *chickenPref;
        
        cotvncPref = [path stringByAppendingPathComponent:
                            @"Preferences/com.geekspiff.chickenofthevnc.plist"];
        chickenPref = [path stringByAppendingPathComponent:
                            @"Preferences/net.sourceforge.chicken.plist"];

        if ([fileManager fileExistsAtPath:cotvncPref]
                && ![fileManager fileExistsAtPath:chickenPref]) {
            BOOL    success;
            success = [fileManager copyItemAtPath:cotvncPref toPath:chickenPref
                                    error:nil];
            if (!success) {
                NSLog(@"Failed to copy %@ to %@", cotvncPref, chickenPref);
            }
        }
    }
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    [self copyCotvncPrefs];
	// make sure our singleton key equivalent manager is initialized, otherwise, it won't watch the frontmost window
	[KeyEquivalentManager defaultManager];
}

- (NSTouchBar *)makeTouchBar
{
    return [[TouchBarController sharedController] makeTouchBar];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	RFBConnectionManager *cm = [RFBConnectionManager sharedManager];

	if ( ! [cm runFromCommandLine] && ! [cm launchedByURL] )
		[cm runNormally];
	
    [mRendezvousMenuItem setState: [[PrefController sharedController] usesRendezvous] ? NSControlStateValueOn : NSControlStateValueOff];
	[mInfoVersionNumber setStringValue: [[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]];
    if ([NSWindow respondsToSelector:@selector(setAllowsAutomaticWindowTabbing:)]) {
        [NSWindow setAllowsAutomaticWindowTabbing:NO];
    }
    if (@available(macOS 10.12.2, *)) {
        [NSApp setTouchBar:[self makeTouchBar]];
    }
}


- (IBAction)showPreferences: (id)sender
{
	[[PrefController sharedController] showWindow];
}

- (BOOL) applicationShouldHandleReopen: (NSApplication *) app hasVisibleWindows: (BOOL) visibleWindows
{
	if(!visibleWindows)
	{
		[self showConnectionDialog:nil];
		return NO;
	}
	
	return YES;
}

- (IBAction)changeRendezvousUse:(id)sender
{
	PrefController *prefs = [PrefController sharedController];
	[prefs toggleUseRendezvous: sender];
	
    [mRendezvousMenuItem setState: [prefs usesRendezvous] ? NSControlStateValueOn : NSControlStateValueOff];
}


- (IBAction)showConnectionDialog: (id)sender
{  [[RFBConnectionManager sharedManager] showConnectionDialog: nil];  }

- (IBAction)showNewConnectionDialog:(id)sender
{  [[RFBConnectionManager sharedManager] showNewConnectionDialog: nil];  }

- (IBAction)showListenerDialog: (id)sender
{  [[ListenerController sharedController] showWindow: nil];  }


- (IBAction)showProfileManager: (id)sender
{  [[ProfileManager sharedManager] showWindow: nil];  }


- (IBAction)showHelp: (id)sender
{
	NSURL *url = [NSURL URLWithString: @"https://ays7.github.io/chicken/"];
	if (url) {
		[[NSWorkspace sharedWorkspace] openURL: url];
	}
}

/* Import connections ---------------------------------------------------- */

- (IBAction)importConnections:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:YES];
    [panel setAllowsMultipleSelection:YES];
    [panel setMessage:@"Choose RealVNC connection files, an XML address book, or a folder of them to import."];
    [panel setPrompt:@"Import"];

    if ([panel runModal] != NSModalResponseOK)
        return;

    NSMutableArray *errors = [NSMutableArray array];
    int total = 0;

    NSArray *urls = [panel URLs];
    NSEnumerator *e = [urls objectEnumerator];
    NSURL *url;
    while ((url = [e nextObject]) != nil)
    {
        NSString *path = [url path];
        NSString *extension = [[path lastPathComponent] pathExtension];

        /* A .vnc file is a single connection; a folder may hold many.
           A .xml file is a RealVNC XML address book with all of them. */
        if ([extension caseInsensitiveCompare:@"xml"] == NSOrderedSame)
        {
            int imported = [VNCProfileBridge importAddressBookFromXMLFile:path
                                                                    errors:&errors];
            if (imported > 0)
                total += imported;
        }
        else if ([extension caseInsensitiveCompare:@"vnc"] == NSOrderedSame)
        {
            NSMutableArray *fileErrors = [NSMutableArray array];
            int imported = [VNCProfileBridge importConnectionsFromDirectory:
                                [path stringByDeletingLastPathComponent]
                                                                     errors:&fileErrors];
            /* The directory import takes every file in the folder, so count
               this one separately when the import brought nothing in. */
            if (imported <= 0)
            {
                NSString *error = nil;
                if ([VNCProfileBridge importConnectionFromFile:path error:&error])
                    total++;
                else if (error != nil)
                    [errors addObject:[NSString stringWithFormat:@"%@: %@",
                                        [path lastPathComponent], error]];
            }
            else
            {
                total += imported;
                [errors addObjectsFromArray:fileErrors];
            }
        }
        else
        {
            int imported = [VNCProfileBridge importConnectionsFromDirectory:path errors:&errors];
            if (imported < 0)
                [errors addObject:[NSString stringWithFormat:@"Cannot read %@", path]];
            else
                total += imported;
        }
    }

    [[ServerDataManager sharedInstance] save];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:[NSString stringWithFormat:@"Imported %d connection(s)", total]];
    if ([errors count] > 0)
        [alert setInformativeText:[NSString stringWithFormat:@"%lu file(s) could not be imported.",
                                  (unsigned long)[errors count]]];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    [alert release];
}

/* Export connections ---------------------------------------------------- */

- (IBAction)exportConnections:(id)sender
{
    /* NSSavePanel cannot choose directories, so the export target is picked
       with an open panel that only accepts folders. */
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanCreateDirectories:YES];
    [panel setMessage:@"Choose a folder to export the address book to."];
    [panel setPrompt:@"Export"];

    if ([panel runModal] != NSModalResponseOK)
        return;

    NSString *directory = [[panel URL] path];
    if (directory == nil)
        return;

    NSAlert *passwordAlert = [[NSAlert alloc] init];
    [passwordAlert setMessageText:@"Include passwords in the exported connections?"];
    [passwordAlert setInformativeText:@"Passwords are stored in your keychain. "
        @"Exported files with passwords should be kept private."];
    [passwordAlert addButtonWithTitle:@"Include Passwords"];
    [passwordAlert addButtonWithTitle:@"Without Passwords"];
    [passwordAlert addButtonWithTitle:@"Cancel"];

    NSModalResponse choice = [passwordAlert runModal];
    [passwordAlert release];

    if (choice != NSAlertFirstButtonReturn && choice != NSAlertSecondButtonReturn)
        return;

    BOOL includePasswords = (choice == NSAlertFirstButtonReturn);

    NSMutableArray *errors = [NSMutableArray array];
    BOOL ok = [VNCProfileBridge exportConnectionsToDirectory:directory
                                           includePasswords:includePasswords
                                                     errors:&errors];
    NSAlert *alert = [[NSAlert alloc] init];
    if (ok)
    {
        [alert setMessageText:@"Connections exported"];
        [alert setInformativeText:[NSString stringWithFormat:
            @"Saved to %@", directory]];
        [alert addButtonWithTitle:@"Show in Finder"];
        [alert addButtonWithTitle:@"OK"];
        if ([alert runModal] == NSAlertFirstButtonReturn)
            [[NSWorkspace sharedWorkspace] selectFile:directory
                                  inFileViewerRootedAtPath:directory];
    }
    else
    {
        [alert setMessageText:@"Export failed"];
        [alert setInformativeText:([errors count] > 0)
            ? [[errors objectAtIndex:0] description]
            : @"Some connections could not be written."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
    [alert release];
}

- (IBAction)exportAddressBookAsXML:(id)sender
{
    /* Export the whole address book as one RealVNC XML file. RealVNC can
       read this format back, so it is the way to move a list of connections
       between machines. */
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setCanCreateDirectories:YES];
    [panel setAllowedFileTypes:@[@"xml"]];
    [panel setNameFieldStringValue:@"VNC Address Book.xml"];
    [panel setMessage:@"Save the address book as a RealVNC XML file."];
    [panel setPrompt:@"Export"];

    if ([panel runModal] != NSModalResponseOK)
        return;

    NSString *path = [[panel URL] path];
    if (path == nil)
        return;

    NSAlert *passwordAlert = [[NSAlert alloc] init];
    [passwordAlert setMessageText:@"Include passwords in the exported address book?"];
    [passwordAlert setInformativeText:@"Passwords are stored in your keychain. "
        @"An address book with passwords should be kept private."];
    [passwordAlert addButtonWithTitle:@"Include Passwords"];
    [passwordAlert addButtonWithTitle:@"Without Passwords"];
    [passwordAlert addButtonWithTitle:@"Cancel"];

    NSModalResponse choice = [passwordAlert runModal];
    [passwordAlert release];

    if (choice != NSAlertFirstButtonReturn && choice != NSAlertSecondButtonReturn)
        return;

    BOOL includePasswords = (choice == NSAlertFirstButtonReturn);

    NSString *error = nil;
    BOOL ok = [VNCProfileBridge exportAddressBookToXMLFile:path
                                          includePasswords:includePasswords
                                                    error:&error];

    NSAlert *alert = [[NSAlert alloc] init];
    if (ok)
    {
        [alert setMessageText:@"Address book exported"];
        [alert setInformativeText:[NSString stringWithFormat:@"Saved to %@", path]];
        [alert addButtonWithTitle:@"Show in Finder"];
        [alert addButtonWithTitle:@"OK"];
        if ([alert runModal] == NSAlertFirstButtonReturn)
            [[NSWorkspace sharedWorkspace] selectFile:path
                                  inFileViewerRootedAtPath:path];
    }
    else
    {
        [alert setMessageText:@"Export failed"];
        [alert setInformativeText:(error != nil) ? error
                              : @"The address book could not be written."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
    [alert release];
}

- (IBAction)setDiagnosticLogLevel:(id)sender
{
    NSInteger level = [sender tag];
    [[NSUserDefaults standardUserDefaults] setInteger:level forKey:@"DiagnosticLoggingLevel"];
    [[NSUserDefaults standardUserDefaults] setBool:(level > DiagnosticLogLevelNone) forKey:@"EnableDiagnosticLogging"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSString *levelName = @"None";
    if (level == DiagnosticLogLevelBasic) {
        levelName = @"Basic";
    } else if (level == DiagnosticLogLevelVerbose) {
        levelName = @"Verbose";
    }
    NSLog(@"[Chicken Fork] Diagnostic logging level set to %@", levelName);
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(setDiagnosticLogLevel:)) {
        DiagnosticLogLevel currentLevel = GetDiagnosticLogLevel();
        [menuItem setState:([menuItem tag] == currentLevel) ? NSControlStateValueOn : NSControlStateValueOff];
        return YES;
    }
    return YES;
}


/* Dock menu-related selectors */

- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	NSMenu              *dockMenu = [[[NSMenu alloc] init] autorelease];
    ServerDataManager   *serverManager = [ServerDataManager sharedInstance];
	NSEnumerator        *enumerator;
	NSString            *s;

	[dockMenu addItemWithTitle:NSLocalizedString(@"ConnectTo", nil)
			  action:nil
			  keyEquivalent:@""];

	enumerator = [[serverManager sortedServerNames] objectEnumerator];
	while (s = [enumerator nextObject]) {
		NSMenuItem	*item =  [dockMenu addItemWithTitle:s
										action:@selector(connectClicked:)
										keyEquivalent:@""];

		[item setTarget:self];
        [item setRepresentedObject:[serverManager getServerWithName:s]];
        [item setIndentationLevel:1];
	}

    if ([dockConnections count] > 0) {
        // Menu items for current dock-initiated connection attempts.
        [dockMenu addItem:[NSMenuItem separatorItem]];
        [dockConnections makeObjectsPerformSelector:@selector(addMenuItems:)
                withObject:dockMenu];
    }

    return dockMenu;
}	

- (void)connectClicked: (id)sender
{
    DockConnection      *conn;

    conn = [[DockConnection alloc] initWithServer:[sender representedObject]];
    [dockConnections addObject:conn];
    [conn release];
}

- (void)addDockConnection:(DockConnection *)conn
{
    [dockConnections addObject:conn];
}

- (void)removeDockConnection: (DockConnection *)conn
{
    /* This selector is called by the object conn itself. We want to make sure
     * that the object continues to exist, even though we're about to remove it
     * from our array. */
    [[conn retain] autorelease];
    [dockConnections removeObject:conn];
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    /* A RealVNC connection file: open it as a connection, exactly like
       double-clicking an exported connection file does in RealVNC. */
    if ([[filename pathExtension] caseInsensitiveCompare:@"vnc"] == NSOrderedSame)
    {
        NSString *error = nil;
        if (![VNCProfileBridge importConnectionFromFile:filename error:&error])
        {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Cannot open this connection file"];
            [alert setInformativeText:(error != nil) ? error
                                  : @"The file is not a valid RealVNC connection file."];
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            [alert release];
            return NO;
        }

        [[ServerDataManager sharedInstance] save];

        /* Start the connection that was just imported. */
        VNCConnectionProfile *profile = [VNCConnectionProfile profileFromFileAtPath:filename
                                                                               error:NULL];
        if (profile != nil)
        {
            NSString *name = [profile friendlyName];
            if ([name length] == 0)
                name = [[filename lastPathComponent] stringByDeletingPathExtension];
            [[RFBConnectionManager sharedManager] connectToSavedServerByName:name];
        }
        return YES;
    }

    if ([[filename pathExtension] caseInsensitiveCompare:@"rdp"] == NSOrderedSame)
    {
        NSStringEncoding encoding = 0;
        NSError *error = nil;
        NSString *content = [NSString stringWithContentsOfFile:filename usedEncoding:&encoding error:&error];
        if (!content && error)
        {
            // Fallback to UTF-8 or ASCII if usedEncoding could not detect
            content = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:nil];
        }

        NSString *host = nil;
        int port = 3389;
        NSString *user = nil;
        NSString *domain = nil;
        int audioMode = 0; // Default: 0 = play on this computer

        if (content)
        {
            NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            for (NSString *rawLine in lines)
            {
                NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([line length] == 0 || [line hasPrefix:@"#"])
                    continue;

                if ([line hasPrefix:@"full address:s:"])
                {
                    host = [line substringFromIndex:[@"full address:s:" length]];
                }
                else if ([line hasPrefix:@"server port:i:"])
                {
                    NSString *portStr = [line substringFromIndex:[@"server port:i:" length]];
                    port = [portStr intValue];
                }
                else if ([line hasPrefix:@"username:s:"])
                {
                    user = [line substringFromIndex:[@"username:s:" length]];
                }
                else if ([line hasPrefix:@"domain:s:"])
                {
                    domain = [line substringFromIndex:[@"domain:s:" length]];
                }
                else if ([line hasPrefix:@"audiomode:i:"])
                {
                    NSString *modeStr = [line substringFromIndex:[@"audiomode:i:" length]];
                    audioMode = [modeStr intValue];
                }
            }
        }

        ServerStandAlone *server = [[ServerStandAlone alloc] init];
        [server setRemoteProtocol:RemoteProtocolRDP];
        [server setRdpAudioMode:audioMode];
        if (host)
        {
            [server setHostAndPort:host];
            if ([server port] == 0 || [server port] == 5900)
                [server setPort:port];
        }
        else
        {
            [server setPort:port];
        }

        if (domain && [domain length] > 0 && user && [user length] > 0 && [user rangeOfString:@"\\"].location == NSNotFound)
        {
            [server setUsername:[NSString stringWithFormat:@"%@\\%@", domain, user]];
        }
        else if (user)
        {
            [server setUsername:user];
        }

        [server setProfileName:@"Windows"];

        ServerDataViewController *viewCtrlr = [[ServerDataViewController alloc] initWithReleaseOnCloseOrConnect];
        [viewCtrlr setServer:server];
        [[viewCtrlr window] makeKeyAndOrderFront:self];
        [server release];
        [viewCtrlr release];
        return YES;
    }
    return NO;
}

@end
