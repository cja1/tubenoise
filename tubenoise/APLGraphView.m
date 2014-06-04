
/*
     File: APLGraphView.m
 Abstract: Displays a graph of output. This class uses Core Animation techniques to avoid needing to render the entire graph every update.
 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 
 */

#import "APLGraphView.h"

#pragma mark - Quartz Helpers

// Functions used to draw all content.
CGColorRef CreateDeviceGrayColor(CGFloat w, CGFloat a) {
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CGFloat comps[] = {w, a};
    CGColorRef color = CGColorCreate(gray, comps);
    CGColorSpaceRelease(gray);
    return color;
}

CGColorRef graphBackgroundColor() {
    static CGColorRef c = NULL;
    if (c == NULL) {
        c = CreateDeviceGrayColor(1.0, 1.0);
    }
    return c;
}

CGColorRef graphLineColor() {
    static CGColorRef c = NULL;
    if (c == NULL) {
        c = CreateDeviceGrayColor(0.5, 1.0);
    }
    return c;
}

void DrawGridlines(CGContextRef context, CGFloat x, CGFloat width) {
    for (CGFloat y = -48.5; y <= 48.5; y += 16.0) {
        CGContextMoveToPoint(context, x, y);
        CGContextAddLineToPoint(context, x + width, y);
    }
    CGContextSetStrokeColorWithColor(context, graphLineColor());
    CGContextStrokePath(context);
}


#pragma mark - GraphViewSegment

/*
 The GraphViewSegment manages up to 32 values and a CALayer that it updates with the segment of the graph that those values represent.
 */

@interface APLGraphViewSegment : NSObject

/*
 When this object gets recycled (when it falls off the end of the graph) -reset is sent to clear values and prepare for reuse.
*/
-(void)reset;


// Returns true if the layer for this segment is visible in the given rect.
-(BOOL)isVisibleInRect:(CGRect)r;

// The layer that this segment is drawing into.
@property(nonatomic, readonly) CALayer *layer;

@end


@implementation APLGraphViewSegment {
    // Need 33 values to fill 32 pixel width.
    double history[33];
    int index;
    CGColorRef lineColor;
}

-(id)initWithLineColor:(CGColorRef)thisLineColor {
    self = [super init];
    if (self != nil) {
        _layer = [[CALayer alloc] init];
        _layer.delegate = self;
        _layer.bounds = CGRectMake(0.0, -56.0, 32.0, 112.0);
        _layer.opaque = YES;
        lineColor = thisLineColor;
        
        /*
         Index represents how many slots are left to be filled in the graph, which is also +1 compared to the array index that a new entry will be added.
         */
        index = 33;
    }
    return self;
}

-(void)reset {
    // Clear out our components and reset the index to 33 to start filling values again.
    memset(history, 0, sizeof(history));
    index = 33;

    // Inform Core Animation that this layer needs to be redrawn.
    [self.layer setNeedsDisplay];
}

-(BOOL)isVisibleInRect:(CGRect)r {
    // Check if there is an intersection between the layer's frame and the given rect.
    return CGRectIntersectsRect(r, self.layer.frame);
}

-(BOOL)add:(double)val {

    // If this segment is not full, add a new value to the history.
    if (index > 0) {
        // First decrement, both to get to a zero-based index and to flag one fewer position left.
        --index;
        history[index] = val;
        // And inform Core Animation to redraw the layer.
        [self.layer setNeedsDisplay];
    }
    
    // And return if we are now full or not
    return index == 0;
}

-(void)drawLayer:(CALayer*)l inContext:(CGContextRef)context {
    // Fill in the background.
    CGContextSetFillColorWithColor(context, graphBackgroundColor());
    CGContextFillRect(context, self.layer.bounds);

    // Draw the grid lines.
    DrawGridlines(context, 0.0, 32.0);

    // Draw the graph.
    CGPoint lines[64];
    int i;
        
    // X
    for (i = 0; i < 32; ++i) {
        lines[i*2].x = i;
        lines[i*2].y = - history[i];
        lines[i*2+1].x = i + 1;
        lines[i*2+1].y = - history[i+1];
    }
    CGContextSetStrokeColorWithColor(context, lineColor);
    CGContextStrokeLineSegments(context, lines, 64);
}

-(id)actionForLayer:(CALayer *)layer forKey :(NSString *)key {
    // We disable all actions for the layer, so no content cross fades, no implicit animation on moves, etc.
    return [NSNull null];
}

@end

#pragma mark - APLGraphView

/*
 GraphView handles the public interface as well as arranging the subviews and sublayers to produce the intended effect.
*/

@interface APLGraphView()

// Internal accessors
@property (nonatomic) NSMutableArray *segments;
@property (nonatomic, weak) APLGraphViewSegment *current;

@end


@implementation APLGraphView

// Designated initializer.
-(id)initWithFrame:(CGRect)frame lineColor:(CGColorRef)thisLineColor {
    self = [super initWithFrame:frame];
    if (self != nil) {
        [self commonInitLineColor:thisLineColor];
    }
    return self;
}

-(void)commonInitLineColor:(CGColorRef)thisLineColor {
    _lineColor = thisLineColor;
    _segments = [[NSMutableArray alloc] init];
    _current = [self addSegment];
}

- (void)add:(double)val {
    // First, add the new value to the current segment.
    if ([self.current add:val]) {
        /*
         If after doing that we've filled up the current segment, then we need to determine the next current segment.
         */
        [self recycleSegment];
        // To keep the graph looking continuous, add the value to the new segment as well.
        [self.current add:val];
    }
    /*
     After adding a new data point, advance the x-position of all the segment layers by 1 to create the illusion that the graph is advancing.
    */
    for (APLGraphViewSegment *segment in self.segments) {
        CGPoint position = segment.layer.position;
        position.x += 1.0;
        segment.layer.position = position;
    }
}

/*
 kSegmentInitialPosition defines the initial position of a segment that is meant to be displayed on the left side of the graph.
 This positioning is meant so that a few entries must be added to the segment's history before it becomes visible to the user. This value could be tweaked a little bit with varying results, but the X coordinate should never be larger than 16 (the center of the text view) or the zero values in the segment's history will be exposed to the user.
 */
#define kSegmentInitialPosition CGPointMake(-17.0, 56.0);


/*
 Creates a new segment, adds it to 'segments', and returns a weak reference to that segment. Typically a graph will have around a dozen segments, but this depends on the width of the graph view and segments.
 */
- (APLGraphViewSegment *)addSegment {
    // Create a new segment and add it to the segments array.
    APLGraphViewSegment *segment = [[APLGraphViewSegment alloc] initWithLineColor:_lineColor];
    
    /*
     Add the new segment at the front of the array because -recycleSegment expects the oldest segment to be at the end of the array. As long as we always insert the youngest segment at the front this will be true.
     */
    [self.segments insertObject:segment atIndex:0];

    [self.layer insertSublayer:segment.layer atIndex:0];
    
    // Position the segment properly (see the comment for kSegmentInitialPosition).
    segment.layer.position = kSegmentInitialPosition;
    
    return segment;
}

// Recycles a segment from 'segments' into 'current'.
-(void)recycleSegment {
    /*
     Start with the last object in the segments array, because it should either be visible onscreen (which indicates that we need more segments) or pushed offscreen (which makes it eligible for recycling).
     */
    APLGraphViewSegment * last = [self.segments lastObject];
    if ([last isVisibleInRect:self.layer.bounds]) {
        // The last segment is still visible, so create a new segment, which is now the current segment.
        self.current = [self addSegment];
    }
    else {
        // The last segment is no longer visible, so reset it in preperation for being recycled.
        [last reset];
        // Position the segment properly (see the comment for kSegmentInitialPosition).
        last.layer.position = kSegmentInitialPosition;
        /*
         Move the segment from the last position in the array to the first position in the array because it is now the youngest segment,
         */
        [self.segments insertObject:last atIndex:0];
        [self.segments removeLastObject];
        // and make it the current segment.
        self.current = last;
    }
}

/*
 The graph view itself exists only to draw the background and gridlines. All other content is drawn into a layer managed by a GraphViewSegment.
 */
-(void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    // Fill in the background.
    CGContextSetFillColorWithColor(context, graphBackgroundColor());
    CGContextFillRect(context, self.bounds);

    // Draw the grid lines.
    CGFloat width = self.bounds.size.width;
    CGContextTranslateCTM(context, 0.0, 56.0);
    DrawGridlines(context, 0.0, width);
}


// Return an up-to-date value for the graph.
- (NSString *)accessibilityValue {
    if (self.segments.count == 0) {
        return nil;
    }

    // Let the GraphViewSegment handle its own accessibilityValue.
    APLGraphViewSegment *graphViewSegment = [self.segments objectAtIndex:0];
    return [graphViewSegment accessibilityValue];
}


@end

