//
//  test_vnc_connection_profile.m
//  Tests for the RealVNC connection-file reader/writer.
//
//  Built and run on Linux with GNUstep (see scripts/objc_test_bench.sh);
//  the same sources compile unchanged in the macOS target.
//

#import <Foundation/Foundation.h>
#import "VNCConnectionProfile.h"

static int gFailures = 0;
static int gChecks = 0;

static void check(BOOL condition, NSString *what)
{
    gChecks++;
    if (condition)
    {
        printf("  ok   %s\n", [what UTF8String]);
    }
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
    {
        printf("  ok   %s\n", [what UTF8String]);
    }
    else
    {
        gFailures++;
        printf("  FAIL %s (expected '%s', got '%s')\n",
               [what UTF8String],
               expected ? [expected UTF8String] : "(nil)",
               actual ? [actual UTF8String] : "(nil)");
    }
}

static void testParseSimple(void)
{
    printf("test: parse a RealVNC-style connection file\n");

    NSString *text =
        @"ConnMethod=tcp\n"
        @"FriendlyName=Office PC\n"
        @"Host=192.168.1.50\n"
        @"Port=5901\n"
        @"SecurityType=VncAuth\n"
        @"Username=alexey\n";
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];

    NSString *error = nil;
    VNCConnectionProfile *profile = [VNCConnectionProfile profileFromData:data error:&error];

    check(profile != nil, @"profile parsed");
    if (profile == nil) return;

    checkEqual(profile.friendlyName, @"Office PC", @"FriendlyName");
    checkEqual(profile.host, @"192.168.1.50", @"Host");
    checkEqual(profile.port, @"5901", @"Port");
    checkEqual(profile.securityType, @"VncAuth", @"SecurityType");
    checkEqual(profile.username, @"alexey", @"Username");
    checkEqual(profile.connMethod, @"tcp", @"ConnMethod");
    checkEqual([profile displayAddress], @"192.168.1.50:5901", @"display address");
}

static void testDefaultsPort(void)
{
    printf("test: default port is applied when absent\n");

    NSString *text = @"Host=desktop.local\nFriendlyName=Desktop\n";
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSString *error = nil;
    VNCConnectionProfile *profile = [VNCConnectionProfile profileFromData:data error:&error];

    check(profile != nil, @"profile parsed");
    if (profile == nil) return;
    checkEqual(profile.port, @"5900", @"port defaults to 5900");
}

static void testRequiresHost(void)
{
    printf("test: a file without Host is rejected\n");

    NSString *text = @"FriendlyName=No host here\nPort=5900\n";
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSString *error = nil;
    VNCConnectionProfile *profile = [VNCConnectionProfile profileFromData:data error:&error];

    check(profile == nil, @"profile rejected");
    check(error != nil && [error length] > 0, @"error message set");
}

static void testUnknownParametersPreserved(void)
{
    printf("test: unknown parameters survive a round trip\n");

    NSString *text =
        @"Host=10.0.0.5\n"
        @"FriendlyName=Server\n"
        @"SomeFutureParameter=42\n"
        @"AnotherOne=hello world\n";
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSString *error = nil;
    VNCConnectionProfile *profile = [VNCConnectionProfile profileFromData:data error:&error];

    check(profile != nil, @"profile parsed");
    if (profile == nil) return;

    checkEqual([profile parameterForKey:@"SomeFutureParameter"], @"42",
               @"unknown parameter kept in memory");
    checkEqual([profile parameterForKey:@"AnotherOne"], @"hello world",
               @"second unknown parameter kept");

    NSData *out = [profile dataRepresentation];
    NSString *outText = [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding];
    check([outText rangeOfString:@"SomeFutureParameter=42"].location != NSNotFound,
          @"unknown parameter written back out");
}

static void testCommentsAndWhitespace(void)
{
    printf("test: comments and stray whitespace are ignored\n");

    NSString *text =
        @"; a comment\n"
        @"# another comment\n"
        @"\n"
        @"   Host = spaced.host   \n"
        @"   FriendlyName=  Spaced Name  \n";
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSString *error = nil;
    VNCConnectionProfile *profile = [VNCConnectionProfile profileFromData:data error:&error];

    check(profile != nil, @"profile parsed");
    if (profile == nil) return;
    checkEqual(profile.host, @"spaced.host", @"host trimmed");
    checkEqual(profile.friendlyName, @"Spaced Name", @"friendly name trimmed");
}

static void testRoundTrip(void)
{
    printf("test: write then read gives the same values\n");

    NSString *text =
        @"ConnMethod=tcp\n"
        @"FriendlyName=Workstation\n"
        @"Host=vpn.example.org\n"
        @"Port=5905\n"
        @"SecurityType=ARD\n"
        @"Username=admin\n"
        @"Encoding=Tight\n"
        @"ColorLevel=8\n"
        @"ViewOnly=1\n"
        @"Shared=1\n";
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSString *error = nil;
    VNCConnectionProfile *profile = [VNCConnectionProfile profileFromData:data error:&error];
    check(profile != nil, @"profile parsed");
    if (profile == nil) return;

    NSData *written = [profile dataRepresentation];
    VNCConnectionProfile *again = [VNCConnectionProfile profileFromData:written error:&error];
    check(again != nil, @"re-parsed");
    if (again == nil) return;

    checkEqual(again.friendlyName, profile.friendlyName, @"friendly name preserved");
    checkEqual(again.host, profile.host, @"host preserved");
    checkEqual(again.port, profile.port, @"port preserved");
    checkEqual(again.securityType, profile.securityType, @"security type preserved");
    checkEqual(again.username, profile.username, @"username preserved");
    checkEqual(again.encoding, profile.encoding, @"encoding preserved");
    checkEqual(again.colorLevel, profile.colorLevel, @"colour level preserved");
    checkEqual(again.viewOnly, profile.viewOnly, @"view-only preserved");
    checkEqual(again.shared, profile.shared, @"shared preserved");
}

static void testPasswordHandling(void)
{
    printf("test: password is exported only when set\n");

    VNCConnectionProfile *profile = [[[VNCConnectionProfile alloc] init] autorelease];
    profile.host = @"10.1.1.1";
    profile.friendlyName = @"No password";

    NSString *out = [[NSString alloc] initWithData:[profile dataRepresentation]
                                            encoding:NSUTF8StringEncoding];
    check([out rangeOfString:@"Password="].location == NSNotFound,
          @"no password written when unset");

    profile.password = @"s3cret";
    NSString *out2 = [[NSString alloc] initWithData:[profile dataRepresentation]
                                             encoding:NSUTF8StringEncoding];
    check([out2 rangeOfString:@"Password=s3cret"].location != NSNotFound,
          @"password written when set");
}

static void testFileRoundTrip(void)
{
    printf("test: write to a file and read it back\n");

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"vnc-test-profile.vnc"];

    VNCConnectionProfile *profile = [[[VNCConnectionProfile alloc] init] autorelease];
    profile.host = @"172.16.0.9";
    profile.port = @"5902";
    profile.friendlyName = @"Disk test";
    profile.securityType = @"VncAuth";

    NSString *error = nil;
    BOOL written = [profile writeToFileAtPath:path error:&error];
    check(written, @"file written");
    check(error == nil, @"no error on write");

    VNCConnectionProfile *loaded = [VNCConnectionProfile profileFromFileAtPath:path error:&error];
    check(loaded != nil, @"file loaded");
    if (loaded == nil) return;
    checkEqual(loaded.host, @"172.16.0.9", @"host from file");
    checkEqual(loaded.port, @"5902", @"port from file");
    checkEqual(loaded.friendlyName, @"Disk test", @"friendly name from file");

    [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
}

static void testCopy(void)
{
    printf("test: copying a profile\n");

    VNCConnectionProfile *profile = [[[VNCConnectionProfile alloc] init] autorelease];
    profile.host = @"copy.test";
    profile.friendlyName = @"Copy me";
    [profile setParameter:@"keepme" forKey:@"Custom"];

    VNCConnectionProfile *copy = [[profile copy] autorelease];
    checkEqual(copy.host, @"copy.test", @"host copied");
    checkEqual(copy.friendlyName, @"Copy me", @"name copied");
    checkEqual([copy parameterForKey:@"Custom"], @"keepme", @"custom parameter copied");
    check(copy != profile, @"copy is a distinct object");
}

static void testMalformedLine(void)
{
    printf("test: a malformed line is reported\n");

    NSString *text = @"Host=good.host\nthis line has no equals sign\n";
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSString *error = nil;
    VNCConnectionProfile *profile = [VNCConnectionProfile profileFromData:data error:&error];

    check(profile == nil, @"profile rejected");
    check(error != nil && [error length] > 0, @"error mentions the problem");
}

int main(int argc, const char *argv[])
{
    @autoreleasepool
    {
        printf("VNCConnectionProfile tests\n");
        printf("-----------------------\n");

        testParseSimple();
        testDefaultsPort();
        testRequiresHost();
        testUnknownParametersPreserved();
        testCommentsAndWhitespace();
        testRoundTrip();
        testPasswordHandling();
        testFileRoundTrip();
        testCopy();
        testMalformedLine();

        printf("-----------------------\n");
        printf("%d checks, %d failures\n", gChecks, gFailures);
        return gFailures == 0 ? 0 : 1;
    }
}
