//
//  VNCConnectionProfile.h
//  RealVNC-style VNC client for macOS
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  A single saved connection. Modelled on the connection files that RealVNC
//  Viewer exports ("File -> Export Connections"), so that profiles can be
//  exchanged with RealVNC in both directions.
//

#import <Foundation/Foundation.h>

/* Connection method values used by RealVNC exported connection files. */
extern NSString * const VNCConnMethodTCP;
extern NSString * const VNCConnMethodSSH;

/* Security type values understood by RealVNC. */
extern NSString * const VNCSecurityTypeNone;
extern NSString * const VNCSecurityTypeVNCAuth;
extern NSString * const VNCSecurityTypeARD;
extern NSString * const VNCSecurityTypeTLS;
extern NSString * const VNCSecurityTypeVeNCrypt;
extern NSString * const VNCSecurityTypePlain;

@interface VNCConnectionProfile : NSObject <NSCopying>
{
    NSString *_friendlyName;
    NSString *_host;
    NSString *_port;
    NSString *_identity;
    NSString *_securityType;
    NSString *_password;
    NSString *_username;
    NSString *_connMethod;
    NSString *_encoding;
    NSString *_colorLevel;
    NSString *_viewOnly;
    NSString *_shared;
    NSString *_gatewayHost;
    NSString *_gatewayPort;
    NSString *_sshHost;
    NSString *_sshUser;
    NSString *_sshPort;
    NSMutableDictionary *_extraParameters;
}

/* Name shown in the address book. */
@property (nonatomic, copy) NSString *friendlyName;
/* Address of the remote machine. */
@property (nonatomic, copy) NSString *host;
/* TCP port, kept as a string so that "5900" and "display :0" survive round trips. */
@property (nonatomic, copy) NSString *port;
/* RealVNC connection identifier. */
@property (nonatomic, copy) NSString *identity;
/* Security type, e.g. VncAuth. */
@property (nonatomic, copy) NSString *securityType;
/* Password, only populated when the user asked to remember it. */
@property (nonatomic, copy) NSString *password;
/* Username for ARD / TLS authentication. */
@property (nonatomic, copy) NSString *username;
/* "tcp" or "ssh". */
@property (nonatomic, copy) NSString *connMethod;
/* Preferred encoding name, e.g. Tight. */
@property (nonatomic, copy) NSString *encoding;
/* Colour depth preference. */
@property (nonatomic, copy) NSString *colorLevel;
@property (nonatomic, copy) NSString *viewOnly;
@property (nonatomic, copy) NSString *shared;
/* Gateway (RealVNC Connect) parameters. */
@property (nonatomic, copy) NSString *gatewayHost;
@property (nonatomic, copy) NSString *gatewayPort;
/* SSH tunnel parameters. */
@property (nonatomic, copy) NSString *sshHost;
@property (nonatomic, copy) NSString *sshUser;
@property (nonatomic, copy) NSString *sshPort;

/* Any parameter that we do not model explicitly, preserved verbatim so that
   a profile exported by this application can be re-imported without losing
   information, and so that parameters written by newer RealVNC versions
   survive a round trip. */
@property (nonatomic, readonly) NSMutableDictionary *extraParameters;

/* All parameters as a flat dictionary, modelled and unmodelled alike. */
- (NSDictionary *)allParameters;
- (void)setParameter:(NSString *)value forKey:(NSString *)key;
- (NSString *)parameterForKey:(NSString *)key;

/* Default port for a server, 5900. */
+ (NSString *)defaultPort;

/* Parse a RealVNC-style connection file (ini-like "Key=Value" lines).
   Returns nil and fills in error if the data cannot be parsed. */
+ (VNCConnectionProfile *)profileFromData:(NSData *)data
                                    error:(NSString **)error;

/* Read a connection file from disk. */
+ (VNCConnectionProfile *)profileFromFileAtPath:(NSString *)path
                                          error:(NSString **)error;

/* Serialise in RealVNC connection-file format. */
- (NSData *)dataRepresentation;
- (BOOL)writeToFileAtPath:(NSString *)path error:(NSString **)error;

/* "host:port" as shown in the address book. */
- (NSString *)displayAddress;

@end
