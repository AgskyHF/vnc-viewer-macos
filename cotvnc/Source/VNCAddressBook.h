//
//  VNCAddressBook.h
//  RealVNC-style VNC client for macOS
//
//  The address book holds saved connections, grouped into folders, and can
//  import and export them in RealVNC's connection-file format.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//

#import <Foundation/Foundation.h>
#import "VNCConnectionProfile.h"

@class VNCAddressBook;

/* Posted when the contents of the address book change. */
extern NSString * const VNCAddressBookDidChangeNotification;

@interface VNCAddressBook : NSObject
{
    NSMutableArray *_profiles;
    NSMutableArray *_groupNames;
    NSMutableDictionary *_groupMembership;
    NSMutableDictionary *_profileGroups;
    NSString *_path;
}

+ (VNCAddressBook *)sharedAddressBook;

/* Directory used for the address book, ~/Library/Application Support/<app>/. */
+ (NSString *)defaultStoragePath;

- (NSString *)path;

/* All saved connections, in display order. */
- (NSArray *)profiles;
- (unsigned)count;
- (VNCConnectionProfile *)profileAtIndex:(unsigned)index;
- (VNCConnectionProfile *)profileNamed:(NSString *)name;

/* Folder (group) names, in display order. */
- (NSArray *)groupNames;
- (NSArray *)profilesInGroup:(NSString *)group;

/* Group membership. A profile with no group belongs to the default group. */
- (NSString *)groupForProfile:(VNCConnectionProfile *)profile;
- (void)setGroup:(NSString *)group forProfile:(VNCConnectionProfile *)profile;

/* Add / remove. Adding a profile with the same name replaces the old one. */
- (BOOL)addProfile:(VNCConnectionProfile *)profile;
- (BOOL)removeProfile:(VNCConnectionProfile *)profile;
- (void)removeAllProfiles;

/* Rename a profile, keeping its group. */
- (BOOL)renameProfile:(VNCConnectionProfile *)profile toName:(NSString *)newName;

/* Add a group (folder). */
- (BOOL)addGroup:(NSString *)groupName;
- (BOOL)removeGroup:(NSString *)groupName;
- (BOOL)hasGroup:(NSString *)groupName;

/* Import: read every connection file (*.vnc) in a directory, recursively.
   Files that cannot be parsed are skipped and reported in errors.
   Returns the number of connections imported, or -1 on failure. */
- (int)importConnectionsFromDirectory:(NSString *)directory
                               errors:(NSMutableArray **)errors;

/* Import: read a single connection file. */
- (BOOL)importConnectionFromFile:(NSString *)path error:(NSString **)error;

/* Export: write every connection into a directory as RealVNC connection
   files, one per connection, grouped into subfolders. Passing nil for
   includePasswords omits the password from the exported files. */
- (BOOL)exportConnectionsToDirectory:(NSString *)directory
                     includePasswords:(BOOL)includePasswords
                               errors:(NSMutableArray **)errors;

/* Export as a single RealVNC-style XML address book, which is the format
   RealVNC itself uses when it exports to XML. */
- (NSData *)xmlRepresentationWithPasswords:(BOOL)includePasswords;
- (BOOL)importFromXMLData:(NSData *)data error:(NSString **)error;

/* Persist to / restore from disk. */
- (BOOL)save;
- (BOOL)load;

@end
