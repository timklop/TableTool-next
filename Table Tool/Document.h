//
//  Document.h
//  Table Tool
//
//  Created by Andreas Aigner on 06.07.15.
//  Copyright (c) 2015 Egger Apps. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CSVConfiguration.h"
#import "TTFormatViewController.h"

@interface Document : NSDocument <NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate, NSToolbarItemValidation, TTFormatViewControllerDelegate>

@property NSMutableArray *data;
@property long maxColumnNumber;
@property CSVConfiguration *csvConfig;

@property IBOutlet NSTableView *tableView;
@property IBOutlet NSView *formatBarContainer;

-(IBAction)addColumn:(NSToolbarItemGroup *)sender;
-(IBAction)addRow:(NSToolbarItemGroup *)sender;
-(IBAction)addRowAbove:(id)sender;
-(IBAction)addRowBelow:(id)sender;
-(IBAction)addColumnLeft:(id)sender;
-(IBAction)addColumnRight:(id)sender;
-(IBAction)deleteRow:(id)sender;
-(IBAction)deleteColumn:(id)sender;
-(IBAction)exportFile:(id)sender;

-(void)configurationChangedForFormatViewController:(TTFormatViewController *)formatViewController;

@end
