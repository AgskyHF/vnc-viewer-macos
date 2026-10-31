//
//  VNCProfileBridge.h
//  RealVNC-style VNC client for macOS
//
//  Converts between the app's own server model and the RealVNC connection
//  file format, so that connections can be imported from and exported to
//  RealVNC.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//

#import <Foundation/Foundation.h>
#import "IServerData.h"
#import "VNCConnectionProfile.h"

@interface VNCProfileBridge : NSObject

/* Build a RealVNC connection profile from one of the app's servers. */
+ (VNCConnectionProfile *)profileFromServer:(id<IServerData>)server;

/* Build an app server from a RealVNC connection profile. The name is used
   as the display name of the new connection. */
+ (id<IServerData>)serverFromProfile:(VNCConnectionProfile *)profile;

/* Build an app server from a profile, adding it to the saved server list so
   that it appears in the address book. */
+ (id<IServerData>)serverFromProfile:(VNCConnectionProfile *)profile
                              addToList:(BOOL)addToList;

/* Import a directory of RealVNC connection files into the saved server list.
   Returns the number of connections imported, or -1 on failure. */
+ (int)importConnectionsFromDirectory:(NSString *)directory
                               errors:(NSMutableArray **)errors;

/* Import a single RealVNC connection file into the saved server list. */
+ (BOOL)importConnectionFromFile:(NSString *)path error:(NSString **)error;

/* Import a RealVNC XML address book into the saved server list.
   Returns the number of connections imported, or -1 on failure. */
+ (int)importAddressBookFromXMLFile:(NSString *)path
                              errors:(NSMutableArray **)errors;

/* Export the saved server list into a directory of RealVNC connection files. */
+ (BOOL)exportConnectionsToDirectory:(NSString *)directory
                     includePasswords:(BOOL)includePasswords
                               errors:(NSMutableArray **)errors;

/* Export the saved server list as a RealVNC XML address book file.
   Returns NO on failure. */
+ (BOOL)exportAddressBookToXMLFile:(NSString *)path
                   includePasswords:(BOOL)includePasswords
                             error:(NSString **)error;

@end
