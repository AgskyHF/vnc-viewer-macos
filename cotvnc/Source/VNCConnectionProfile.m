//
//  VNCConnectionProfile.m
//  RealVNC-style VNC client for macOS
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//

#import "VNCConnectionProfile.h"

NSString * const VNCConnMethodTCP = @"tcp";
NSString * const VNCConnMethodSSH = @"ssh";

NSString * const VNCSecurityTypeNone     = @"None";
NSString * const VNCSecurityTypeVNCAuth  = @"VncAuth";
NSString * const VNCSecurityTypeARD      = @"ARD";
NSString * const VNCSecurityTypeTLS      = @"TLS";
NSString * const VNCSecurityTypeVeNCrypt = @"VeNCrypt";
NSString * const VNCSecurityTypePlain    = @"Plain";

/* Parameter names as used by RealVNC connection files. */
static NSString * const kParamFriendlyName = @"FriendlyName";
static NSString * const kParamHost         = @"Host";
static NSString * const kParamPort         = @"Port";
static NSString * const kParamIdentity     = @"Identity";
static NSString * const kParamSecurityType = @"SecurityType";
static NSString * const kParamPassword     = @"Password";
static NSString * const kParamUsername     = @"Username";
static NSString * const kParamConnMethod   = @"ConnMethod";
static NSString * const kParamEncoding     = @"Encoding";
static NSString * const kParamColorLevel   = @"ColorLevel";
static NSString * const kParamViewOnly     = @"ViewOnly";
static NSString * const kParamShared       = @"Shared";
static NSString * const kParamGatewayHost  = @"GatewayHost";
static NSString * const kParamGatewayPort  = @"GatewayPort";
static NSString * const kParamSSHHost      = @"SSHHost";
static NSString * const kParamSSHUser      = @"SSHUser";
static NSString * const kParamSSHPort      = @"SSHPort";

@implementation VNCConnectionProfile

@synthesize friendlyName = _friendlyName;
@synthesize host = _host;
@synthesize port = _port;
@synthesize identity = _identity;
@synthesize securityType = _securityType;
@synthesize password = _password;
@synthesize username = _username;
@synthesize connMethod = _connMethod;
@synthesize encoding = _encoding;
@synthesize colorLevel = _colorLevel;
@synthesize viewOnly = _viewOnly;
@synthesize shared = _shared;
@synthesize gatewayHost = _gatewayHost;
@synthesize gatewayPort = _gatewayPort;
@synthesize sshHost = _sshHost;
@synthesize sshUser = _sshUser;
@synthesize sshPort = _sshPort;

- (id)init
{
    if (self = [super init])
    {
        _extraParameters = [[NSMutableDictionary alloc] init];
        _connMethod = [[VNCConnMethodTCP retain] autorelease];
        _securityType = [[VNCSecurityTypeVNCAuth retain] autorelease];
    }
    return self;
}

- (void)dealloc
{
    [_friendlyName release];
    [_host release];
    [_port release];
    [_identity release];
    [_securityType release];
    [_password release];
    [_username release];
    [_connMethod release];
    [_encoding release];
    [_colorLevel release];
    [_viewOnly release];
    [_shared release];
    [_gatewayHost release];
    [_gatewayPort release];
    [_sshHost release];
    [_sshUser release];
    [_sshPort release];
    [_extraParameters release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    VNCConnectionProfile *copy = [[VNCConnectionProfile allocWithZone:zone] init];
    copy.friendlyName = _friendlyName;
    copy.host = _host;
    copy.port = _port;
    copy.identity = _identity;
    copy.securityType = _securityType;
    copy.password = _password;
    copy.username = _username;
    copy.connMethod = _connMethod;
    copy.encoding = _encoding;
    copy.colorLevel = _colorLevel;
    copy.viewOnly = _viewOnly;
    copy.shared = _shared;
    copy.gatewayHost = _gatewayHost;
    copy.gatewayPort = _gatewayPort;
    copy.sshHost = _sshHost;
    copy.sshUser = _sshUser;
    copy.sshPort = _sshPort;
    [copy.extraParameters addEntriesFromDictionary:_extraParameters];
    return copy;
}

+ (NSString *)defaultPort
{
    return @"5900";
}

- (NSMutableDictionary *)extraParameters
{
    return _extraParameters;
}

/* The keys we model explicitly; everything else lands in extraParameters. */
+ (NSSet *)modelledParameterNames
{
    static NSSet *names = nil;
    if (names == nil)
    {
        names = [[NSSet alloc] initWithObjects:
                  kParamFriendlyName, kParamHost, kParamPort, kParamIdentity,
                  kParamSecurityType, kParamPassword, kParamUsername,
                  kParamConnMethod, kParamEncoding, kParamColorLevel,
                  kParamViewOnly, kParamShared, kParamGatewayHost,
                  kParamGatewayPort, kParamSSHHost, kParamSSHUser, kParamSSHPort,
                  nil];
    }
    return names;
}

- (NSString *)parameterForKey:(NSString *)key
{
    if (key == nil) return nil;

    if ([key isEqualToString:kParamFriendlyName]) return _friendlyName;
    if ([key isEqualToString:kParamHost])         return _host;
    if ([key isEqualToString:kParamPort])         return _port;
    if ([key isEqualToString:kParamIdentity])     return _identity;
    if ([key isEqualToString:kParamSecurityType]) return _securityType;
    if ([key isEqualToString:kParamPassword])     return _password;
    if ([key isEqualToString:kParamUsername])     return _username;
    if ([key isEqualToString:kParamConnMethod])   return _connMethod;
    if ([key isEqualToString:kParamEncoding])     return _encoding;
    if ([key isEqualToString:kParamColorLevel])   return _colorLevel;
    if ([key isEqualToString:kParamViewOnly])     return _viewOnly;
    if ([key isEqualToString:kParamShared])       return _shared;
    if ([key isEqualToString:kParamGatewayHost])  return _gatewayHost;
    if ([key isEqualToString:kParamGatewayPort])  return _gatewayPort;
    if ([key isEqualToString:kParamSSHHost])      return _sshHost;
    if ([key isEqualToString:kParamSSHUser])      return _sshUser;
    if ([key isEqualToString:kParamSSHPort])      return _sshPort;

    return [_extraParameters objectForKey:key];
}

- (void)setParameter:(NSString *)value forKey:(NSString *)key
{
    if (key == nil) return;

    if ([key isEqualToString:kParamFriendlyName]) { self.friendlyName = value; return; }
    if ([key isEqualToString:kParamHost])         { self.host = value; return; }
    if ([key isEqualToString:kParamPort])         { self.port = value; return; }
    if ([key isEqualToString:kParamIdentity])     { self.identity = value; return; }
    if ([key isEqualToString:kParamSecurityType]) { self.securityType = value; return; }
    if ([key isEqualToString:kParamPassword])     { self.password = value; return; }
    if ([key isEqualToString:kParamUsername])     { self.username = value; return; }
    if ([key isEqualToString:kParamConnMethod])   { self.connMethod = value; return; }
    if ([key isEqualToString:kParamEncoding])     { self.encoding = value; return; }
    if ([key isEqualToString:kParamColorLevel])   { self.colorLevel = value; return; }
    if ([key isEqualToString:kParamViewOnly])     { self.viewOnly = value; return; }
    if ([key isEqualToString:kParamShared])       { self.shared = value; return; }
    if ([key isEqualToString:kParamGatewayHost])  { self.gatewayHost = value; return; }
    if ([key isEqualToString:kParamGatewayPort])  { self.gatewayPort = value; return; }
    if ([key isEqualToString:kParamSSHHost])      { self.sshHost = value; return; }
    if ([key isEqualToString:kParamSSHUser])      { self.sshUser = value; return; }
    if ([key isEqualToString:kParamSSHPort])      { self.sshPort = value; return; }

    if (value == nil)
        [_extraParameters removeObjectForKey:key];
    else
        [_extraParameters setObject:value forKey:key];
}

- (NSDictionary *)allParameters
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSSet *modelled = [[self class] modelledParameterNames];
    NSArray *keys = [modelled allObjects];
    unsigned i;

    for (i = 0; i < [keys count]; i++)
    {
        NSString *key = [keys objectAtIndex:i];
        NSString *value = [self parameterForKey:key];
        if (value != nil)
            [params setObject:value forKey:key];
    }

    [params addEntriesFromDictionary:_extraParameters];
    return params;
}

/* Parsing ------------------------------------------------------------- */

+ (VNCConnectionProfile *)profileFromData:(NSData *)data error:(NSString **)error
{
    if (data == nil)
    {
        if (error) *error = @"No connection data";
        return nil;
    }

    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text == nil)
    {
        if (error) *error = @"Connection file is not valid UTF-8";
        return nil;
    }

    VNCConnectionProfile *profile = [[[VNCConnectionProfile alloc] init] autorelease];
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    unsigned i;
    BOOL sawHost = NO;

    for (i = 0; i < [lines count]; i++)
    {
        NSString *line = [lines objectAtIndex:i];
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmed length] == 0)
            continue;
        /* Comments start with '#' or ';'. */
        if ([trimmed hasPrefix:@"#"] || [trimmed hasPrefix:@";"])
            continue;

        NSRange sep = [trimmed rangeOfString:@"="];
        if (sep.location == NSNotFound)
        {
            if (error)
                *error = [NSString stringWithFormat:@"Malformed line %u: %@", i + 1, trimmed];
            return nil;
        }

        NSString *key = [[trimmed substringToIndex:sep.location]
                            stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceCharacterSet]];
        NSString *value = [[trimmed substringFromIndex:sep.location + 1]
                            stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceCharacterSet]];
        if ([key length] == 0)
            continue;

        [profile setParameter:value forKey:key];
        if ([key isEqualToString:kParamHost])
            sawHost = YES;
    }

    if (!sawHost)
    {
        if (error) *error = @"Connection file does not contain a Host";
        return nil;
    }

    if (profile.port == nil)
        profile.port = [[self class] defaultPort];

    if (error) *error = nil;
    return profile;
}

+ (VNCConnectionProfile *)profileFromFileAtPath:(NSString *)path error:(NSString **)error
{
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil)
    {
        if (error) *error = [NSString stringWithFormat:@"Cannot read %@", path];
        return nil;
    }
    return [self profileFromData:data error:error];
}

/* Serialising ---------------------------------------------------------- */

- (NSData *)dataRepresentation
{
    NSMutableString *out = [NSMutableString string];

    /* The order below matches the order RealVNC itself writes when
       exporting connections, so that exported files look familiar. */
    NSArray *order = [NSArray arrayWithObjects:
                      kParamConnMethod, kParamFriendlyName, kParamHost, kParamPort,
                      kParamIdentity, kParamSecurityType, kParamUsername,
                      kParamEncoding, kParamColorLevel, kParamViewOnly,
                      kParamShared, kParamGatewayHost, kParamGatewayPort,
                      kParamSSHHost, kParamSSHUser, kParamSSHPort,
                      nil];
    unsigned i;

    for (i = 0; i < [order count]; i++)
    {
        NSString *key = [order objectAtIndex:i];
        NSString *value = [self parameterForKey:key];
        if (value == nil) continue;
        [out appendFormat:@"%@=%@\n", key, value];
    }

    /* Unmodelled parameters are written after the modelled ones, sorted, so
       that the output is stable. */
    NSArray *extraKeys = [[_extraParameters allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (i = 0; i < [extraKeys count]; i++)
    {
        NSString *key = [extraKeys objectAtIndex:i];
        [out appendFormat:@"%@=%@\n", key, [_extraParameters objectForKey:key]];
    }

    /* The password is written last and only when it is set, matching the
       behaviour of RealVNC's "export passwords" option. */
    if (_password != nil && [_password length] > 0)
        [out appendFormat:@"%@=%@\n", kParamPassword, _password];

    return [out dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)writeToFileAtPath:(NSString *)path error:(NSString **)error
{
    NSData *data = [self dataRepresentation];
    if (data == nil)
    {
        if (error) *error = @"Could not serialise connection";
        return NO;
    }
    if (![data writeToFile:path atomically:YES])
    {
        if (error) *error = [NSString stringWithFormat:@"Cannot write %@", path];
        return NO;
    }
    if (error) *error = nil;
    return YES;
}

- (NSString *)displayAddress
{
    NSString *h = (_host == nil || [_host length] == 0) ? @"" : _host;
    NSString *p = (_port == nil || [_port length] == 0) ? [[self class] defaultPort] : _port;
    return [NSString stringWithFormat:@"%@:%@", h, p];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<VNCConnectionProfile %@ (%@)>",
            (_friendlyName == nil ? @"" : _friendlyName), [self displayAddress]];
}

@end
