//
//  test_vnc_address_book.m
//  Tests for the address book: import, export, groups, XML round trip.
//
//  Built and run on Linux with GNUstep (see scripts/objc_test_bench.sh).
//

#import <Foundation/Foundation.h>
#import <unistd.h>
#import "VNCAddressBook.h"

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

static void checkEqual(NSString *actual, NSString *expected, NSString *what)
{
    BOOL equal = (actual == expected) || [actual isEqualToString:expected];
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

static NSString *makeTempDir(NSString *tag)
{
    NSString *base = [NSTemporaryDirectory() stringByAppendingPathComponent:
                        [NSString stringWithFormat:@"vnctest-%@-%d", tag, (int)getpid()]];
    [[NSFileManager defaultManager] removeItemAtPath:base error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:base
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    return base;
}

static VNCAddressBook *freshBook(void)
{
    VNCAddressBook *book = [[[VNCAddressBook alloc] init] autorelease];
    return book;
}

static void testAddAndCount(void)
{
    printf("test: adding connections\n");

    VNCAddressBook *book = freshBook();
    VNCConnectionProfile *p = [[[VNCConnectionProfile alloc] init] autorelease];
    p.host = @"10.0.0.1";
    p.friendlyName = @"First";

    check([book addProfile:p], @"profile added");
    check(book.count == 1, @"count is 1");
    check([[book profileNamed:@"First"] host] != nil, @"profile found by name");
    checkEqual([[book profileNamed:@"First"] host], @"10.0.0.1", @"host of found profile");
}

static void testDuplicateReplaces(void)
{
    printf("test: adding a connection with the same name replaces it\n");

    VNCAddressBook *book = freshBook();
    VNCConnectionProfile *a = [[[VNCConnectionProfile alloc] init] autorelease];
    a.host = @"10.0.0.1"; a.friendlyName = @"Same";
    [book addProfile:a];

    VNCConnectionProfile *b = [[[VNCConnectionProfile alloc] init] autorelease];
    b.host = @"10.0.0.2"; b.friendlyName = @"Same";
    [book addProfile:b];

    check(book.count == 1, @"still one profile");
    checkEqual([[book profileNamed:@"Same"] host], @"10.0.0.2", @"host updated");
}

static void testGroups(void)
{
    printf("test: groups\n");

    VNCAddressBook *book = freshBook();
    check([book addGroup:@"Servers"], @"group added");
    check([book hasGroup:@"Servers"], @"group exists");
    check(![book addGroup:@"Servers"], @"adding the same group again fails");

    VNCConnectionProfile *p = [[[VNCConnectionProfile alloc] init] autorelease];
    p.host = @"10.0.0.3"; p.friendlyName = @"In group";
    [book addProfile:p];
    [book setGroup:@"Servers" forProfile:p];

    checkEqual([book groupForProfile:p], @"Servers", @"profile group");
    check([[book profilesInGroup:@"Servers"] count] == 1, @"one profile in group");

    /* Removing a group moves its profiles back to the default group. */
    check([book removeGroup:@"Servers"], @"group removed");
    checkEqual([book groupForProfile:p], @"", @"profile back in default group");
}

static void testExportImport(void)
{
    printf("test: export to a directory and import back\n");

    NSString *dir = makeTempDir(@"export");
    VNCAddressBook *book = freshBook();

    VNCConnectionProfile *a = [[[VNCConnectionProfile alloc] init] autorelease];
    a.host = @"192.168.0.1"; a.port = @"5900"; a.friendlyName = @"Alpha";
    a.securityType = @"VncAuth";
    [book addProfile:a];

    VNCConnectionProfile *b = [[[VNCConnectionProfile alloc] init] autorelease];
    b.host = @"192.168.0.2"; b.port = @"5901"; b.friendlyName = @"Beta";
    [book addProfile:b];
    [book addGroup:@"Office"];
    [book setGroup:@"Office" forProfile:b];

    NSMutableArray *errors = [NSMutableArray array];
    BOOL ok = [book exportConnectionsToDirectory:dir includePasswords:NO errors:&errors];
    check(ok, @"export succeeded");
    check([errors count] == 0, @"no export errors");

    /* The group became a subfolder, like RealVNC does. */
    NSFileManager *fm = [NSFileManager defaultManager];
    check([fm fileExistsAtPath:[dir stringByAppendingPathComponent:@"Alpha.vnc"]],
          @"Alpha.vnc written");
    check([fm fileExistsAtPath:[dir stringByAppendingPathComponent:@"Office/Beta.vnc"]],
          @"Beta.vnc written into the Office folder");

    /* Import into a fresh book. */
    VNCAddressBook *book2 = freshBook();
    NSMutableArray *importErrors = [NSMutableArray array];
    int imported = [book2 importConnectionsFromDirectory:dir errors:&importErrors];
    check(imported == 2, @"two connections imported");
    check([importErrors count] == 0, @"no import errors");
    check(book2.count == 2, @"imported book has two profiles");
    checkEqual([[book2 profileNamed:@"Alpha"] host], @"192.168.0.1", @"Alpha host imported");
    checkEqual([[book2 profileNamed:@"Beta"] port], @"5901", @"Beta port imported");
    check([book2 hasGroup:@"Office"], @"Office group restored from folder");
    checkEqual([book2 groupForProfile:[book2 profileNamed:@"Beta"]], @"Office",
               @"Beta is in the Office group");

    [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
}

static void testExportWithoutPasswords(void)
{
    printf("test: exported files omit the password unless asked\n");

    NSString *dir = makeTempDir(@"nopass");
    VNCAddressBook *book = freshBook();

    VNCConnectionProfile *a = [[[VNCConnectionProfile alloc] init] autorelease];
    a.host = @"10.1.1.1"; a.friendlyName = @"Secret"; a.password = @"hunter2";
    [book addProfile:a];

    NSMutableArray *errors = [NSMutableArray array];
    [book exportConnectionsToDirectory:dir includePasswords:NO errors:&errors];

    NSString *path = [dir stringByAppendingPathComponent:@"Secret.vnc"];
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    check(contents != nil, @"file readable");
    check([contents rangeOfString:@"hunter2"].location == NSNotFound, @"password not written");
    check([contents rangeOfString:@"Password="].location == NSNotFound, @"no Password key at all");
    check([contents rangeOfString:@"Host=10.1.1.1"].location != NSNotFound, @"host written");

    /* With passwords the value is included. */
    NSString *dir2 = makeTempDir(@"withpass");
    [book exportConnectionsToDirectory:dir2 includePasswords:YES errors:&errors];
    NSString *contents2 = [NSString stringWithContentsOfFile:
                                [dir2 stringByAppendingPathComponent:@"Secret.vnc"]
                                                     encoding:NSUTF8StringEncoding error:NULL];
    check([contents2 rangeOfString:@"Password=hunter2"].location != NSNotFound,
          @"password written when requested");

    [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:dir2 error:NULL];
}

static void testXMLRoundTrip(void)
{
    printf("test: XML address book round trip\n");

    VNCAddressBook *book = freshBook();

    VNCConnectionProfile *a = [[[VNCConnectionProfile alloc] init] autorelease];
    a.host = @"10.5.5.5"; a.port = @"5900"; a.friendlyName = @"XML One";
    a.securityType = @"VncAuth"; a.username = @"user";
    [book addProfile:a];

    VNCConnectionProfile *b = [[[VNCConnectionProfile alloc] init] autorelease];
    b.host = @"10.5.5.6"; b.friendlyName = @"XML & Two";
    [book addProfile:b];

    NSData *xml = [book xmlRepresentationWithPasswords:NO];
    check(xml != nil && [xml length] > 0, @"xml produced");

    NSString *text = [[NSString alloc] initWithData:xml encoding:NSUTF8StringEncoding];
    check([text rangeOfString:@"<realvnc-address-book>"].location != NSNotFound, @"root element");
    check([text rangeOfString:@"name=\"XML One\""].location != NSNotFound, @"file element with name");
    check([text rangeOfString:@"name=\"Host\""].location != NSNotFound, @"param element");
    check([text rangeOfString:@"XML &amp; Two"].location != NSNotFound, @"ampersand escaped");

    /* Import it into a fresh book. */
    VNCAddressBook *book2 = freshBook();
    NSString *error = nil;
    BOOL ok = [book2 importFromXMLData:xml error:&error];
    check(ok, @"xml imported");
    check(error == nil, @"no error");
    check(book2.count == 2, @"two profiles imported");
    checkEqual([[book2 profileNamed:@"XML One"] host], @"10.5.5.5", @"host imported");
    checkEqual([[book2 profileNamed:@"XML One"] username], @"user", @"username imported");
    checkEqual([[book2 profileNamed:@"XML & Two"] host], @"10.5.5.6", @"escaped name imported");
}

static void testXMLWithPassword(void)
{
    printf("test: XML export can include passwords\n");

    VNCAddressBook *book = freshBook();
    VNCConnectionProfile *a = [[[VNCConnectionProfile alloc] init] autorelease];
    a.host = @"10.6.6.6"; a.friendlyName = @"WithPass"; a.password = @"topsecret";
    [book addProfile:a];

    NSData *without = [book xmlRepresentationWithPasswords:NO];
    NSString *textWithout = [[NSString alloc] initWithData:without encoding:NSUTF8StringEncoding];
    check([textWithout rangeOfString:@"topsecret"].location == NSNotFound, @"password omitted");

    NSData *with = [book xmlRepresentationWithPasswords:YES];
    NSString *textWith = [[NSString alloc] initWithData:with encoding:NSUTF8StringEncoding];
    check([textWith rangeOfString:@"topsecret"].location != NSNotFound, @"password included");
}

static void testImportSkipsBadFiles(void)
{
    printf("test: broken connection files are skipped, not fatal\n");

    NSString *dir = makeTempDir(@"bad");
    NSFileManager *fm = [NSFileManager defaultManager];

    [[@"Host=good.host\nFriendlyName=Good\n" dataUsingEncoding:NSUTF8StringEncoding]
        writeToFile:[dir stringByAppendingPathComponent:@"Good.vnc"] atomically:YES];
    [[@"this is not a connection file\n" dataUsingEncoding:NSUTF8StringEncoding]
        writeToFile:[dir stringByAppendingPathComponent:@"Broken.vnc"] atomically:YES];
    [[@"FriendlyName=NoHost\n" dataUsingEncoding:NSUTF8StringEncoding]
        writeToFile:[dir stringByAppendingPathComponent:@"NoHost.vnc"] atomically:YES];

    VNCAddressBook *book = freshBook();
    NSMutableArray *errors = [NSMutableArray array];
    int imported = [book importConnectionsFromDirectory:dir errors:&errors];

    check(imported == 1, @"only the valid file imported");
    check(book.count == 1, @"one profile in the book");
    check([errors count] == 2, @"two errors reported");

    [fm removeItemAtPath:dir error:NULL];
}

static void testRename(void)
{
    printf("test: renaming keeps the group\n");

    VNCAddressBook *book = freshBook();
    [book addGroup:@"Keep"];

    VNCConnectionProfile *p = [[[VNCConnectionProfile alloc] init] autorelease];
    p.host = @"10.7.7.7"; p.friendlyName = @"Before";
    [book addProfile:p];
    [book setGroup:@"Keep" forProfile:p];

    check([book renameProfile:p toName:@"After"], @"renamed");
    check([book profileNamed:@"After"] != nil, @"found under the new name");
    check([book profileNamed:@"Before"] == nil, @"old name gone");
    checkEqual([book groupForProfile:p], @"Keep", @"group kept after rename");
}

int main(int argc, const char *argv[])
{
    @autoreleasepool
    {
        printf("VNCAddressBook tests\n");
        printf("-------------------\n");

        testAddAndCount();
        testDuplicateReplaces();
        testGroups();
        testExportImport();
        testExportWithoutPasswords();
        testXMLRoundTrip();
        testXMLWithPassword();
        testImportSkipsBadFiles();
        testRename();

        printf("-------------------\n");
        printf("%d checks, %d failures\n", gChecks, gFailures);
        return gFailures == 0 ? 0 : 1;
    }
}
