//
//  AppDelegate.m
//  Table Tool
//
//  Created by Andreas Aigner on 06.07.15.
//  Copyright (c) 2015 Egger Apps. All rights reserved.
//

#import "AppDelegate.h"
#import "Constants.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

+ (void)initialize {
    if (self == [AppDelegate class]) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{TTResizeColumnsWhenOpeningKey: @YES}];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (IBAction)toggleResizeColumnsWhenOpening:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:![defaults boolForKey:TTResizeColumnsWhenOpeningKey] forKey:TTResizeColumnsWhenOpeningKey];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(toggleResizeColumnsWhenOpening:)) {
        menuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:TTResizeColumnsWhenOpeningKey] ? NSControlStateValueOn : NSControlStateValueOff;
    }
    return YES;
}

@end
