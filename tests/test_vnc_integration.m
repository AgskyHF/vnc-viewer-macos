//
//  test_vnc_integration.m
//  Integration test for the RealVNC import/export bridge against the app's
//  real server model (ServerDataManager / ServerFromPrefs).
//
//  Built natively on macOS (see scripts/build_integration_test.sh).
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <Security/Security.h>
#import "VNCProfileBridge.h"
#import "VNCConnectionProfile.h"
#import "VNCAddressBook.h"
#import "ServerDataManager.h"
#import "IServerData.h"

static int gFailures = 0;
static int gChecks = 0;

static void check(BOOL condition, NSString *what)
{
    gChecks++;
    if (condition)
        printf("  ok   %s\n", [what UTF8String]);
    else
    {
        gFailures++;
        printf("  FAIL %s\n", [what UTF8String]);
    }
}

static void checkEqualStr(NSString *actual, NSString *expected, NSString *what)
{
    BOOL equal = (actual == expected) || (actual && [actual isEqualToString:expected]);
    gChecks++;
    if (equal)
        printf("  ok   %s\n", [what UTF8String]);
    else
    {
        gFailures++;
        printf("  FAIL %s (expected '%s', got '%s')\n",
               [what UTF8String],
               expected ? [expected UTF8String] : "(nil)",
               actual ? [actual UTF8String] : "(nil)");
    }
}

static NSString *gTempDir = nil;

static NSString *makeTempDir(void)
{
    NSString *path = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSString stringWithFormat:@"vncint-%@",
                                           [[NSUUID UUID] UUIDString]]];
    [[NSFileManager defaultManager] createDirectoryAtPath:path
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    return path;
}

static void writeFile(NSString *path, NSString *contents)
{
    [[contents dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES];
}

static NSArray *serverNames(void)
{
    NSMutableArray *names = [NSMutableArray array];
    NSEnumerator *e = [[ServerDataManager sharedInstance] getServerEnumeratorForGroupName:@"All"];
    id<IServerData> server;
    while ((server = [e nextObject]) != nil)
        [names addObject:[server name]];
    return names;
}

static id<IServerData>findServer(NSString *name)
{
    NSEnumerator *e = [[ServerDataManager sharedInstance] getServerEnumeratorForGroupName:@"All"];
    id<IServerData> server;
    while ((server = [e nextObject]) != nil)
        if ([[server name] isEqualToString:name])
            return server;
    return nil;
}

int main(int argc, const char *argv[])
{
    @autoreleasepool
    {
        /* Keep the test off any state left over from earlier runs. A command
           line tool stores its defaults under its own process name, so that
           is the domain that has to be cleared — clearing the app's domain
           (ru.gsky.vncviewer) would leave the test's own leftovers in
           place, and stale servers would shadow the freshly imported ones. */
        NSString *domain = [[NSProcessInfo processInfo] processName];
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domain];
        printf("using defaults domain: %s\n", [domain UTF8String]);

        gTempDir = [[makeTempDir() retain] autorelease];
        NSString *src = [gTempDir stringByAppendingPathComponent:@"import"];
        NSString *office = [src stringByAppendingPathComponent:@"Office"];
        NSString *exportDir = [gTempDir stringByAppendingPathComponent:@"export"];
        [[NSFileManager defaultManager] createDirectoryAtPath:office
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
        [[NSFileManager defaultManager] createDirectoryAtPath:exportDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];

        writeFile([src stringByAppendingPathComponent:@"Workstation.vnc"],
                  @"ConnMethod=tcp\nFriendlyName=Workstation\nHost=192.168.1.50\n"
                   "Port=5900\nSecurityType=VncAuth\n");
        writeFile([office stringByAppendingPathComponent:@"Server.vnc"],
                  @"ConnMethod=tcp\nFriendlyName=Office server\nHost=192.168.1.51\n"
                   "Port=5901\nSecurityType=VncAuth\n");
        writeFile([src stringByAppendingPathComponent:@"Secret.vnc"],
                  @"ConnMethod=tcp\nFriendlyName=Secret\nHost=192.168.1.52\n"
                   "Port=5902\nSecurityType=VncAuth\nPassword=secret123\n");

        printf("test: importing a directory of .vnc files\n");
        NSMutableArray *errors = [NSMutableArray array];
        int imported = [VNCProfileBridge importConnectionsFromDirectory:src errors:&errors];
        check(imported == 3, @"three connections imported");
        check([errors count] == 0, @"no import errors");

        NSArray *names = serverNames();
        /* The app always keeps one default connection ("New Server"), so the
           imported ones are three on top of it. */
        check([names count] == 4, @"four servers in the address book (3 imported + 1 default)");
        check([names containsObject:@"Workstation"], @"Workstation present");
        check([names containsObject:@"Office server"], @"Office server present");
        check([names containsObject:@"Secret"], @"Secret present");

        printf("test: imported values reach the server model\n");
        id<IServerData> ws = findServer(@"Workstation");
        check(ws != nil, @"Workstation found");
        if (ws)
        {
            checkEqualStr([ws host], @"192.168.1.50", @"host imported");
            check([ws port] == 5900, @"port imported");
        }

        printf("test: a subfolder becomes an address book folder\n");
        ServerDataManager *manager = [ServerDataManager sharedInstance];
        NSString *group = [manager groupForServer:findServer(@"Office server")];
        checkEqualStr(group, @"Office", @"Office server landed in the Office folder");
        NSEnumerator *inGroup = [manager getServerEnumeratorForGroupName:@"Office"];
        check([inGroup nextObject] != nil, @"Office folder is not empty");

        printf("test: export without passwords\n");
        NSMutableArray *exportErrors = [NSMutableArray array];
        BOOL ok = [VNCProfileBridge exportConnectionsToDirectory:exportDir
                                               includePasswords:NO
                                                         errors:&exportErrors];
        check(ok, @"export succeeded");
        check([exportErrors count] == 0, @"no export errors");

        NSString *wsPath = [exportDir stringByAppendingPathComponent:@"Workstation.vnc"];
        NSString *secretPath = [exportDir stringByAppendingPathComponent:@"Secret.vnc"];
        check([[NSFileManager defaultManager] fileExistsAtPath:wsPath],
              @"Workstation.vnc written");
        check([[NSFileManager defaultManager] fileExistsAtPath:secretPath],
              @"Secret.vnc written");

        NSString *exportedOffice = [exportDir stringByAppendingPathComponent:@"Office"];
        check([[NSFileManager defaultManager] fileExistsAtPath:exportedOffice],
              @"Office subdirectory created");
        /* The exported file is named after the connection, not after the
           original .vnc file name. */
        NSString *exportedOfficeFile =
            [exportedOffice stringByAppendingPathComponent:@"Office server.vnc"];
        check([[NSFileManager defaultManager] fileExistsAtPath:exportedOfficeFile],
              @"Office/Office server.vnc written");

        printf("test: the exported file is real RealVNC format\n");
        NSString *contents = [NSString stringWithContentsOfFile:wsPath
                                                       encoding:NSUTF8StringEncoding
                                                          error:NULL];
        check(contents != nil, @"exported file is readable");
        if (contents)
        {
            check([contents rangeOfString:@"ConnMethod=tcp"].location != NSNotFound,
                  @"ConnMethod=tcp present");
            check([contents rangeOfString:@"FriendlyName=Workstation"].location != NSNotFound,
                  @"FriendlyName present");
            check([contents rangeOfString:@"Host=192.168.1.50"].location != NSNotFound,
                  @"Host present");
            check([contents rangeOfString:@"Port=5900"].location != NSNotFound,
                  @"Port present");
        }

        NSString *secretContents = [NSString stringWithContentsOfFile:secretPath
                                                             encoding:NSUTF8StringEncoding
                                                                error:NULL];
        check(secretContents != nil
              && [secretContents rangeOfString:@"Password="].location == NSNotFound,
              @"no password in the password-less export");

        printf("test: export with passwords\n");
        NSString *exportDir2 = [gTempDir stringByAppendingPathComponent:@"export-pw"];
        [[NSFileManager defaultManager] createDirectoryAtPath:exportDir2
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
        NSMutableArray *exportErrors2 = [NSMutableArray array];
        ok = [VNCProfileBridge exportConnectionsToDirectory:exportDir2
                                         includePasswords:YES
                                                   errors:&exportErrors2];
        check(ok, @"export with passwords succeeded");
        NSString *secret2 = [exportDir2 stringByAppendingPathComponent:@"Secret.vnc"];
        NSString *contents2 = [NSString stringWithContentsOfFile:secret2
                                                        encoding:NSUTF8StringEncoding
                                                           error:NULL];
        check(contents2 != nil, @"Secret.vnc written");
        if (contents2)
            check([contents2 rangeOfString:@"Password=secret123"].location != NSNotFound,
                  @"password present in the password export");

        printf("test: the XML address book round trips\n");
        NSString *xmlPath = [gTempDir stringByAppendingPathComponent:@"book.xml"];
        NSString *xmlError = nil;
        check([VNCProfileBridge exportAddressBookToXMLFile:xmlPath
                                          includePasswords:YES
                                                    error:&xmlError],
              @"XML address book exported");
        check(xmlError == nil, @"no XML export error");
        NSString *xmlText = [NSString stringWithContentsOfFile:xmlPath
                                                       encoding:NSUTF8StringEncoding
                                                          error:NULL];
        check(xmlText != nil, @"XML file is readable");
        if (xmlText)
        {
            check([xmlText rangeOfString:@"<realvnc-address-book>"].location != NSNotFound,
                  @"RealVNC address book root element");
            check([xmlText rangeOfString:@"name=\"Host\""].location != NSNotFound,
                  @"Host parameter present");
            check([xmlText rangeOfString:@"Password=secret123"].location != NSNotFound
                  || [xmlText rangeOfString:@"name=\"Password\""].location != NSNotFound,
                  @"password parameter present");
        }

        printf("test: importing the XML address book back\n");
        {
            /* Import into a fresh state, so the counts are unambiguous. */
            NSString *domain = [[NSProcessInfo processInfo] processName];
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domain];

            NSMutableArray *xmlErrors = [NSMutableArray array];
            int xmlImported = [VNCProfileBridge importAddressBookFromXMLFile:xmlPath
                                                                        errors:&xmlErrors];
            check(xmlImported == 4, @"four connections imported from XML");
            check([xmlErrors count] == 0, @"no XML import errors");

            NSArray *xmlNames = serverNames();
            check([xmlNames containsObject:@"Workstation"], @"Workstation from XML");
            check([xmlNames containsObject:@"Office server"], @"Office server from XML");
            check([xmlNames containsObject:@"Secret"], @"Secret from XML");

            id<IServerData> wsXml = findServer(@"Workstation");
            check(wsXml != nil, @"Workstation found after XML import");
            if (wsXml)
                checkEqualStr([wsXml host], @"192.168.1.50", @"host from XML import");
        }

        printf("test: a broken file is reported, not fatal\n");
        NSString *brokenDir = [gTempDir stringByAppendingPathComponent:@"broken"];
        [[NSFileManager defaultManager] createDirectoryAtPath:brokenDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
        writeFile([brokenDir stringByAppendingPathComponent:@"Bad.vnc"],
                  @"this is not a connection file\n");
        NSMutableArray *brokenErrors = [NSMutableArray array];
        int brokenImported = [VNCProfileBridge importConnectionsFromDirectory:brokenDir
                                                                        errors:&brokenErrors];
        check(brokenImported >= 0, @"broken import returns a count");
        check([brokenErrors count] > 0, @"broken file reported as an error");

        printf("-------------------\n");
        printf("%d checks, %d failures\n", gChecks, gFailures);

        [[NSFileManager defaultManager] removeItemAtPath:gTempDir error:NULL];
    }

    return gFailures == 0 ? 0 : 1;
}
