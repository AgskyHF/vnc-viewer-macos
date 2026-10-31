//
//  KeyChainStub.m
//  Test-only replacement for the app's KeyChain class.
//
//  The real implementation uses the modern SecItem API, which always talks to
//  the user's login keychain and therefore pops up a SecurityAgent prompt the
//  first time an unsigned command-line tool touches an item that a
//  GUI-signed build created. That prompt blocks the test forever.
//
//  This stub keeps the passwords in memory instead, so the integration test
//  stays self-contained and never touches the system keychain.
//
//  It is NOT linked into the app; only into build/integration_tests.
//

#import "KeyChain.h"

@implementation KeyChain

static KeyChain *defaultKeychainInstance = nil;

+ (KeyChain *)defaultKeyChain
{
    if (defaultKeychainInstance == nil)
        defaultKeychainInstance = [[self alloc] init];
    return defaultKeychainInstance;
}

- (BOOL)setGenericPassword:(NSString *)password
                forService:(NSString *)service
                   account:(NSString *)account
{
    if ([service length] == 0 || [account length] == 0)
        return NO;

    if (!password || [password length] == 0)
    {
        [self removeGenericPasswordForService:service account:account];
        return YES;
    }

    [[self store] setObject:password
                      forKey:[NSString stringWithFormat:@"%@|%@", service, account]];
    return YES;
}

- (NSString *)genericPasswordForService:(NSString *)service
                                 account:(NSString *)account
{
    if ([service length] == 0 || [account length] == 0)
        return @"";

    NSString *value = [[self store] objectForKey:
                        [NSString stringWithFormat:@"%@|%@", service, account]];
    return value ? value : @"";
}

- (void)removeGenericPasswordForService:(NSString *)service
                                 account:(NSString *)account
{
    if ([service length] == 0 || [account length] == 0)
        return;

    [[self store] removeObjectForKey:
     [NSString stringWithFormat:@"%@|%@", service, account]];
}

- (NSMutableDictionary *)store
{
    static NSMutableDictionary *shared = nil;
    if (shared == nil)
        shared = [[NSMutableDictionary alloc] init];
    return shared;
}

@end
