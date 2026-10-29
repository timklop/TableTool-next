//
//  ToolbarIcons.m
//  TableTool
//
//  Created by Andreas Aigner on 31.07.15.
//  Copyright (c) 2015 CompanyName. All rights reserved.
//
//  Template images in the style of SF Symbols: the affected row or column is
//  drawn at full opacity with a plus or minus cut out, the others are faded.
//  As template images they follow the appearance (light/dark, disabled,
//  pressed) of the control they are placed in.
//

#import "ToolbarIcons.h"

typedef NS_ENUM(NSInteger, TTIconBadge) {
    TTIconBadgePlus,
    TTIconBadgeMinus,
};

static const NSSize TTIconSize = {20, 16};
static const CGFloat TTIconColumnGap = 1.5;
static const CGFloat TTIconColumnMinorExtent = 4;
static const CGFloat TTIconRowGap = 1.25;
static const CGFloat TTIconRowMinorExtent = 3;
static const CGFloat TTIconCornerRadius = 1.5;
static const CGFloat TTIconFadedAlpha = 0.35;
static const CGFloat TTIconBadgeSize = 4.5;
static const CGFloat TTIconBadgeLineWidth = 1.5;

@implementation ToolbarIcons

#pragma mark Drawing

// Draws three bars (columns if vertical, rows otherwise). The bar at highlightedIndex is wider and carries the badge.
+ (void)drawBarsVertical:(BOOL)vertical highlightedIndex:(NSInteger)highlightedIndex badge:(TTIconBadge)badge inRect:(NSRect)bounds
{
    CGFloat majorLength = vertical ? NSWidth(bounds) : NSHeight(bounds);
    CGFloat gap = vertical ? TTIconColumnGap : TTIconRowGap;
    CGFloat minorExtent = vertical ? TTIconColumnMinorExtent : TTIconRowMinorExtent;
    CGFloat highlightedExtent = majorLength - 2 * minorExtent - 2 * gap;

    CGFloat offset = 0;
    for (NSInteger i = 0; i < 3; i++) {
        // Rows are counted from the top, but Cocoa's origin is at the bottom left.
        NSInteger position = vertical ? i : 2 - i;
        BOOL highlighted = (position == highlightedIndex);
        CGFloat extent = highlighted ? highlightedExtent : minorExtent;
        NSRect barRect = vertical
            ? NSMakeRect(NSMinX(bounds) + offset, NSMinY(bounds), extent, NSHeight(bounds))
            : NSMakeRect(NSMinX(bounds), NSMinY(bounds) + offset, NSWidth(bounds), extent);
        offset += extent + gap;

        NSBezierPath *barPath = [NSBezierPath bezierPathWithRoundedRect:barRect xRadius:TTIconCornerRadius yRadius:TTIconCornerRadius];
        [[NSColor colorWithWhite:0 alpha:highlighted ? 1 : TTIconFadedAlpha] setFill];
        [barPath fill];

        if (highlighted) {
            [self cutOutBadge:badge centeredInRect:barRect];
        }
    }
}

+ (void)cutOutBadge:(TTIconBadge)badge centeredInRect:(NSRect)rect
{
    NSPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
    CGFloat halfSize = TTIconBadgeSize / 2;

    NSBezierPath *badgePath = [NSBezierPath bezierPath];
    badgePath.lineWidth = TTIconBadgeLineWidth;
    badgePath.lineCapStyle = NSLineCapStyleRound;
    [badgePath moveToPoint:NSMakePoint(center.x - halfSize, center.y)];
    [badgePath lineToPoint:NSMakePoint(center.x + halfSize, center.y)];
    if (badge == TTIconBadgePlus) {
        [badgePath moveToPoint:NSMakePoint(center.x, center.y - halfSize)];
        [badgePath lineToPoint:NSMakePoint(center.x, center.y + halfSize)];
    }

    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    context.compositingOperation = NSCompositingOperationDestinationOut;
    [[NSColor blackColor] setStroke];
    [badgePath stroke];
    [context restoreGraphicsState];
}

+ (NSImage *)imageWithBarsVertical:(BOOL)vertical highlightedIndex:(NSInteger)highlightedIndex badge:(TTIconBadge)badge accessibilityDescription:(NSString *)description
{
    NSImage *image = [NSImage imageWithSize:TTIconSize flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [ToolbarIcons drawBarsVertical:vertical highlightedIndex:highlightedIndex badge:badge inRect:dstRect];
        return YES;
    }];
    image.template = YES;
    image.accessibilityDescription = description;
    return image;
}

#pragma mark Generated Images

+ (NSImage*)imageOfAddLeftColumnIcon
{
    static NSImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = [self imageWithBarsVertical:YES highlightedIndex:0 badge:TTIconBadgePlus accessibilityDescription:@"Add Column Left"];
    });
    return image;
}

+ (NSImage*)imageOfAddRightColumnIcon
{
    static NSImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = [self imageWithBarsVertical:YES highlightedIndex:2 badge:TTIconBadgePlus accessibilityDescription:@"Add Column Right"];
    });
    return image;
}

+ (NSImage*)imageOfDeleteColumnIcon
{
    static NSImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = [self imageWithBarsVertical:YES highlightedIndex:1 badge:TTIconBadgeMinus accessibilityDescription:@"Delete Column"];
    });
    return image;
}

+ (NSImage*)imageOfAddRowBelowIcon
{
    static NSImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = [self imageWithBarsVertical:NO highlightedIndex:2 badge:TTIconBadgePlus accessibilityDescription:@"Add Row Below"];
    });
    return image;
}

+ (NSImage*)imageOfAddRowAboveIcon
{
    static NSImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = [self imageWithBarsVertical:NO highlightedIndex:0 badge:TTIconBadgePlus accessibilityDescription:@"Add Row Above"];
    });
    return image;
}

+ (NSImage*)imageOfDeleteRowIcon
{
    static NSImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = [self imageWithBarsVertical:NO highlightedIndex:1 badge:TTIconBadgeMinus accessibilityDescription:@"Delete Row"];
    });
    return image;
}

@end
