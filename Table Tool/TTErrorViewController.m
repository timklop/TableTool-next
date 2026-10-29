//
//  TTErrorViewController.m
//  Table Tool
//
//  Created by Andreas Aigner on 30.07.15.
//  Copyright (c) 2015 Egger Apps. All rights reserved.
//

#import "TTErrorViewController.h"

@interface TTErrorViewController ()

@end
@implementation TTErrorViewController

-(instancetype)initWithMessage:(NSString *)errorMessage information:(NSString *)errorInformation{

    self = [super initWithNibName:@"TTErrorViewController" bundle:nil];
    if(self) {
        [self view];
        _information.stringValue = errorInformation ?: @"";
        _message.stringValue = errorMessage ?: @"";
        [_message setFont:[NSFont boldSystemFontOfSize:NSFont.systemFontSize]];
        _icon.image = [NSImage imageWithSystemSymbolName:@"exclamationmark.triangle.fill" accessibilityDescription:@"Warning"];
        _icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:32 weight:NSFontWeightRegular];
        _icon.contentTintColor = [NSColor systemYellowColor];

        NSShadow *shadow = [[NSShadow alloc] init];
        shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.2];
        shadow.shadowOffset = NSMakeSize(0, -2);
        shadow.shadowBlurRadius = 12;
        self.view.wantsLayer = YES;
        self.view.shadow = shadow;
    }
    return self;
}

@end
