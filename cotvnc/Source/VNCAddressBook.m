//
//  VNCAddressBook.m
//  RealVNC-style VNC client for macOS
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//

#import "VNCAddressBook.h"

NSString * const VNCAddressBookDidChangeNotification = @"VNCAddressBookDidChangeNotification";

static VNCAddressBook * gSharedAddressBook = nil;

@implementation VNCAddressBook

+ (VNCAddressBook *)sharedAddressBook
{
    if (gSharedAddressBook == nil)
    {
        gSharedAddressBook = [[self alloc] init];
        [gSharedAddressBook load];
    }
    return gSharedAddressBook;
}

+ (NSString *)defaultStoragePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                         NSUserDomainMask, YES);
    NSString *base = ([paths count] > 0) ? [paths objectAtIndex:0]
                                         : [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    return [base stringByAppendingPathComponent:@"VNCViewer"];
}

- (id)init
{
    if (self = [super init])
    {
        _profiles = [[NSMutableArray alloc] init];
        _groupNames = [[NSMutableArray alloc] init];
        _groupMembership = [[NSMutableDictionary alloc] init];
        _profileGroups = [[NSMutableDictionary alloc] init];
        _path = [[[self class] defaultStoragePath] retain];
    }
    return self;
}

- (void)dealloc
{
    [_profiles release];
    [_groupNames release];
    [_groupMembership release];
    [_profileGroups release];
    [_path release];
    [super dealloc];
}

- (NSString *)path
{
    return _path;
}

- (void)notifyChanged
{
    [[NSNotificationCenter defaultCenter] postNotificationName:VNCAddressBookDidChangeNotification
                                                        object:self];
}

/* Lookup helper: a profile is identified by its friendly name. */
- (NSString *)keyForProfile:(VNCConnectionProfile *)profile
{
    NSString *name = [profile friendlyName];
    if (name == nil || [name length] == 0)
        name = [profile displayAddress];
    return name;
}

- (NSArray *)profiles
{
    return [[_profiles copy] autorelease];
}

- (unsigned)count
{
    return (unsigned)[_profiles count];
}

- (VNCConnectionProfile *)profileAtIndex:(unsigned)index
{
    if (index >= [_profiles count])
        return nil;
    return [_profiles objectAtIndex:index];
}

- (VNCConnectionProfile *)profileNamed:(NSString *)name
{
    unsigned i;
    for (i = 0; i < [_profiles count]; i++)
    {
        VNCConnectionProfile *p = [_profiles objectAtIndex:i];
        if ([[p friendlyName] isEqualToString:name])
            return p;
    }
    return nil;
}

- (NSArray *)groupNames
{
    return [[_groupNames copy] autorelease];
}

- (NSString *)groupForProfile:(VNCConnectionProfile *)profile
{
    NSString *group = [_profileGroups objectForKey:[self keyForProfile:profile]];
    if (group == nil)
        return @"";
    return group;
}

- (void)setGroup:(NSString *)group forProfile:(VNCConnectionProfile *)profile
{
    NSString *key = [self keyForProfile:profile];
    if (group == nil || [group length] == 0)
        [_profileGroups removeObjectForKey:key];
    else
        [_profileGroups setObject:group forKey:key];
    [self notifyChanged];
}

- (NSArray *)profilesInGroup:(NSString *)group
{
    NSMutableArray *result = [NSMutableArray array];
    unsigned i;
    for (i = 0; i < [_profiles count]; i++)
    {
        VNCConnectionProfile *p = [_profiles objectAtIndex:i];
        if ([[self groupForProfile:p] isEqualToString:group])
            [result addObject:p];
    }
    return result;
}

- (BOOL)addProfile:(VNCConnectionProfile *)profile
{
    if (profile == nil)
        return NO;

    NSString *key = [self keyForProfile:profile];

    /* Replace an existing connection with the same name. */
    VNCConnectionProfile *existing = [self profileNamed:[profile friendlyName]];
    if (existing != nil)
    {
        NSString *group = [self groupForProfile:existing];
        [_profiles removeObject:existing];
        [_profileGroups removeObjectForKey:[self keyForProfile:existing]];
        if ([group length] > 0)
            [_profileGroups setObject:group forKey:key];
    }

    [_profiles addObject:profile];
    [_profileGroups setObject:@"" forKey:key];
    [self notifyChanged];
    return YES;
}

- (BOOL)removeProfile:(VNCConnectionProfile *)profile
{
    if (profile == nil)
        return NO;
    if (![_profiles containsObject:profile])
        return NO;
    [_profiles removeObject:profile];
    [_profileGroups removeObjectForKey:[self keyForProfile:profile]];
    [self notifyChanged];
    return YES;
}

- (void)removeAllProfiles
{
    [_profiles removeAllObjects];
    [_profileGroups removeAllObjects];
    [self notifyChanged];
}

- (BOOL)renameProfile:(VNCConnectionProfile *)profile toName:(NSString *)newName
{
    if (profile == nil || newName == nil || [newName length] == 0)
        return NO;

    NSString *oldKey = [self keyForProfile:profile];
    NSString *group = [_profileGroups objectForKey:oldKey];

    [_profileGroups removeObjectForKey:oldKey];
    [profile setFriendlyName:newName];
    NSString *newKey = [self keyForProfile:profile];
    if (group != nil)
        [_profileGroups setObject:group forKey:newKey];
    else
        [_profileGroups setObject:@"" forKey:newKey];

    [self notifyChanged];
    return YES;
}

- (BOOL)hasGroup:(NSString *)groupName
{
    return [_groupNames containsObject:groupName];
}

- (BOOL)addGroup:(NSString *)groupName
{
    if (groupName == nil || [groupName length] == 0)
        return NO;
    if ([self hasGroup:groupName])
        return NO;
    [_groupNames addObject:groupName];
    [self notifyChanged];
    return YES;
}

- (BOOL)removeGroup:(NSString *)groupName
{
    if (![self hasGroup:groupName])
        return NO;

    [_groupNames removeObject:groupName];

    /* Profiles in the group move back to the default group. */
    NSMutableArray *keys = [NSMutableArray array];
    NSDictionary *membership = [NSDictionary dictionaryWithDictionary:_profileGroups];
    NSArray *allKeys = [membership allKeys];
    unsigned i;
    for (i = 0; i < [allKeys count]; i++)
    {
        NSString *key = [allKeys objectAtIndex:i];
        if ([[membership objectForKey:key] isEqualToString:groupName])
            [keys addObject:key];
    }
    for (i = 0; i < [keys count]; i++)
        [_profileGroups setObject:@"" forKey:[keys objectAtIndex:i]];

    [self notifyChanged];
    return YES;
}

/* Import --------------------------------------------------------------- */

- (BOOL)importConnectionFromFile:(NSString *)path error:(NSString **)error
{
    NSString *localError = nil;
    VNCConnectionProfile *profile = [VNCConnectionProfile profileFromFileAtPath:path
                                                                           error:&localError];
    if (profile == nil)
    {
        if (error) *error = localError ? localError : @"Cannot read connection file";
        return NO;
    }

    /* A connection file without a name gets one derived from the host. */
    if ([[profile friendlyName] length] == 0)
        [profile setFriendlyName:[profile host]];

    [self addProfile:profile];
    if (error) *error = nil;
    return YES;
}

- (int)importConnectionsFromDirectory:(NSString *)directory errors:(NSMutableArray **)errors
{
    if (directory == nil)
        return -1;

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:directory isDirectory:&isDir] || !isDir)
        return -1;

    int imported = 0;

    /* Walk the directory tree: top-level files belong to the default group,
       files in a subfolder belong to that folder's group. */
    NSMutableArray *collected = [NSMutableArray array];
    NSDirectoryEnumerator *dirEnum = [fm enumeratorAtPath:directory];
    NSString *entry;
    while ((entry = [dirEnum nextObject]) != nil)
        [collected addObject:entry];
    NSArray *sorted = [collected sortedArrayUsingSelector:@selector(compare:)];

    NSEnumerator *e = [sorted objectEnumerator];
    NSString *relative;
    while ((relative = [e nextObject]) != nil)
    {
        if (![[relative pathExtension] isEqualToString:@"vnc"])
            continue;

        NSString *full = [directory stringByAppendingPathComponent:relative];
        BOOL entryIsDir = NO;
        if (![fm fileExistsAtPath:full isDirectory:&entryIsDir] || entryIsDir)
            continue;

        NSString *localError = nil;
        VNCConnectionProfile *profile = [VNCConnectionProfile profileFromFileAtPath:full
                                                                               error:&localError];
        if (profile == nil)
        {
            if (errors != nil && *errors != nil)
                [*errors addObject:[NSString stringWithFormat:@"%@: %@", relative,
                                    localError ? localError : @"cannot parse"]];
            continue;
        }

        if ([[profile friendlyName] length] == 0)
            [profile setFriendlyName:[[full lastPathComponent] stringByDeletingPathExtension]];

        [self addProfile:profile];

        /* The containing folder becomes the profile's group. */
        NSString *folder = [relative stringByDeletingLastPathComponent];
        if ([folder length] > 0 && ![folder isEqualToString:@"."])
        {
            [self addGroup:folder];
            [self setGroup:folder forProfile:profile];
        }

        imported++;
    }

    return imported;
}

/* Export --------------------------------------------------------------- */

- (BOOL)exportConnectionsToDirectory:(NSString *)directory
                     includePasswords:(BOOL)includePasswords
                               errors:(NSMutableArray **)errors
{
    if (directory == nil)
        return NO;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *nsError = nil;
    if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES
                        attributes:nil error:&nsError])
    {
        if (errors != nil && *errors != nil)
            [*errors addObject:[NSString stringWithFormat:@"Cannot create %@: %@",
                                directory, nsError ? [nsError localizedDescription] : @"unknown error"]];
        return NO;
    }

    unsigned i;
    BOOL allOk = YES;

    for (i = 0; i < [_profiles count]; i++)
    {
        VNCConnectionProfile *profile = [_profiles objectAtIndex:i];

        /* The group becomes a subfolder, as RealVNC does on export. */
        NSString *group = [self groupForProfile:profile];
        NSString *targetDir = directory;
        if ([group length] > 0)
        {
            targetDir = [directory stringByAppendingPathComponent:group];
            if (![fm createDirectoryAtPath:targetDir withIntermediateDirectories:YES
                                attributes:nil error:&nsError])
            {
                if (errors != nil && *errors != nil)
                    [*errors addObject:[NSString stringWithFormat:@"Cannot create %@: %@",
                                        targetDir, nsError ? [nsError localizedDescription] : @"unknown error"]];
                allOk = NO;
                continue;
            }
        }

        NSString *base = [profile friendlyName];
        if ([base length] == 0)
            base = [profile displayAddress];

        /* Make the file name safe for the file system. */
        NSCharacterSet *illegal = [NSCharacterSet characterSetWithCharactersInString:@"/\\:*?\"<>|"];
        base = [[base componentsSeparatedByCharactersInSet:illegal] componentsJoinedByString:@"_"];
        if ([base length] == 0)
            base = @"connection";

        NSString *filePath = [targetDir stringByAppendingPathComponent:
                                [base stringByAppendingPathExtension:@"vnc"]];

        /* Do not write the password unless asked to. */
        NSString *savedPassword = [profile password];
        if (!includePasswords)
            [profile setPassword:nil];

        NSString *localError = nil;
        BOOL written = [profile writeToFileAtPath:filePath error:&localError];
        if (!includePasswords)
            [profile setPassword:savedPassword];

        if (!written)
        {
            if (errors != nil && *errors != nil)
                [*errors addObject:localError ? localError :
                            [NSString stringWithFormat:@"Cannot write %@", filePath]];
            allOk = NO;
        }
    }

    return allOk;
}

/* XML address book ----------------------------------------------------- */

/* RealVNC exports its address book as XML with one <file> element per
   connection, each holding <section><param> pairs. */
- (NSData *)xmlRepresentationWithPasswords:(BOOL)includePasswords
{
    NSMutableString *xml = [NSMutableString string];
    unsigned i;

    [xml appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
    [xml appendString:@"<realvnc-address-book>\n"];

    for (i = 0; i < [_profiles count]; i++)
    {
        VNCConnectionProfile *profile = [_profiles objectAtIndex:i];
        NSString *name = [profile friendlyName];
        if ([name length] == 0)
            name = [profile displayAddress];

        [xml appendFormat:@"  <file name=\"%@\">\n",
            [self xmlEscape:name]];
        [xml appendString:@"    <section name=\"connection\">\n"];

        NSDictionary *params = [profile allParameters];
        NSArray *keys = [[params allKeys] sortedArrayUsingSelector:@selector(compare:)];
        unsigned j;
        for (j = 0; j < [keys count]; j++)
        {
            NSString *key = [keys objectAtIndex:j];
            if (!includePasswords && [key isEqualToString:@"Password"])
                continue;
            [xml appendFormat:@"      <param name=\"%@\" value=\"%@\" />\n",
                [self xmlEscape:key],
                [self xmlEscape:[params objectForKey:key]]];
        }

        [xml appendString:@"    </section>\n"];
        [xml appendString:@"  </file>\n"];
    }

    [xml appendString:@"</realvnc-address-book>\n"];

    return [xml dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)xmlEscape:(NSString *)value
{
    if (value == nil)
        return @"";
    NSMutableString *out = [NSMutableString stringWithCapacity:[value length]];
    NSUInteger i;
    for (i = 0; i < [value length]; i++)
    {
        unichar c = [value characterAtIndex:i];
        switch (c)
        {
            case '&':  [out appendString:@"&amp;"];  break;
            case '<':  [out appendString:@"&lt;"];   break;
            case '>':  [out appendString:@"&gt;"];   break;
            case '"':  [out appendString:@"&quot;"]; break;
            case '\'': [out appendString:@"&apos;"]; break;
            default:
                if (c < 0x20)
                    [out appendString:@" "];
                else
                    [out appendFormat:@"%C", c];
                break;
        }
    }
    return out;
}

- (BOOL)importFromXMLData:(NSData *)data error:(NSString **)error
{
    if (data == nil)
    {
        if (error) *error = @"No XML data";
        return NO;
    }

    NSString *xml = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (xml == nil)
    {
        if (error) *error = @"XML is not valid UTF-8";
        return NO;
    }

    /* A small hand-rolled scanner: the address book format is simple, and
       this avoids depending on NSXMLParser's error reporting quirks. */
    NSError *parseError = nil;
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    if (![parser parse])
    {
        parseError = [parser parserError];
        [parser release];
        if (error)
            *error = parseError ? [parseError localizedDescription] : @"Malformed XML";
        return NO;
    }
    [parser release];

    /* Second pass with a delegate to collect the values. */
    NSMutableArray *files = [NSMutableArray array];
    NSMutableDictionary *current = nil;
    NSUInteger index = 0;

    while (index < [xml length])
    {
        NSRange tagStart = [xml rangeOfString:@"<" options:0 range:NSMakeRange(index, [xml length] - index)];
        if (tagStart.location == NSNotFound)
            break;

        NSRange tagEnd = [xml rangeOfString:@">" options:0
                                      range:NSMakeRange(tagStart.location, [xml length] - tagStart.location)];
        if (tagEnd.location == NSNotFound)
            break;

        NSString *tag = [xml substringWithRange:
                            NSMakeRange(tagStart.location + 1, tagEnd.location - tagStart.location - 1)];
        index = tagEnd.location + 1;

        if ([tag hasPrefix:@"/"])
            continue;

        if ([tag hasPrefix:@"file "])
        {
            NSString *name = [self attributeValue:@"name" inTag:tag];
            current = [NSMutableDictionary dictionary];
            [current setObject:(name == nil ? @"" : name) forKey:@"__name__"];
            [files addObject:current];
            continue;
        }

        if ([tag hasPrefix:@"param "])
        {
            NSString *name = [self attributeValue:@"name" inTag:tag];
            NSString *value = [self attributeValue:@"value" inTag:tag];
            if (current != nil && name != nil)
                [current setObject:(value == nil ? @"" : value) forKey:name];
            continue;
        }
    }

    if ([files count] == 0)
    {
        if (error) *error = @"The XML address book contains no connections";
        return NO;
    }

    unsigned i;
    for (i = 0; i < [files count]; i++)
    {
        NSDictionary *entry = [files objectAtIndex:i];
        VNCConnectionProfile *profile = [[[VNCConnectionProfile alloc] init] autorelease];

        NSArray *keys = [[entry allKeys] sortedArrayUsingSelector:@selector(compare:)];
        unsigned j;
        for (j = 0; j < [keys count]; j++)
        {
            NSString *key = [keys objectAtIndex:j];
            if ([key isEqualToString:@"__name__"])
                continue;
            [profile setParameter:[entry objectForKey:key] forKey:key];
        }

        if ([[profile friendlyName] length] == 0)
            [profile setFriendlyName:[entry objectForKey:@"__name__"]];
        if ([[profile host] length] == 0)
            continue;

        [self addProfile:profile];
    }

    if (error) *error = nil;
    return YES;
}

- (NSString *)attributeValue:(NSString *)attribute inTag:(NSString *)tag
{
    NSString *needle = [NSString stringWithFormat:@"%@=\"", attribute];
    NSRange r = [tag rangeOfString:needle];
    if (r.location == NSNotFound)
        return nil;

    NSUInteger start = r.location + r.length;
    NSRange end = [tag rangeOfString:@"\"" options:0
                              range:NSMakeRange(start, [tag length] - start)];
    if (end.location == NSNotFound)
        return nil;

    return [self xmlUnescape:[tag substringWithRange:NSMakeRange(start, end.location - start)]];
}

/* Reverse of xmlEscape: turn the XML entities back into the characters they
   stand for, so that a name containing "&" survives an export/import cycle. */
- (NSString *)xmlUnescape:(NSString *)value
{
    if (value == nil)
        return nil;

    NSString *result = value;
    NSArray *entities = [NSArray arrayWithObjects:@"&amp;", @"&lt;", @"&gt;",
                          @"&quot;", @"&apos;", nil];
    NSArray *replacements = [NSArray arrayWithObjects:@"&", @"<", @">",
                              @"\"", @"'", nil];
    unsigned i;
    for (i = 0; i < [entities count]; i++)
        result = [result stringByReplacingOccurrencesOfString:[entities objectAtIndex:i]
                                                   withString:[replacements objectAtIndex:i]];
    return result;
}

/* Persistence ---------------------------------------------------------- */

- (BOOL)save
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *nsError = nil;

    if (![fm createDirectoryAtPath:_path withIntermediateDirectories:YES
                        attributes:nil error:&nsError])
        return NO;

    /* The address book itself is stored as a directory of RealVNC-style
       connection files, which is also the format we export in. */
    NSString *bookDir = [_path stringByAppendingPathComponent:@"AddressBook"];
    if (![fm createDirectoryAtPath:bookDir withIntermediateDirectories:YES
                        attributes:nil error:&nsError])
        return NO;

    NSMutableArray *errors = [NSMutableArray array];
    BOOL ok = [self exportConnectionsToDirectory:bookDir includePasswords:NO errors:&errors];

    /* The group layout is stored alongside as a small plist so that the
       folder structure survives a restart. */
    NSMutableDictionary *layout = [NSMutableDictionary dictionary];
    unsigned i;
    for (i = 0; i < [_profiles count]; i++)
    {
        VNCConnectionProfile *profile = [_profiles objectAtIndex:i];
        NSString *group = [self groupForProfile:profile];
        if ([group length] > 0)
            [layout setObject:group forKey:[self keyForProfile:profile]];
    }
    [layout setObject:[NSArray arrayWithArray:_groupNames] forKey:@"__groups__"];

    NSData *data = [NSPropertyListSerialization dataWithPropertyList:layout
                                                               format:NSPropertyListXMLFormat_v1_0
                                                              options:0
                                                                error:&nsError];
    if (data != nil)
    {
        [data writeToFile:[_path stringByAppendingPathComponent:@"AddressBook.plist"]
              atomically:YES];
    }

    return ok;
}

- (BOOL)load
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *bookDir = [_path stringByAppendingPathComponent:@"AddressBook"];

    BOOL isDir = NO;
    if ([fm fileExistsAtPath:bookDir isDirectory:&isDir] && isDir)
    {
        NSMutableArray *errors = [NSMutableArray array];
        [self importConnectionsFromDirectory:bookDir errors:&errors];
    }

    /* Restore the group layout. */
    NSString *plistPath = [_path stringByAppendingPathComponent:@"AddressBook.plist"];
    NSData *data = [NSData dataWithContentsOfFile:plistPath];
    if (data != nil)
    {
        NSError *nsError = nil;
        id layout = [NSPropertyListSerialization propertyListWithData:data
                                                              options:NSPropertyListImmutable
                                                               format:NULL
                                                                error:&nsError];
        if ([layout isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *dict = (NSDictionary *)layout;
            NSArray *groups = [dict objectForKey:@"__groups__"];
            if ([groups isKindOfClass:[NSArray class]])
            {
                unsigned i;
                for (i = 0; i < [groups count]; i++)
                    [self addGroup:[groups objectAtIndex:i]];
            }

            NSArray *keys = [dict allKeys];
            unsigned j;
            for (j = 0; j < [keys count]; j++)
            {
                NSString *key = [keys objectAtIndex:j];
                if ([key isEqualToString:@"__groups__"])
                    continue;
                VNCConnectionProfile *profile = [self profileNamed:key];
                if (profile != nil)
                    [self setGroup:[dict objectForKey:key] forProfile:profile];
            }
        }
    }

    return YES;
}

@end
