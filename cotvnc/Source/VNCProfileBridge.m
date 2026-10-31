//
//  VNCProfileBridge.m
//  RealVNC-style VNC client for macOS
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//

#import "VNCProfileBridge.h"
#import "ServerFromPrefs.h"
#import "ServerDataManager.h"
#import "ServerBase.h"
#import "VNCAddressBook.h"

@implementation VNCProfileBridge

+ (VNCConnectionProfile *)profileFromServer:(id<IServerData>)server
{
    if (server == nil)
        return nil;

    VNCConnectionProfile *profile = [[[VNCConnectionProfile alloc] init] autorelease];

    [profile setFriendlyName:[server name]];
    [profile setHost:[server host]];

    int port = [server port];
    [profile setPort:[NSString stringWithFormat:@"%d", port]];

    [profile setConnMethod:VNCConnMethodTCP];

    if ([server username] != nil && [[server username] length] > 0)
        [profile setUsername:[server username]];

    if ([server viewOnly])
        [profile setViewOnly:@"1"];
    if ([server shared])
        [profile setShared:@"1"];

    /* The password is only exported when the server actually remembers it. */
    if ([server rememberPassword] && [server password] != nil)
        [profile setPassword:[server password]];

    return profile;
}

+ (id<IServerData>)serverFromProfile:(VNCConnectionProfile *)profile
{
    return [self serverFromProfile:profile addToList:NO];
}

+ (id<IServerData>)serverFromProfile:(VNCConnectionProfile *)profile
                              addToList:(BOOL)addToList
{
    if (profile == nil)
        return nil;

    NSString *host = [profile host];
    if (host == nil || [host length] == 0)
        return nil;

    ServerDataManager *manager = [ServerDataManager sharedInstance];

    NSString *name = [profile friendlyName];
    if (name == nil || [name length] == 0)
        name = host;

    ServerFromPrefs *server = nil;

    if (addToList)
    {
        /* Reuse an existing connection with the same name if there is one. */
        id<IServerData> existing = [manager getServerWithName:name];
        if (existing != nil)
            server = (ServerFromPrefs *)[manager addServer:existing];
        else
            server = [manager createServerByName:name];
    }
    else
    {
        server = [ServerFromPrefs createWithName:name];
    }

    if (server == nil)
        return nil;

    /* Host and port. The port may be given as a number or as a display
       number ("0" meaning display 0, i.e. port 5900). */
    NSString *portString = [profile port];
    if ([portString length] > 0)
    {
        int port = [portString intValue];
        if (port > 0 && port < 100)
            port = 5900 + port;
        [server setPort:port];
    }
    [server setHost:host];

    if ([profile username] != nil && [[profile username] length] > 0)
        [server setUsername:[profile username]];

    if ([[profile viewOnly] isEqualToString:@"1"])
        [server setViewOnly:YES];

    if ([[profile shared] isEqualToString:@"1"])
        [server setShared:YES];

    /* The password is stored in the keychain when the connection is set to
       remember it. */
    if ([profile password] != nil && [[profile password] length] > 0)
    {
        [server setPassword:[profile password]];
        [server setRememberPassword:YES];
    }

    return server;
}

+ (BOOL)importConnectionFromFile:(NSString *)path error:(NSString **)error
{
    if (path == nil)
    {
        if (error) *error = @"No file given";
        return NO;
    }

    NSString *localError = nil;
    VNCConnectionProfile *profile = [VNCConnectionProfile profileFromFileAtPath:path
                                                                           error:&localError];
    if (profile == nil)
    {
        if (error) *error = localError ? localError : @"Cannot read connection file";
        return NO;
    }

    if ([[profile friendlyName] length] == 0)
        [profile setFriendlyName:[[path lastPathComponent] stringByDeletingPathExtension]];

    if ([self serverFromProfile:profile addToList:YES] == nil)
    {
        if (error) *error = @"Cannot create the connection";
        return NO;
    }

    if (error) *error = nil;
    return YES;
}

+ (int)importConnectionsFromDirectory:(NSString *)directory
                               errors:(NSMutableArray **)errors
{
    if (directory == nil)
        return -1;

    VNCAddressBook *book = [[[VNCAddressBook alloc] init] autorelease];

    int imported = [book importConnectionsFromDirectory:directory errors:errors];
    if (imported < 0)
        return -1;

    /* Move the imported connections into the app's own server list. */
    NSArray *profiles = [book profiles];
    unsigned i;
    for (i = 0; i < [profiles count]; i++)
    {
        VNCConnectionProfile *profile = [profiles objectAtIndex:i];
        id<IServerData> server = [self serverFromProfile:profile addToList:YES];

        /* The folder the connection came from becomes an address book
           folder, so that the layout of the imported directory is kept. */
        NSString *group = [book groupForProfile:profile];
        if ([group length] > 0 && server != nil)
        {
            ServerDataManager *manager = [ServerDataManager sharedInstance];
            [manager createGroup:group];
            [manager moveServer:server toGroup:group];
        }
    }

    [[ServerDataManager sharedInstance] save];

    return imported;
}

+ (int)importAddressBookFromXMLFile:(NSString *)path
                              errors:(NSMutableArray **)errors
{
    if (path == nil)
        return -1;

    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil)
    {
        if (errors != nil && *errors != nil)
            [*errors addObject:[NSString stringWithFormat:@"Cannot read %@", path]];
        return -1;
    }

    VNCAddressBook *book = [[[VNCAddressBook alloc] init] autorelease];

    NSString *parseError = nil;
    if (![book importFromXMLData:data error:&parseError])
    {
        if (errors != nil && *errors != nil)
            [*errors addObject:[NSString stringWithFormat:@"%@: %@",
                                [path lastPathComponent],
                                parseError ? parseError : @"Cannot read the address book"]];
        return -1;
    }

    /* Move the imported connections into the app's own server list, keeping
       the folder each one came from. */
    NSArray *profiles = [book profiles];
    unsigned i;
    int imported = 0;
    for (i = 0; i < [profiles count]; i++)
    {
        VNCConnectionProfile *profile = [profiles objectAtIndex:i];
        id<IServerData> server = [self serverFromProfile:profile addToList:YES];
        if (server == nil)
            continue;

        NSString *group = [book groupForProfile:profile];
        if ([group length] > 0)
        {
            ServerDataManager *manager = [ServerDataManager sharedInstance];
            [manager createGroup:group];
            [manager moveServer:server toGroup:group];
        }
        imported++;
    }

    [[ServerDataManager sharedInstance] save];

    return imported;
}

+ (BOOL)exportAddressBookToXMLFile:(NSString *)path
                   includePasswords:(BOOL)includePasswords
                             error:(NSString **)error
{
    if (path == nil)
    {
        if (error) *error = @"No file given";
        return NO;
    }

    VNCAddressBook *book = [[[VNCAddressBook alloc] init] autorelease];

    ServerDataManager *manager = [ServerDataManager sharedInstance];

    NSEnumerator *e = [manager getServerEnumeratorForGroupName:@"All"];
    id<IServerData> server;
    while ((server = [e nextObject]) != nil)
    {
        VNCConnectionProfile *profile = [self profileFromServer:server];
        if (profile == nil)
            continue;

        [book addProfile:profile];

        /* Keep the folder the connection lives in. */
        NSString *group = [manager groupForServer:server];
        if ([group length] > 0
            && ![group isEqualToString:@"Standard"]
            && ![group isEqualToString:@"All"]
            && ![group isEqualToString:@"Rendezvous"])
        {
            [book addGroup:group];
            [book setGroup:group forProfile:profile];
        }
    }

    NSData *xml = [book xmlRepresentationWithPasswords:includePasswords];
    if (xml == nil)
    {
        if (error) *error = @"Could not serialise the address book";
        return NO;
    }

    if (![xml writeToFile:path atomically:YES])
    {
        if (error) *error = [NSString stringWithFormat:@"Cannot write %@", path];
        return NO;
    }

    if (error) *error = nil;
    return YES;
}

+ (BOOL)exportConnectionsToDirectory:(NSString *)directory
                     includePasswords:(BOOL)includePasswords
                               errors:(NSMutableArray **)errors
{
    if (directory == nil)
        return NO;

    VNCAddressBook *book = [[[VNCAddressBook alloc] init] autorelease];

    ServerDataManager *manager = [ServerDataManager sharedInstance];

    /* Every server, including the ones in the address book folders. */
    NSEnumerator *e = [manager getServerEnumeratorForGroupName:@"All"];
    id<IServerData> server;

    while ((server = [e nextObject]) != nil)
    {
        VNCConnectionProfile *profile = [self profileFromServer:server];
        if (profile == nil)
            continue;

        [book addProfile:profile];

        /* Keep the folder the connection lives in. */
        NSString *group = [manager groupForServer:server];
        if ([group length] > 0
            && ![group isEqualToString:@"Standard"]
            && ![group isEqualToString:@"All"]
            && ![group isEqualToString:@"Rendezvous"])
        {
            [book addGroup:group];
            [book setGroup:group forProfile:profile];
        }
    }

    return [book exportConnectionsToDirectory:directory
                             includePasswords:includePasswords
                                       errors:errors];
}

@end
