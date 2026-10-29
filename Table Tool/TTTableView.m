//
//  TTTableView.m
//  Table Tool
//

#import "TTTableView.h"

@implementation TTTableView

+ (NSColor *)backgroundBehindCellsColor {
    // Light grey as in Table Tool 1.x. In dark mode, as elsewhere in macOS, the content is the darker part.
    return [NSColor colorWithName:@"TTTableBackgroundColor" dynamicProvider:^NSColor *(NSAppearance *appearance) {
        BOOL dark = [[appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
        return [NSColor colorWithCalibratedWhite:dark ? 0.17 : 0.96 alpha:1];
    }];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    self.backgroundColor = [TTTableView backgroundBehindCellsColor];
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    // Command-Return finishes editing in place. Without this the field editor ignores it.
    NSEventModifierFlags modifiers = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    BOOL isReturnOrEnter = [event.charactersIgnoringModifiers isEqualToString:@"\r"] || [event.charactersIgnoringModifiers isEqualToString:@"\x03"];
    if (self.currentEditor && modifiers == NSEventModifierFlagCommand && isReturnOrEnter) {
        [self.window makeFirstResponder:self];
        return YES;
    }
    return [super performKeyEquivalent:event];
}

- (void)drawGridInClipRect:(NSRect)clipRect {
    NSInteger rowCount = self.numberOfRows;
    NSInteger columnCount = self.numberOfColumns;
    if (rowCount == 0 || columnCount == 0) return;

    NSRect tableRect = NSUnionRect([self rectOfRow:0], [self rectOfRow:rowCount - 1]);
    tableRect.size.width = NSMaxX([self rectOfColumn:columnCount - 1]) - NSMinX(tableRect);

    [NSGraphicsContext saveGraphicsState];
    NSRectClip(tableRect);
    [super drawGridInClipRect:NSIntersectionRect(clipRect, tableRect)];
    [NSGraphicsContext restoreGraphicsState];
}

@end
