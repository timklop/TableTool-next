//
//  TTTableView.h
//  Table Tool
//

#import <Cocoa/Cocoa.h>

// Shows where the table ends: outside its rows and columns there is no grid,
// and the background differs from the cells, so missing rows don't look like empty ones.
//
// Command-Return finishes editing a cell without moving to another one.
@interface TTTableView : NSTableView

@end
