/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 * Copyright (c) 2008 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

 /**
  * Modifications made by Appcelerator, Inc. licensed under the
  * same license as above.
  */

#import "iPhoneSimulator.h"
#import "nsprintf.h"

/**
 * A simple iPhoneSimulatorRemoteClient framework.
 */
@implementation iPhoneSimulator

/**
 * Print usage.
 */
- (void) printUsage {
    fprintf(stderr, "Usage: iphonesim <options> <command> ...\n");
    fprintf(stderr, "Commands:\n");
    fprintf(stderr, "  showsdks\n");
    fprintf(stderr, "  launch [ENVIRONMENT_VARIABLE=VALUE ...] <application path> [sdkversion] [family] [uuid]\n");
}


/**
 * List available SDK roots.
 */
- (int) showSDKs {
    NSArray *roots = [DTiPhoneSimulatorSystemRoot knownRoots];

    nsprintf(@"Simulator SDK Roots:");
    for (DTiPhoneSimulatorSystemRoot *root in roots) {
        nsfprintf(stderr, @"'%@' (%@)\n\t%@", [root sdkDisplayName], [root sdkVersion], [root sdkRootPath]);
    }

    return EXIT_SUCCESS;
}

- (void) session: (DTiPhoneSimulatorSession *) session didEndWithError: (NSError *) error {
    nsprintf(@"Session did end with error %@", error);
    
    if (error != nil)
        exit(EXIT_FAILURE);

    exit(EXIT_SUCCESS);
}


- (void) session: (DTiPhoneSimulatorSession *) session didStart: (BOOL) started withError: (NSError *) error {
    if (started) {
        nsprintf(@"Session started");
    } else {
        nsprintf(@"Session could not be started: %@", error);
        exit(EXIT_FAILURE);
    }
}


/**
 * Launch the given Simulator binary.
 */
- (int) launchApp:(NSString *) path withEnvironment:(NSDictionary *)environment withFamily:(NSString*)family uuid:(NSString*)uuid{
    DTiPhoneSimulatorApplicationSpecifier *appSpec;
    DTiPhoneSimulatorSessionConfig *config;
    DTiPhoneSimulatorSession *session;
    NSError *error;

    /* Create the app specifier */
    appSpec = [DTiPhoneSimulatorApplicationSpecifier specifierWithApplicationPath: path];
    if (appSpec == nil) {
        nsprintf(@"Could not load application specification for %s", path);
        return EXIT_FAILURE;
    }
    nsprintf(@"App Spec: %@", appSpec);

    /* Load the default SDK root */
    
    nsprintf(@"SDK Root: %@", sdkRoot);

    /* Set up the session configuration */
    config = [[[DTiPhoneSimulatorSessionConfig alloc] init] autorelease];
    [config setApplicationToSimulateOnStart: appSpec];
    [config setSimulatedSystemRoot: sdkRoot];
    [config setSimulatedApplicationShouldWaitForDebugger: NO];

    [config setSimulatedApplicationLaunchArgs: [NSArray array]];
    [config setSimulatedApplicationLaunchEnvironment: environment];

    [config setLocalizedClientName: @"TitaniumDeveloper"];

	// this was introduced in 3.2 of SDK
	if ([config respondsToSelector:@selector(setSimulatedDeviceFamily:)])
	{
		if (family == nil)
		{
			family = @"iphone";
		}

		nsprintf(@"using device family %@",family);

		if ([family isEqualToString:@"ipad"])
		{
			[config setSimulatedDeviceFamily:[NSNumber numberWithInt:2]];
		}
		else
		{
			[config setSimulatedDeviceFamily:[NSNumber numberWithInt:1]];
		}
	}

    /* Start the session */
    session = [[[DTiPhoneSimulatorSession alloc] init] autorelease];
    [session setDelegate: self];
    [session setSimulatedApplicationPID: [NSNumber numberWithInt: 35]];
	if (uuid!=nil)
	{
		[session setUuid:uuid];
	}

    if (![session requestStartWithConfig: config timeout: 30 error: &error]) {
        nsprintf(@"Could not start simulator session: %@", error);
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}


/**
 * Execute 'main'
 */
- (void) runWithArgc: (int) argc argv: (char **) argv {
	int main_argc = argc;
	char **main_argv = argv;
	int envc = 0;
	char **envv = argv;
	envv++;

	for (int i = 1; i < argc; i++) {
		if (strchr(argv[i], '=') == NULL)
			break;

		envc++;
		main_argc--;
		main_argv++;
	}

    /* Read the command */
    if (main_argc < 2) {
        [self printUsage];
        exit(EXIT_FAILURE);
    }

    if (strcmp(main_argv[1], "showsdks") == 0) {
        exit([self showSDKs]);
    }
    else if (strcmp(main_argv[1], "launch") == 0) {
        /* Requires an additional argument */
        if (main_argc < 3) {
            fprintf(stderr, "Missing application path argument\n");
            [self printUsage];
            exit(EXIT_FAILURE);
        }
        if (main_argc > 3) {
            NSString* ver = [NSString stringWithCString:main_argv[3] encoding:NSUTF8StringEncoding];
            NSArray *roots = [DTiPhoneSimulatorSystemRoot knownRoots];
            for (DTiPhoneSimulatorSystemRoot *root in roots) {
                NSString *v = [root sdkVersion];
                if ([v isEqualToString:ver])
                {
                    sdkRoot = root;
                    break;
                }
            }
            if (sdkRoot == nil)
            {
                fprintf(stderr,"Unknown or unsupported SDK version: %s\n", main_argv[3]);
                [self showSDKs];
                exit(EXIT_FAILURE);
            }
        }
        else {
            sdkRoot = [DTiPhoneSimulatorSystemRoot defaultRoot];
        }

        /* Don't exit, adds to runloop */
		NSString *family = nil;
		NSString *uuid = nil;
		if (main_argc > 4)
		{
			family = [NSString stringWithUTF8String:main_argv[4]];
		}
		if (main_argc > 5)
		{
			uuid = [NSString stringWithUTF8String:main_argv[5]];
		}
		
		NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithCapacity: envc];
		for (int i = 0; i < envc; i++) {
			NSString *arg = [NSString stringWithCString:envv[i] encoding:NSUTF8StringEncoding];
			NSArray *parts = [arg componentsSeparatedByString:@"="];

			[environment setObject:[parts objectAtIndex:1] forKey:[parts objectAtIndex:0]];
		}
        [self launchApp: [NSString stringWithUTF8String: main_argv[2]] withEnvironment:environment withFamily:family uuid:uuid];
    } else {
        fprintf(stderr, "Unknown command\n");
        [self printUsage];
        exit(EXIT_FAILURE);
    }
}

@end
