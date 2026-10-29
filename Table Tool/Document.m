//
//  Document.m
//  Table Tool
//
//  Created by Andreas Aigner on 06.07.15.
//  Copyright (c) 2015 Egger Apps. All rights reserved.
//

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "Constants.h"
#import "Document.h"
#import "CSVReader.h"
#import "CSVWriter.h"
#import "CSVHeuristic.h"
#import "TTErrorViewController.h"
#import "ToolbarIcons.h"

static NSToolbarIdentifier const TTDocumentToolbarIdentifier = @"TTDocumentToolbar";
static NSToolbarItemIdentifier const TTToolbarItemAddColumn = @"TTToolbarItemAddColumn";
static NSToolbarItemIdentifier const TTToolbarItemDeleteColumn = @"TTToolbarItemDeleteColumn";
static NSToolbarItemIdentifier const TTToolbarItemAddRow = @"TTToolbarItemAddRow";
static NSToolbarItemIdentifier const TTToolbarItemDeleteRow = @"TTToolbarItemDeleteRow";
static NSToolbarItemIdentifier const TTToolbarItemConvert = @"TTToolbarItemConvert";

@interface Document () {
    NSCell *dataCell;
    NSData *savedData;
    NSArray *columnNames;
    
    NSError *readingError;
    NSView *errorControllerView;
    NSString *errorCode5;
    
    BOOL ignoreColumnDidMoveNotifications;
    BOOL newFile;
    BOOL enableEditing;
    
    NSArray *validPBoardTypes;
    
    TTErrorViewController *errorController;
    TTFormatViewController *statusBarFormatViewController;
    TTFormatViewController* accessoryViewController;
}
@property BOOL didSave;

@end

@implementation Document 

- (instancetype)init {
    self = [super init];
    if (self) {
        _data = [[NSMutableArray alloc]init];
        _maxColumnNumber = 1;
        _csvConfig = [[CSVConfiguration alloc]init];
        newFile = YES;
        errorCode5 = @"Your are not allowed to save while the input format has an error. Configure the format manually, until no error occurs.";
        _didSave = NO;
        
        [self initValidPBoardTypes];
        
        [self addObserver:self forKeyPath:@"fileURL" options:0 context:nil];
        [self addObserver:self forKeyPath:@"didSave" options:0 context:nil];
    }
    return self;
}

-(void)dealloc {
	[self removeObserver:self forKeyPath:@"fileURL"];
	[self removeObserver:self forKeyPath:@"didSave"];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    [self setUpToolbarForWindow:aController.window];
    self.tableView.style = NSTableViewStyleFullWidth;
    dataCell = [self.tableView.tableColumns.firstObject dataCell];
    // Monospaced digits keep numbers in a column aligned
    dataCell.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize weight:NSFontWeightRegular];
    [self updateTableColumns];
    
    if (!statusBarFormatViewController) {
        statusBarFormatViewController = [[TTFormatViewController alloc] initWithNibName:@"TTFormatViewController" bundle:nil];
        statusBarFormatViewController.delegate = self;
		statusBarFormatViewController.config = self.csvConfig;
    }
    
    [self.tableView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    [self.tableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
    [self.tableView registerForDraggedTypes:[NSArray arrayWithObject:TTRowInternalPboardType]];
    
    if(newFile){
        _maxColumnNumber = 3;
        [self updateTableColumns];
        [_data addObject:[[NSMutableArray alloc]init]];
        [self.tableView reloadData];
    }
    
    enableEditing = YES;

    if(readingError) dispatch_async(dispatch_get_main_queue(), ^{
        [self displayError:self->readingError];
    });

    NSView *formatBar = statusBarFormatViewController.view;
    formatBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.formatBarContainer addSubview:formatBar];
    [NSLayoutConstraint activateConstraints:@[
        [formatBar.leadingAnchor constraintEqualToAnchor:self.formatBarContainer.leadingAnchor],
        [formatBar.trailingAnchor constraintEqualToAnchor:self.formatBarContainer.trailingAnchor],
        [formatBar.topAnchor constraintEqualToAnchor:self.formatBarContainer.topAnchor],
        [formatBar.bottomAnchor constraintEqualToAnchor:self.formatBarContainer.bottomAnchor],
    ]];
    [statusBarFormatViewController selectFormatByConfig];
    [self updateWindowSubtitle];
}

#pragma mark - window, toolbar

-(void)setUpToolbarForWindow:(NSWindow *)window {
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:TTDocumentToolbarIdentifier];
    toolbar.delegate = self;
    toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    toolbar.allowsUserCustomization = YES;
    // Set after the defaults above, so a configuration the user saved wins
    toolbar.autosavesConfiguration = YES;
    window.toolbar = toolbar;
    window.toolbarStyle = NSWindowToolbarStyleUnified;
}

-(NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[TTToolbarItemAddColumn, TTToolbarItemDeleteColumn, NSToolbarSpaceItemIdentifier,
             TTToolbarItemAddRow, TTToolbarItemDeleteRow, NSToolbarFlexibleSpaceItemIdentifier,
             TTToolbarItemConvert];
}

-(NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[TTToolbarItemAddColumn, TTToolbarItemDeleteColumn, TTToolbarItemAddRow, TTToolbarItemDeleteRow,
             TTToolbarItemConvert, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier];
}

-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    if ([itemIdentifier isEqualToString:TTToolbarItemAddColumn]) {
        return [self toolbarGroupWithIdentifier:itemIdentifier
                                          label:@"Add Column"
                                         images:@[[ToolbarIcons imageOfAddLeftColumnIcon], [ToolbarIcons imageOfAddRightColumnIcon]]
                                  subitemLabels:@[@"Left", @"Right"]
                                subitemToolTips:@[@"Add a column to the left of the selection", @"Add a column to the right of the selection"]
                                         action:@selector(addColumn:)];
    }
    if ([itemIdentifier isEqualToString:TTToolbarItemAddRow]) {
        return [self toolbarGroupWithIdentifier:itemIdentifier
                                          label:@"Add Row"
                                         images:@[[ToolbarIcons imageOfAddRowAboveIcon], [ToolbarIcons imageOfAddRowBelowIcon]]
                                  subitemLabels:@[@"Above", @"Below"]
                                subitemToolTips:@[@"Add a row above the selection", @"Add a row below the selection"]
                                         action:@selector(addRow:)];
    }
    if ([itemIdentifier isEqualToString:TTToolbarItemDeleteColumn]) {
        return [self toolbarItemWithIdentifier:itemIdentifier label:@"Delete Column" toolTip:@"Delete the selected columns" image:[ToolbarIcons imageOfDeleteColumnIcon] action:@selector(deleteColumn:)];
    }
    if ([itemIdentifier isEqualToString:TTToolbarItemDeleteRow]) {
        return [self toolbarItemWithIdentifier:itemIdentifier label:@"Delete Row" toolTip:@"Delete the selected rows" image:[ToolbarIcons imageOfDeleteRowIcon] action:@selector(deleteRow:)];
    }
    if ([itemIdentifier isEqualToString:TTToolbarItemConvert]) {
        NSImage *image = [NSImage imageWithSystemSymbolName:@"square.and.arrow.up" accessibilityDescription:@"Convert"];
        return [self toolbarItemWithIdentifier:itemIdentifier label:@"Convert…" toolTip:@"Save a copy in a different CSV format" image:image action:@selector(exportFile:)];
    }
    return nil;
}

-(NSToolbarItem *)toolbarItemWithIdentifier:(NSToolbarItemIdentifier)identifier label:(NSString *)label toolTip:(NSString *)toolTip image:(NSImage *)image action:(SEL)action {
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    item.label = label;
    item.toolTip = toolTip;
    item.image = image;
    item.bordered = YES;
    item.target = self;
    item.action = action;
    return item;
}

-(NSToolbarItemGroup *)toolbarGroupWithIdentifier:(NSToolbarItemIdentifier)identifier label:(NSString *)label images:(NSArray<NSImage *> *)images subitemLabels:(NSArray<NSString *> *)subitemLabels subitemToolTips:(NSArray<NSString *> *)subitemToolTips action:(SEL)action {
    NSToolbarItemGroup *group = [NSToolbarItemGroup groupWithItemIdentifier:identifier images:images selectionMode:NSToolbarItemGroupSelectionModeMomentary labels:subitemLabels target:self action:action];
    group.label = label;
    [group.subitems enumerateObjectsUsingBlock:^(NSToolbarItem *subitem, NSUInteger idx, BOOL *stop) {
        subitem.toolTip = subitemToolTips[idx];
    }];
    return group;
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)item {
    if (item.action == @selector(deleteColumn:)) {
        return enableEditing && [self.tableView selectedColumn] != -1;
    }
    if (item.action == @selector(deleteRow:)) {
        return enableEditing && [self.tableView selectedRow] != -1;
    }
    return enableEditing;
}

-(void)updateWindowSubtitle {
    NSWindow *window = [(NSWindowController *)self.windowControllers.firstObject window];
    if (!window) return;
    NSInteger rowCount = _data.count;
    NSInteger columnCount = self.tableView.numberOfColumns;
    window.subtitle = [NSString stringWithFormat:@"%@ %@, %@ %@",
                       [NSNumberFormatter localizedStringFromNumber:@(rowCount) numberStyle:NSNumberFormatterDecimalStyle],
                       rowCount == 1 ? @"row" : @"rows",
                       [NSNumberFormatter localizedStringFromNumber:@(columnCount) numberStyle:NSNumberFormatterDecimalStyle],
                       columnCount == 1 ? @"column" : @"columns"];
}

- (void)close {
    [super close];
}


+ (BOOL)autosavesInPlace {
    return YES;
}

- (NSString *)windowNibName {
    return @"Document";
}

- (void)updateChangeCountWithToken:(id)changeCountToken forSaveOperation:(NSSaveOperationType)saveOperation {
    if (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation ) {
        self.didSave = YES;
    }
    [super updateChangeCountWithToken:changeCountToken forSaveOperation:saveOperation];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
	return [self dataWithCSVConfig:self.csvConfig error:outError];
}

-(NSData*)dataWithCSVConfig:(CSVConfiguration*)config error:(NSError**)outError {
	if(readingError){
		NSError *error = [NSError errorWithDomain:@"at.eggerapps.Table-Tool" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Could not save", NSLocalizedRecoverySuggestionErrorKey:errorCode5}];
		[self displayError:error];
		return nil;
	}
	
	NSArray *exportData = _data;
	
	if(self.csvConfig.firstRowAsHeader){
		NSMutableArray *headerRow = [[NSMutableArray alloc]init];
		for(int i = 0; i < _maxColumnNumber; i++){
			[headerRow addObject:@""];
		}
		for(NSTableColumn * col in self.tableView.tableColumns){
			[headerRow replaceObjectAtIndex:col.identifier.integerValue withObject:col.headerCell.stringValue];
		}
		exportData = [@[headerRow] arrayByAddingObjectsFromArray:exportData];
	}
	
	NSError *error;
	
	CSVWriter *writer = [[CSVWriter alloc] initWithDataArray:exportData columnsOrder:[self getColumnsOrder] configuration:config];
	NSData *finalData = [writer writeDataWithError:&error];
	if(finalData == nil){
		if(error) {
			*outError = error;
			[self displayError:error];
		}
	}
	
	return finalData;
}

-(BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError * _Nullable __autoreleasing *)outError {
    [self.undoManager removeAllActions];
	NSData *data = [NSData dataWithContentsOfURL:url options:0 error:outError];
	if (!data) {
		return NO;
	}
	CSVHeuristic *formatHeuristic = [[CSVHeuristic alloc]initWithData:data];
	for (NSString *language in [[NSUserDefaults standardUserDefaults] arrayForKey:@"AppleLanguages"]) {
		if ([language isKindOfClass:[NSString class]] && [language hasPrefix:@"zh"]) {
			formatHeuristic.preferChineseEncoding = YES;
		}
	}
	NSStringEncoding usedEncoding;
	if ([[NSString alloc] initWithContentsOfURL:url usedEncoding:&usedEncoding error:nil]) {
		formatHeuristic.encoding = usedEncoding;
	}
    newFile = NO;
    self.csvConfig = [formatHeuristic calculatePossibleFormat];
    
    savedData = data;
	
	NSError *error = nil;
	if (![self reloadDataWithError:&error]) {
		readingError = error;
		if (dataCell) [self displayError:error];
	}
	
	return YES;
}

-(BOOL)reloadDataWithError:(NSError**)error {
	[self.undoManager removeAllActions];
	
	_maxColumnNumber = 1;
	[_data removeAllObjects];
	
	NSError *outError;
	CSVReader *reader = [[CSVReader alloc ]initWithData:savedData configuration: self.csvConfig];
	columnNames = nil;
	while(!reader.isAtEnd) {
		NSArray *line = [reader readLineWithError:&outError];
		if (!line) {
			if (error) *error = outError;
			[self updateTableColumns];
			[self.tableView reloadData];
			[self updateWindowSubtitle];
			return NO;
		}
		_maxColumnNumber = MAX(_maxColumnNumber, line.count);
		if (self.csvConfig.firstRowAsHeader && !columnNames) {
			columnNames = line;
		} else {
			[_data addObject:line];
		}
	}
	
	[self updateTableColumns];
	[self.tableView reloadData];
	[self updateWindowSubtitle];
	return YES;
}


-(void)displayError:(NSError *)error {
    
    errorController = [[TTErrorViewController alloc]initWithMessage:error.localizedDescription information:error.localizedRecoverySuggestion];
    
    NSView *errorContainerView = self.tableView.enclosingScrollView.superview;
    if(errorControllerView){
        [errorContainerView replaceSubview:errorControllerView with:errorController.view];
        errorControllerView = errorController.view;
    }else{
        errorControllerView = errorController.view;
        [errorContainerView addSubview:errorControllerView positioned:NSWindowAbove relativeTo:nil];
    }
    
    [errorContainerView addConstraint:[NSLayoutConstraint constraintWithItem:errorController.view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:errorContainerView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [errorContainerView addConstraint:[NSLayoutConstraint constraintWithItem:errorController.view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:errorContainerView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [errorContainerView addConstraint:[NSLayoutConstraint constraintWithItem:errorControllerView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationLessThanOrEqual toItem:errorContainerView attribute:NSLayoutAttributeBottom multiplier:1 constant:-20]];
    [errorController.view setWantsLayer:YES];
}

#pragma mark - tableViewDataSource, delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_data count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    
    if(_data.count >= rowIndex+1) {
        NSArray *rowArray = _data[rowIndex];
        if(rowArray.count >= tableColumn.identifier.integerValue+1){
            if([rowArray[tableColumn.identifier.integerValue] isKindOfClass:[NSDecimalNumber class]]) {
                return [(NSDecimalNumber *)rowArray[tableColumn.identifier.integerValue] descriptionWithLocale:@{NSLocaleDecimalSeparator:self.csvConfig.decimalMark}];
            }
            return rowArray[tableColumn.identifier.integerValue];
        }
    }
    return nil;
}

-(void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    
    [self restoreObjectValue:object forTableColumn:tableColumn row:rowIndex reload:NO];
    [self.undoManager setActionName:@"Edit Cell"];
    
}

-(void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    if(_data.count <= rowIndex) return;
    NSTextFieldCell *textCell = cell;
    NSArray *rowArray = [_data objectAtIndex:rowIndex];
    if(rowArray.count > tableColumn.identifier.integerValue){
        if([rowArray[tableColumn.identifier.integerValue] isKindOfClass:[NSDecimalNumber class]]){
            textCell.alignment = NSTextAlignmentRight;
        }else{
            textCell.alignment = NSTextAlignmentLeft;
        }
    }
}

-(void)restoreObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex reload:(BOOL)shouldReload {
    
    NSMutableArray *rowArray = _data[rowIndex];
    if([rowArray count] <= tableColumn.identifier.integerValue) {
        for(NSUInteger i = rowArray.count; i <= tableColumn.identifier.integerValue+1; ++i){
            [rowArray addObject:@""];
        }
    }
    
    [[self.undoManager prepareWithInvocationTarget:self] restoreObjectValue:rowArray[tableColumn.identifier.integerValue] forTableColumn:tableColumn row:rowIndex reload:YES];
    
    if(![object isEqualTo:rowArray[tableColumn.identifier.integerValue]]){
        [self dataGotEdited];
    }
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^\\s*[+-]?(\\d+\\%@?\\d*|\\d*\\%@?\\d+)([eE][+-]?\\d+)?\\s*$",self.csvConfig.decimalMark,self.csvConfig.decimalMark] options:0 error:NULL];
    NSString *userInputValue = (NSString *)object;
    if([regex numberOfMatchesInString:userInputValue options:0 range:NSMakeRange(0, [userInputValue length])] == 1){
        rowArray[tableColumn.identifier.integerValue] = [NSDecimalNumber decimalNumberWithString:userInputValue locale:@{NSLocaleDecimalSeparator:self.csvConfig.decimalMark}];
    }else{
        rowArray[tableColumn.identifier.integerValue] = userInputValue;
    }
    
    _data[rowIndex] = rowArray;
    if (shouldReload) [self.tableView reloadData];
}

-(void)tableViewSelectionDidChange:(NSNotification *)notification {
    // The toolbar only revalidates after events; selection can also change without one (e.g. via accessibility)
    [self.tableView.window.toolbar validateVisibleItems];
}

-(void)tableViewColumnDidMove:(NSNotification *)aNotification {
    if(!ignoreColumnDidMoveNotifications){
        [self.undoManager setActionName:@"Move Column"];
        NSNumber *oldIndex = [aNotification.userInfo valueForKey:@"NSOldColumn"];
        NSNumber *newIndex = [aNotification.userInfo valueForKey:@"NSNewColumn"];
        [self dataGotEdited];
        [[self.undoManager prepareWithInvocationTarget:self] moveColumnFrom:newIndex.longValue toIndex:oldIndex.longValue];
    }
    [self updateTableColumnsNames];
}

-(NSArray *)getColumnsOrder{
    NSMutableArray *columnsOrder = [[NSMutableArray alloc] init];
    for(NSTableColumn *col in self.tableView.tableColumns) {
        [columnsOrder addObject:col.identifier];
    }
    return columnsOrder.copy;
}

#pragma mark - tableViewDataSource (optional methods) - drag & drop

-(void)initValidPBoardTypes
{
    validPBoardTypes = [NSArray arrayWithObjects:TTRowInternalPboardType,
                                                 NSPasteboardTypeTabularText,
                                                 NSPasteboardTypeString,
                                                 nil];
}

// Deprecated in favour of -tableView:pasteboardWriterForRow:, which writes one pasteboard item per row.
// Keep writing all dragged rows as a single tab-separated item, which is what Numbers and TextEdit expect.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (BOOL)tableView:(NSTableView *)tableView
writeRowsWithIndexes:(NSIndexSet *)rowIndexes
     toPasteboard:(NSPasteboard *)pboard
{
    if (rowIndexes == nil)
        return NO;
    
    [pboard declareTypes:validPBoardTypes owner: nil];
    
    // TTRowInternalPboardType is used for app internal movement of rows
    NSData *serializedRowIndexes = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes requiringSecureCoding:YES error:NULL];
    [pboard setData:serializedRowIndexes forType:TTRowInternalPboardType];

    NSArray *rowDataAtIndexes = [_data objectsAtIndexes:rowIndexes];
    
    // tab-separated text, for supporting drag & drop from Table Tool to table based apps like Numbers or TextEdit
    CSVConfiguration *tabSeparatedCSVConfiguration = [self.csvConfig copy];
    tabSeparatedCSVConfiguration.columnSeparator = @"\t";
    tabSeparatedCSVConfiguration.quoteCharacter = @"";
    CSVWriter *writer = [[CSVWriter alloc] initWithDataArray:rowDataAtIndexes
                                                columnsOrder:[self getColumnsOrder]
                                               configuration:tabSeparatedCSVConfiguration];
    NSString *tabSeparatedCSV = [writer writeString];
    [pboard setString:tabSeparatedCSV forType:NSPasteboardTypeTabularText];
    [pboard setString:tabSeparatedCSV forType:NSPasteboardTypeString];
    
    return YES;
}
#pragma clang diagnostic pop

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSString *type = [pboard availableTypeFromArray:validPBoardTypes];
    if ([type isEqualToString:TTRowInternalPboardType] &&
        [info draggingSource] == self.tableView &&
        tableView == self.tableView)
    { // NOTE: for now, only drag & drop within the same tableView is supported
        switch (dropOperation) {
            case NSTableViewDropAbove: return NSDragOperationMove;
            case NSTableViewDropOn:    return NSDragOperationNone;
        }
    }
    
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)destinationRow
    dropOperation:(NSTableViewDropOperation)dropOperation
{
    NSPasteboard *pboard = [info draggingPasteboard];

    NSString *type = [pboard availableTypeFromArray:validPBoardTypes];
    if ([type isEqualToString:TTRowInternalPboardType]) {
        if ([info draggingSource] == self.tableView &&
            tableView == self.tableView)
        { // NOTE: for now, only drag & drop within the same tableView is supported
            NSData *serializedDraggedRowIndexes = [pboard dataForType:TTRowInternalPboardType];
            NSIndexSet *draggedRowIndexes = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSIndexSet class] fromData:serializedDraggedRowIndexes error:NULL];
            
            return [self moveRowsAtIndexes:draggedRowIndexes toIndex:destinationRow];
        }
    }
    
    return NO;
}

- (void)addRedoStackOperationForMovingRowsAtIndexes:(NSIndexSet *)rowIndexes
                                            toIndex:(NSInteger)row
{
    [[self.undoManager prepareWithInvocationTarget:self] moveRowsAtIndexes:rowIndexes toIndex:row];
	[[self.undoManager prepareWithInvocationTarget:self.tableView] selectRowIndexes:rowIndexes byExtendingSelection:NO];
}

- (void)findLowerDropDestination:(NSInteger *)lowerDropDestination
            upperDropDestination:(NSInteger *)upperDropDestination
            forDraggedRowIndexes:(NSIndexSet *)draggedRowIndexes
               droppedAtLocation:(NSInteger)dropLocation
{
    *lowerDropDestination = dropLocation;
    *upperDropDestination = dropLocation;
    
    BOOL isRowAtDropLocationDragged = [draggedRowIndexes containsIndex:dropLocation];
    BOOL isRowBeforeDropLocationDragged = [draggedRowIndexes containsIndex:dropLocation-1];
    if (isRowAtDropLocationDragged || isRowBeforeDropLocationDragged)
    {
        NSUInteger lastIndex = (isRowAtDropLocationDragged ? dropLocation : dropLocation-1);
        NSUInteger nextIndex = dropLocation;
        while ((nextIndex = [draggedRowIndexes indexGreaterThanIndex:nextIndex]) != NSNotFound) {
            if (nextIndex > lastIndex+1)
                break;
            
            lastIndex = nextIndex;
            *upperDropDestination = nextIndex+1;
        }
        
        nextIndex = dropLocation;
        while ((nextIndex = [draggedRowIndexes indexLessThanIndex:nextIndex]) != NSNotFound) {
            if (nextIndex < (*lowerDropDestination)-1)
                break;
            
            *lowerDropDestination = nextIndex;
        }
    }
}



- (BOOL)moveRowsAtIndexes:(NSIndexSet *)draggedRowIndexes
                  toIndex:(NSInteger)dropLocation
{
    // NOTE: no need to move the destination row to itself, as it lands at the same place anyway
    //       no need also for contiguous multi-selections at and around the destination row
    
    NSInteger lowerDropDestination = dropLocation;
    NSInteger upperDropDestination = dropLocation;
    [self findLowerDropDestination:&lowerDropDestination
              upperDropDestination:&upperDropDestination
              forDraggedRowIndexes:draggedRowIndexes
                 droppedAtLocation:dropLocation];
    
    NSRange rangeOfUnmovedIndexes = NSMakeRange(lowerDropDestination, upperDropDestination-lowerDropDestination+1);

    const NSUInteger draggedRowCount = [draggedRowIndexes count];
    
    NSUInteger countOfRowsBeforeDropLocation = [draggedRowIndexes countOfIndexesInRange:NSMakeRange(0, dropLocation)];
    
    NSInteger destinationRow = dropLocation - countOfRowsBeforeDropLocation;
    
    NSIndexSet *finalIndexesAfterDropping = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(destinationRow, draggedRowCount)];
    
    NSArray *draggedRowData = [_data objectsAtIndexes:draggedRowIndexes];
    
    NSIndexSet *lowerDraggedIndexes;
    if (lowerDropDestination == 0) {
        lowerDraggedIndexes = [NSIndexSet indexSet];
    } else {
        lowerDraggedIndexes = [draggedRowIndexes indexesInRange:NSMakeRange(0, dropLocation-1)
                                                        options:NSEnumerationConcurrent
                                                    passingTest:^BOOL(NSUInteger idx, BOOL * _Nonnull stop) { return YES; }];
    }
    
    NSIndexSet *upperDraggedIndexes = [draggedRowIndexes indexesInRange:NSMakeRange(dropLocation, [_data count])
                                                                       options:NSEnumerationConcurrent
                                                                   passingTest:^BOOL(NSUInteger idx, BOOL * _Nonnull stop) { return YES; }];
    
    if ([lowerDraggedIndexes count] == 0 && [upperDraggedIndexes count] == 0) {
        // NOTE: nothing to do
        return NO;
    }
    
    if (![self.undoManager isUndoing]) {
        [self.undoManager setActionName:(draggedRowCount >= 2) ? @"Move Rows" : @"Move Row"];
    }
	[[self.undoManager prepareWithInvocationTarget:self.tableView] selectRowIndexes:draggedRowIndexes byExtendingSelection:NO];
    [[self.undoManager prepareWithInvocationTarget:self] addRedoStackOperationForMovingRowsAtIndexes:draggedRowIndexes toIndex:dropLocation];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [self.tableView beginUpdates];
        
        [[self.undoManager prepareWithInvocationTarget:self] dataGotEdited];
        
        [[self.undoManager prepareWithInvocationTarget:NSAnimationContext.self] endGrouping];
        [[self.undoManager prepareWithInvocationTarget:self.tableView] endUpdates];
        
        //
        // update model
        //
        
        [_data removeObjectsAtIndexes:draggedRowIndexes];
        
        NSEnumerator *reverseEnumerator = [draggedRowData reverseObjectEnumerator];
        id nextRowToInsert = nil;
        while (nextRowToInsert = [reverseEnumerator nextObject]) {
            NSUInteger insertionIndex = (dropLocation - countOfRowsBeforeDropLocation);
            [_data insertObject:nextRowToInsert atIndex:insertionIndex];
        }
        
        //
        // update view
        //
        
        NSUInteger draggedIndex = [lowerDraggedIndexes firstIndex];
        NSUInteger numberOfRowsMoved = 0;
        while (draggedIndex != NSNotFound) {
            if (!NSLocationInRange(draggedIndex, rangeOfUnmovedIndexes))
            {
                NSUInteger translatedOldIndex = (draggedIndex - numberOfRowsMoved);
                [self.tableView moveRowAtIndex:translatedOldIndex toIndex:lowerDropDestination-1];
                [[self.undoManager prepareWithInvocationTarget:self.tableView] moveRowAtIndex:lowerDropDestination-1 toIndex:translatedOldIndex];
            }
            
            numberOfRowsMoved++;
            draggedIndex = [lowerDraggedIndexes indexGreaterThanIndex:draggedIndex];
        }
        
        NSUInteger destinationRow = upperDropDestination;
        draggedIndex = [upperDraggedIndexes firstIndex];
        while (draggedIndex != NSNotFound) {
            if (!NSLocationInRange(draggedIndex, rangeOfUnmovedIndexes))
            {
                [self.tableView moveRowAtIndex:draggedIndex toIndex:destinationRow];
                [[self.undoManager prepareWithInvocationTarget:self.tableView] moveRowAtIndex:destinationRow toIndex:draggedIndex];
            }
            
            destinationRow++;
            draggedIndex = [upperDraggedIndexes indexGreaterThanIndex:draggedIndex];
        }
        
        [[self.undoManager prepareWithInvocationTarget:_data] insertObjects:[draggedRowData copy] atIndexes:[draggedRowIndexes copy]];
        [[self.undoManager prepareWithInvocationTarget:_data] removeObjectsAtIndexes:finalIndexesAfterDropping];
        
        [self.tableView endUpdates];
        
        [[self.undoManager prepareWithInvocationTarget:self.tableView] beginUpdates];
        [[self.undoManager prepareWithInvocationTarget:NSAnimationContext.self] beginGrouping];
    } completionHandler:^{
        [self dataGotEdited];
    }];
    
    return YES;
}

#pragma mark - updateTableView

-(void)updateTableColumns {
    if (!self.tableView) return;
    
    for(NSTableColumn *col in self.tableView.tableColumns.mutableCopy) {
        [self.tableView removeTableColumn:col];
    }
    for(int i = 0; i < _maxColumnNumber; ++i) {
        NSTableColumn *tableColumn = [[NSTableColumn alloc] initWithIdentifier:[NSString stringWithFormat:@"%d",i]];
        tableColumn.dataCell = dataCell;
		tableColumn.headerCell.stringValue = i < columnNames.count ? columnNames[i] : [self generateColumnName:i];
        ((NSCell *)tableColumn.headerCell).alignment = NSTextAlignmentCenter;
        [self.tableView addTableColumn: tableColumn];
    }
}

-(void)updateTableColumnsNames {
    if(!self.csvConfig.firstRowAsHeader){
        for(int i = 0; i < [self.tableView.tableColumns count]; i++) {
            NSTableColumn *tableColumn = self.tableView.tableColumns[i];
            tableColumn.headerCell.stringValue = [self generateColumnName:i];
            ((NSCell *)tableColumn.headerCell).alignment = NSTextAlignmentCenter;
        }
    }
}

-(NSString *)generateColumnName:(int)index {
    int columnBase = 26;
    int digitMax = 7; // ceil(log26(Int32.Max))
    NSString *digits = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    
    if (index < columnBase) {
        return [digits substringWithRange:NSMakeRange(index, 1)];
    }
    
    NSMutableArray *columnName = [[NSMutableArray alloc]initWithCapacity:digitMax];
    for(int i = 0; i < digitMax; i++) {
        columnName[i] = @"";
    }
    
    index++;
    int offset = digitMax;
    while (index > 0) {
        [columnName replaceObjectAtIndex:--offset withObject:[digits substringWithRange:NSMakeRange(--index % columnBase, 1)]];
        index /= columnBase;
    }
    
    return [columnName componentsJoinedByString:@""];
}

#pragma mark - buttonActions


- (IBAction)addRow:(NSToolbarItemGroup *)sender {
    switch (sender.selectedIndex) {
        case 0:
            [self addRowAbove:sender];
            break;
        case 1:
            [self addRowBelow:sender];
        default:
            break;
    }
}

- (IBAction)addColumn:(NSToolbarItemGroup *)sender {
    switch (sender.selectedIndex) {
        case 0:
            [self addColumnLeft:sender];
            break;
        case 1:
            [self addColumnRight:sender];
        default:
            break;
    }
}

-(void)addRowAbove:(id)sender {
    
    if(![self.tableView.window makeFirstResponder:self.tableView]) {
        NSBeep();
        return;
    }
    
    long rowIndex;
    NSIndexSet *rowIndexes = [self.tableView selectedRowIndexes];
    if(rowIndexes.count != 0){
        rowIndex = [rowIndexes firstIndex] > [rowIndexes lastIndex] ? [rowIndexes lastIndex] : [rowIndexes firstIndex];
    }else{
        rowIndex = 0;
    }
    
    [self addRowAtIndex:rowIndex];
    [self.undoManager setActionName:@"Add Line Above"];
}

-(void)addRowBelow:(id)sender {
    
    if(![self.tableView.window makeFirstResponder:self.tableView]) {
        NSBeep();
        return;
    }
    
    long rowIndex;
    NSIndexSet *rowIndexes = [self.tableView selectedRowIndexes];
    if(rowIndexes.count != 0){
        rowIndex = [rowIndexes firstIndex] > [rowIndexes lastIndex] ? [rowIndexes firstIndex]+1 : [rowIndexes lastIndex]+1;
    }else{
        rowIndex = [self.tableView numberOfRows];
    }
    
    [self addRowAtIndex:rowIndex];
    [self.undoManager setActionName:@"Add Line below"];
}

-(void)addColumnLeft:(id)sender {
    
    if(![self.tableView.window makeFirstResponder:self.tableView]) {
        NSBeep();
        return;
    }
    
    long columnIndex;
    if([self.tableView selectedColumn] == -1){
        if([self.tableView editedColumn] == -1){
            columnIndex = 0;
        } else {
            columnIndex = [self.tableView editedColumn];
        }
    } else {
        NSIndexSet *columnIndexes = [self.tableView selectedColumnIndexes];
        columnIndex = [columnIndexes firstIndex] > [columnIndexes lastIndex] ? [columnIndexes lastIndex] : [columnIndexes firstIndex];
    }
    [self addColumnAtIndex:columnIndex];
    [self.undoManager setActionName:@"Add Column left"];
}

-(void)addColumnRight:(id)sender {
    
    if(![self.tableView.window makeFirstResponder:self.tableView]) {
        NSBeep();
        return;
    }
    
    long columnIndex;
    if([self.tableView selectedColumn] == -1){
        if([self.tableView editedColumn] == -1){
            columnIndex = [self.tableView numberOfColumns];
        } else {
            columnIndex = [self.tableView editedColumn]+1;
        }
    } else {
        NSIndexSet *columnIndexes = [self.tableView selectedColumnIndexes];
        columnIndex = [columnIndexes firstIndex] > [columnIndexes lastIndex] ? [columnIndexes firstIndex]+1 : [columnIndexes lastIndex]+1;
    }
    [self addColumnAtIndex:columnIndex];
    [self.undoManager setActionName:@"Add Column right"];
}

-(IBAction)deleteColumn:(id)sender {
    
    long selectedIndex = [self.tableView selectedColumn];
    if(selectedIndex == -1 || ![self.tableView.window makeFirstResponder:self.tableView]) {
        NSBeep();
        return;
    }
    
    NSIndexSet *columnIndexes = [self.tableView selectedColumnIndexes];
    [self deleteColumnsAtIndexes:columnIndexes];
    [self.undoManager setActionName:@"Delete Column(s)"];
}

-(IBAction)deleteRow:(id)sender {
    
    long selectedIndex = [self.tableView selectedRow];
    if(selectedIndex == -1 || ![self.tableView.window makeFirstResponder:self.tableView]) {
        NSBeep();
        return;
    }
    
    NSIndexSet *rowIndexes = [self.tableView selectedRowIndexes];
    [self deleteRowsAtIndexes:rowIndexes];
    [self.undoManager setActionName:@"Delete Row(s)"];
}

#pragma mark - buttonActionImplementations

-(void)deleteRowsAtIndexes:(NSIndexSet *)rowIndexes{
    
    NSMutableArray *toDeleteRows = [[NSMutableArray alloc]initWithArray:[_data objectsAtIndexes:rowIndexes]];
    [[self.undoManager prepareWithInvocationTarget:self] restoreRowsWithContent:toDeleteRows atIndexes:rowIndexes];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [self.tableView beginUpdates];
        [_data removeObjectsAtIndexes:rowIndexes];
        [self.tableView removeRowsAtIndexes:rowIndexes withAnimation:NSTableViewAnimationSlideUp];
        [self.tableView endUpdates];
    } completionHandler:^{
        [self dataGotEdited];
    }];
}

-(void)restoreRowsWithContent:(NSArray *)rowContents atIndexes:(NSIndexSet *)rowIndexes {
    
    [[self.undoManager prepareWithInvocationTarget:self] deleteRowsAtIndexes:rowIndexes];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [self.tableView scrollRowToVisible:[rowIndexes firstIndex]];
        [self.tableView beginUpdates];
        [_data insertObjects:rowContents atIndexes:rowIndexes];
		[self.tableView insertRowsAtIndexes:rowIndexes withAnimation:NSTableViewAnimationSlideDown];
		[self.tableView selectRowIndexes:rowIndexes byExtendingSelection:NO];
        [self.tableView endUpdates];
    } completionHandler:^{
    }];
}

-(void)addRowAtIndex:(long)rowIndex {
    
    if([self.tableView numberOfColumns] == 0){
        [self addColumnAtIndex:0];
    }
    
    NSMutableArray *toInsertArray = [[NSMutableArray alloc]init];
    for (int i = 0; i < _maxColumnNumber; ++i) {
        [toInsertArray addObject:@""];
    }
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [self.tableView beginUpdates];
        [_data insertObject:toInsertArray atIndex:rowIndex];
		[self.tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:rowIndex] withAnimation:NSTableViewAnimationSlideDown];
		[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];
        [self.tableView endUpdates];
    } completionHandler:^{
        [self dataGotEdited];
    }];
    
    NSIndexSet *toRedoIndexSet = [NSIndexSet indexSetWithIndex:rowIndex];
    [[self.undoManager prepareWithInvocationTarget:self] deleteRowsAtIndexes:toRedoIndexSet];
}

-(void)addColumnAtIndex:(long) columnIndex {
    
    ignoreColumnDidMoveNotifications = YES;
    long columnIdentifier = _maxColumnNumber;
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:[NSString stringWithFormat:@"%ld",columnIdentifier]];
    col.dataCell = dataCell;
    [self.tableView addTableColumn:col];
    col.headerCell.stringValue = @"";
    [self.tableView moveColumn:[self.tableView numberOfColumns]-1 toColumn:columnIndex];
    
    for(NSMutableArray *rowArray in _data) {
        [rowArray addObject:@""];
    }
    
    _maxColumnNumber++;
    
    [self.tableView selectColumnIndexes:[NSIndexSet indexSetWithIndex:columnIndex] byExtendingSelection:NO];
    [self updateTableColumnsNames];
    [self.tableView scrollColumnToVisible:columnIndex];
    ignoreColumnDidMoveNotifications = NO;
    
    [self dataGotEdited];
    [[self.undoManager prepareWithInvocationTarget:self] deleteColumnsAtIndexes:[NSIndexSet indexSetWithIndex:columnIndex]];
}

-(void)deleteColumnsAtIndexes:(NSIndexSet *) columnIndexes{
    
    ignoreColumnDidMoveNotifications = YES;
    NSMutableArray *columnIds = [[NSMutableArray alloc]init];
    NSArray *tableColumns = self.tableView.tableColumns.copy;
    [columnIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSTableColumn *col = tableColumns[idx];
        [columnIds addObject:col.identifier];
        [self.tableView removeTableColumn:col];
    }];
    ignoreColumnDidMoveNotifications = NO;
    [self updateTableColumnsNames];
    
    long selectedIndex = [columnIndexes firstIndex] > [columnIndexes lastIndex] ? [columnIndexes lastIndex] : [columnIndexes firstIndex];
    
    if(selectedIndex == [self.tableView numberOfColumns]){
        [self.tableView selectColumnIndexes:[NSIndexSet indexSetWithIndex: [self.tableView numberOfColumns]-1] byExtendingSelection:NO];
    }else{
        [self.tableView selectColumnIndexes:[NSIndexSet indexSetWithIndex: selectedIndex] byExtendingSelection:NO];
    }
    
    [self dataGotEdited];
    [[self.undoManager prepareWithInvocationTarget:self] restoreColumns:columnIds atIndexes:columnIndexes];
    
}

-(void)restoreColumns:(NSMutableArray *)columnIds atIndexes:(NSIndexSet *)columnIndexes{
    
    ignoreColumnDidMoveNotifications = YES;
    for(int i = 0; i < columnIds.count; i++){
        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:columnIds[i]];
        col.dataCell = dataCell;
        if(self.csvConfig.firstRowAsHeader){
            col.headerCell.stringValue = [columnNames objectAtIndex:((NSString *)columnIds[i]).integerValue];
        }
        ((NSCell *)col.headerCell).alignment = NSTextAlignmentCenter;
        [self.tableView addTableColumn:col];
        [self.tableView moveColumn:[self.tableView numberOfColumns]-1 toColumn:[columnIndexes firstIndex]+i];
    }
    ignoreColumnDidMoveNotifications = NO;
    
    [self updateTableColumnsNames];
    [self.tableView selectColumnIndexes:columnIndexes byExtendingSelection:NO];
    [[self.undoManager prepareWithInvocationTarget:self]deleteColumnsAtIndexes:columnIndexes];
    
}

-(void)moveColumnFrom:(long)oldIndex toIndex:(long)newIndex {
    [self.tableView moveColumn:oldIndex toColumn:newIndex];
    [self updateTableColumnsNames];
}

#pragma mark - configuration

-(void)configurationChangedForFormatViewController:(TTFormatViewController*)formatViewController {
	self.csvConfig = formatViewController.config;
	if (!newFile) {
		NSError *outError;
		BOOL didReload = [self reloadDataWithError:&outError];
		if (!didReload) {
			readingError = outError;
			[self displayError:outError];
		} else {
			readingError = nil;
			[errorControllerView removeFromSuperview];
			errorControllerView = nil;
		}
	}
}

-(void)dataGotEdited {
    if([self.tableView selectedColumn] != -1){
        [self.tableView scrollColumnToVisible: [[self.tableView selectedColumnIndexes] firstIndex]];
    }else if([self.tableView selectedRow] != -1){
        [self.tableView scrollRowToVisible:[[self.tableView selectedRowIndexes] firstIndex]];
    }
}

#pragma mark - copy,paste,delete

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(copy:)){
       if([self.tableView selectedRow] == -1 && [self.tableView selectedColumn] == -1){
           return NO;
       }
    }
    if (menuItem.action == @selector(paste:)) {
        if(!enableEditing) {
            return NO;
        }
    }
    if (menuItem.action == @selector(delete:)) {
        if(([self.tableView selectedRow] == -1 && [self.tableView selectedColumn] == -1)|| !enableEditing){
            return NO;
        }
    }
    if (menuItem.action == @selector(deleteRow:)) {
        return enableEditing && [self.tableView selectedRow] != -1;
    }
    if (menuItem.action == @selector(deleteColumn:)) {
        return enableEditing && [self.tableView selectedColumn] != -1;
    }
    return YES;
}

-(IBAction)copy:(id)sender {
    if([self.tableView selectedRow] != -1){
        [self copyRowIndexes:[self.tableView selectedRowIndexes]];
    }else if([self.tableView selectedColumn] != -1){
        [self copyColumnIndexes:[self.tableView selectedColumnIndexes]];
    }else{
        NSBeep();
    }
    return;
}

-(void)copyRowIndexes:(NSIndexSet *)rowIndexes {
    NSMutableString *copyString = [NSMutableString string];
    
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSMutableString *rowString = [NSMutableString string];
        NSArray *row = _data[idx];
        for(NSString *columnId in [self getColumnsOrder]) {
            if(row.count <= columnId.integerValue) break;
            NSString *cellValue;
            if([row[columnId.integerValue] isKindOfClass:[NSDecimalNumber class]]){
                cellValue = [row[columnId.integerValue] descriptionWithLocale:[NSLocale currentLocale]];
            }else{
                cellValue = row[columnId.integerValue];
            }
            [self appendCell:cellValue toString:rowString];
        }
        [rowString deleteCharactersInRange:NSMakeRange(rowString.length-1, 1)];
        [copyString appendString:rowString];
        [copyString appendString:@"\n"];
    }];
    [copyString deleteCharactersInRange:NSMakeRange(copyString.length-1, 1)];
    
    NSPasteboard *generalPasteboard = [NSPasteboard generalPasteboard];
    [generalPasteboard clearContents];
    [generalPasteboard writeObjects:@[copyString]];
}

-(void)copyColumnIndexes:(NSIndexSet *)columnIndexes {
    NSMutableString *copyString = [NSMutableString string];
    
    for(int i = 0; i < [self.tableView numberOfRows];i++){
        NSMutableString *rowString = [[NSMutableString alloc]init];
        NSArray *row = _data[i];
        [columnIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            NSUInteger columnIndex = ((NSTableColumn *)self.tableView.tableColumns[idx]).identifier.integerValue;
            NSString *cellValue;
            if(row.count <= columnIndex) return;
            if([row[columnIndex] isKindOfClass:[NSDecimalNumber class]]){
                cellValue = [row[columnIndex] descriptionWithLocale:[NSLocale currentLocale]];
            }else{
                cellValue = row[columnIndex];
            }
            [self appendCell:cellValue toString:rowString];
        }];
        if(rowString.length > 0)[rowString deleteCharactersInRange:NSMakeRange(rowString.length-1, 1)];
        [copyString appendString:rowString];
        [copyString appendString:@"\n"];
    }
    [copyString deleteCharactersInRange:NSMakeRange(copyString.length-1, 1)];
    
    NSPasteboard *generalPasteboard = [NSPasteboard generalPasteboard];
    [generalPasteboard clearContents];
    [generalPasteboard writeObjects:@[copyString]];
}

-(void)appendCell:(NSString *)cell toString:(NSMutableString *)rowString {
    NSMutableString *cellValue = cell.mutableCopy;
    [cellValue replaceOccurrencesOfString:@"\t" withString:@" " options:0 range:NSMakeRange(0,cellValue.length)];
    [cellValue replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0,cellValue.length)];
    [rowString appendString:cellValue];
    [rowString appendString:@"\t"];
}

-(IBAction)paste:(id)sender {
    long toInsertIndex;
    if([self.tableView selectedRow] == -1){
        toInsertIndex = [self.tableView numberOfRows];
    } else {
        NSIndexSet *selectedRowIndexes = [self.tableView selectedRowIndexes];
        toInsertIndex = [selectedRowIndexes lastIndex] > [selectedRowIndexes firstIndex] ? [selectedRowIndexes lastIndex] + 1 : [selectedRowIndexes firstIndex] + 1;
    }
    long firstIndex = toInsertIndex;
    
    NSArray *classes = [[NSArray alloc]initWithObjects:[NSString class], nil];
    NSDictionary *options = [NSDictionary dictionary];
    NSPasteboard *generalPasteboard = [NSPasteboard generalPasteboard];
    NSArray *toInsert = [generalPasteboard readObjectsForClasses:classes options:options];
    CSVReader *reader = [[CSVReader alloc]initWithString:[toInsert lastObject] configuration:self.csvConfig];
    
    while(!reader.isAtEnd) {
        NSArray *oneReadLine = [reader readLineForPastingTo:[self getColumnsOrder] maxColumnIndex:_maxColumnNumber];
        
        for(long i = _maxColumnNumber; i < oneReadLine.count;i++){
            [self addColumnAtIndex:self.tableView.tableColumns.count];
        }
        
        [_data insertObject:oneReadLine atIndex:toInsertIndex];
        toInsertIndex++;
    }
    [self.tableView reloadData];
    
    NSIndexSet *toSelectRowIndexes = [[NSIndexSet alloc]initWithIndexesInRange:NSMakeRange(firstIndex, toInsertIndex-firstIndex)];
    [self.tableView selectRowIndexes:toSelectRowIndexes byExtendingSelection:NO];
    [[self.undoManager prepareWithInvocationTarget:self] deleteRowsAtIndexes:toSelectRowIndexes];
    [self.undoManager setActionName:@"Paste Data"];
    [self dataGotEdited];
}

-(IBAction)delete:(id)sender {
    long selectedIndex = [self.tableView selectedRow];
    if(selectedIndex == -1){
        selectedIndex = [self.tableView selectedColumn];
        if(selectedIndex == -1) {
            NSBeep();
            return;
        }
        NSIndexSet *columnIndexes = [self.tableView selectedColumnIndexes];
        [self deleteColumnsAtIndexes:columnIndexes];
        [self.undoManager setActionName:@"Delete Column(s)"];
    }else{
        NSIndexSet *rowIndexes = [self.tableView selectedRowIndexes];
        [self deleteRowsAtIndexes:rowIndexes];
        [self.undoManager setActionName:@"Delete Row(s)"];
    }
    [self dataGotEdited];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    [self updateStatusBar];
}

-(void)updateChangeCount:(NSDocumentChangeType)change {
    [super updateChangeCount:change];
    [self updateStatusBar];
    [self updateWindowSubtitle];
}

-(void)updateStatusBar {
    if (self.fileURL) {
        if (self.didSave) {
            [statusBarFormatViewController setEnabled:NO];
        } else {
            if (self.documentEdited) {
                [statusBarFormatViewController setEnabled:NO];
            } else {
                [statusBarFormatViewController setEnabled:YES];
            }
        }
    } else {
        [statusBarFormatViewController setEnabled:YES];
    }
}

#pragma mark - Menu Item Actions

-(IBAction)exportFile:(id)sender {
    
    accessoryViewController = [[TTFormatViewController alloc] initWithNibName:@"TTFormatViewControllerAccessory" bundle:nil];
    
    
    NSWindow *window = [[[self windowControllers] objectAtIndex: 0] window];
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.accessoryView = accessoryViewController.view;
    accessoryViewController.config.firstRowAsHeader = self.csvConfig.firstRowAsHeader;
    [accessoryViewController selectFormatByConfig];
    savePanel.allowedContentTypes = @[UTTypeCommaSeparatedText];
    [savePanel beginSheetModalForWindow:window completionHandler:^(NSModalResponse result){
        if (result == NSModalResponseOK)
        {
			NSError *error = nil;
			NSData *data = [self dataWithCSVConfig:self->accessoryViewController.config error:&error];
			if (!data) {
				[self presentError:error modalForWindow:window delegate:nil didPresentSelector:NULL contextInfo:NULL];
				return;
			}
			BOOL success = [data writeToURL:[savePanel URL] options:NSDataWritingAtomic error:&error];
			if (!success) {
				[self presentError:error modalForWindow:window delegate:nil didPresentSelector:NULL contextInfo:NULL];
			}
        }
    }];
}

-(IBAction)openReadme:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/jakob/TableTool/blob/master/README.md"]];
}
@end
