//
//  TTFormatViewController.m
//  Table Tool
//
//  Created by Andreas Aigner on 24.07.15.
//  Copyright (c) 2015 Egger Apps. All rights reserved.
//

#import "TTFormatViewController.h"
#import "CSVConfiguration.h"

@interface TTFormatViewController ()
@end

@implementation TTFormatViewController

-(instancetype)initWithNibName:(NSString *)nibName bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibName bundle:nibBundleOrNil];
    if(self) {
        _config = [[CSVConfiguration alloc]init];
    }
    return self;
}

- (IBAction)updateConfiguration:(id)sender {
    // Change a copy, so the delegate can still compare with the configuration it had before
    CSVConfiguration *config = [_config copy];
    config.encoding = [self.encodingMenu selectedTag];
    if([self.separatorControl selectedSegment] == 2) {
        config.columnSeparator = @"\t";
    }else{
        config.columnSeparator = [self.separatorControl labelForSegment:[self.separatorControl selectedSegment] ];
    }
    config.decimalMark = [self.decimalControl labelForSegment:[self.decimalControl selectedSegment]];
    
    if ([self.escapeControl selectedSegment] == 0 || [self.escapeControl selectedSegment] == 1) {
        config.quoteCharacter = @"\"";
    } else {
        config.quoteCharacter = @"";
        config.escapeCharacter = @"";
    }
    config.escapeCharacter = [[self.escapeControl labelForSegment:[self.escapeControl selectedSegment]] substringToIndex:1];
	
	config.firstRowAsHeader = (self.useFirstRowAsHeaderCheckbox.state == NSControlStateValueOn);
	
    _config = config;
    [self.delegate configurationChangedForFormatViewController:self];
}

-(void)awakeFromNib {
	[_encodingMenu removeAllItems];
	for (NSArray *encoding in [CSVConfiguration supportedEncodings]) {
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:encoding[0] action:NULL keyEquivalent:@""];
		item.tag = [encoding[1] integerValue];
		[_encodingMenu.menu addItem:item];
	}
}

-(void)selectFormatByConfig{
    [_encodingMenu selectItemWithTag:_config.encoding];
    if([_config.columnSeparator isEqualToString:@","]){
        [_separatorControl selectSegmentWithTag:0];
    }else if([_config.columnSeparator isEqualToString:@";"]){
        [_separatorControl selectSegmentWithTag:1];
    }else {
        [_separatorControl selectSegmentWithTag:2];
    }
    
    if([_config.decimalMark isEqualToString:@"."]){
        [_decimalControl selectSegmentWithTag:0];
    }else{
        [_decimalControl selectSegmentWithTag:1];
    }
    
    if([_config.escapeCharacter isEqualToString:@"\""]){
        [_escapeControl selectSegmentWithTag:0];
    }else if ([_config.escapeCharacter isEqualToString:@"\\"]) {
        [_escapeControl selectSegmentWithTag:1];
    }else {
        [_escapeControl selectSegmentWithTag:2];
    }

	self.useFirstRowAsHeaderCheckbox.state = self.config.firstRowAsHeader ? NSControlStateValueOn : NSControlStateValueOff;
}

@end
