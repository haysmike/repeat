//
//  FractalView.m
//  repeat
//
//  Created by Mike Hays on 1/15/15.
//  Copyright (c) 2015 Mike Hays. All rights reserved.
//

#include <stdio.h> // include this before gmp for output methods
#include <gmp.h>

#import "FractalView.h"

@implementation FractalView {
    NSInteger _width;
    NSInteger _height;
    double _zoom;
    double _centerX;
    double _centerY;

    int _precision;
    int _maxIterations;
    int _superSampleFactor;

    float _scaleFactor; // for retina

    NSBitmapImageRep *_imageRep;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];

    [self reshape];

    _zoom = pow(2, 7);
    _centerX = 0;
    _centerY = 0;

    _precision = 1 << 5;
    mpf_set_default_prec(_precision - 1);
    _maxIterations = 1 << 6;

    _superSampleFactor = 1;

    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)reshape
{
    NSSize size = [self frame].size;

    _width = size.width;
    _height = size.height;
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint point = [theEvent locationInWindow];

    [self panX:(point.x - _width / 2.0) * _scaleFactor
          andY:(point.y - _height / 2.0) * _scaleFactor];

    [self setNeedsDisplay:YES];
}

- (void)panX:(double)x andY:(double)y
{
    _centerX += x / _zoom;
    _centerY += y / _zoom;
}

// for zoomIn/zoomOut (Document.xib)
- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)zoomIn:(NSEvent *)event
{
    _zoom *= 2;
    [self setNeedsDisplay:YES];
}

- (void)zoomOut:(NSEvent *)event
{
    _zoom /= 2;
    [self setNeedsDisplay:YES];
}

- (void)viewDidChangeBackingProperties
{
    _scaleFactor = [[self window] backingScaleFactor];
}

- (void)viewDidEndLiveResize
{
    [self reshape];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if ([self inLiveResize]) return;

    [super drawRect:dirtyRect];

    [self printInfo];

    _imageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:dirtyRect];

    NSInteger width = [_imageRep pixelsWide];
    NSInteger height = [_imageRep pixelsHigh];
    NSDate *start = [NSDate date];
    NSUInteger numSectionsY = [[NSProcessInfo processInfo] processorCount];
    NSUInteger numSectionsX = 1;

    double top = -height / 2;
    double left = -width / 2;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    dispatch_group_t group = dispatch_group_create();
    for (int sectionY = 0; sectionY < numSectionsY; sectionY++) {
        for (int sectionX = 0; sectionX < numSectionsX; sectionX++) {
            dispatch_group_async(group, queue, ^{
                long startY = sectionY * height / numSectionsY;
                long stopY = (sectionY + 1) * height / numSectionsY;

                long startX = sectionX * width / numSectionsX;
                long stopX = (sectionX + 1) * width / numSectionsX;

                mpf_t cx, cy, zx, zy, zx_s, zy_s, zabs_s, zx_t, zy_t;
                mpf_inits(cx, cy, zx, zy, zx_s, zy_s, zabs_s, zx_t, zy_t, NULL);

                for (long y = startY; y < stopY; y++) {
                    for (long x = startX; x < stopX; x++) {
                        NSUInteger pixel[4];

                        // init black
                        pixel[0] = 0;
                        pixel[1] = 0;
                        pixel[2] = 0;
                        pixel[3] = 255;

                        for (int offsetY = 0; offsetY < _superSampleFactor; offsetY++) {
                            for (int offsetX = 0; offsetX < _superSampleFactor; offsetX++) {
                                double aslkfjd = _centerX + (left + (double)x + (double)offsetX / _superSampleFactor) / _zoom;
                                mpf_set_d(cx, aslkfjd);
                                mpf_set_d(cy, (top + (double)y + (double)offsetY / _superSampleFactor) / _zoom + _centerY);

                                mpf_set_d(zx, 0);
                                mpf_set_d(zy, 0);

                                int i = 0;

                                for (; i < _maxIterations; i++) {
                                    mpf_mul(zx_s, zx, zx);
                                    mpf_mul(zy_s, zy, zy);
                                    mpf_add(zabs_s, zx_s, zy_s);
                                    if (mpf_cmp_ui(zabs_s, 4) > 0) break;

                                    // x = x^2 - y^2 + cx
                                    mpf_sub(zx_t, zx_s, zy_s);
                                    mpf_add(zx_t, zx_t, cx);

                                    // y = 2 * x * y + cy
                                    mpf_mul_ui(zy_t, zx, 2);
                                    mpf_mul(zy_t, zy_t, zy);
                                    mpf_add(zy, zy_t, cy);
                                    
                                    mpf_set(zx, zx_t);
                                }

                                int ss_s = _superSampleFactor * _superSampleFactor;
                                if (i == _maxIterations) {
                                    pixel[1] += 0.5 * 255 / ss_s;
                                    pixel[2] += 0.7 * 255 / ss_s;
                                } else {
                                    if (i % 2 == 0) {
                                        pixel[0] += 0.8 * 255 / ss_s;
                                        pixel[1] += (1 - (double)i / _maxIterations) * 255 / ss_s;
                                        pixel[2] += (1 - (double)i / _maxIterations) * 255 / ss_s;
                                    }
                                }
                            }
                        }
                        
                        @synchronized (_imageRep) {
                            [_imageRep setPixel:pixel atX:x y:y];
                        }
                    }

                    @synchronized (_imageRep) {
                        [self lockFocusIfCanDraw];
                        [_imageRep drawInRect:dirtyRect];
                        [[NSGraphicsContext currentContext] flushGraphics];
                        [self unlockFocus];
                    }
                }
                mpf_clears(cx, cy, zx, zy, zx_s, zy_s, zabs_s, zx_t, zy_t, NULL);

            });
        }
    }
    dispatch_group_notify(group, queue, ^{
        NSDate *stop = [NSDate date];
        long numPixels = _width * _height;
        NSTimeInterval duration = [stop timeIntervalSinceDate:start];
        NSLog(@"drew %li pixels in %f seconds (%f /sec)", numPixels, duration, numPixels/duration);
    });
}

- (void)printInfo
{
    NSLog(@"- iterations: %i", _maxIterations);
    NSLog(@"- precision: %i", _precision);

    printf("_zoom = pow(2, %i);\n", (int) log2(_zoom));
    mpf_t uly, ulx;
    mpf_inits(uly, ulx, NULL);
    mpf_set_d(ulx, _centerX);
    mpf_set_d(uly, _centerY);
    printf("_centerX = ");
    mpf_out_str(stdout, 10, 0, ulx);
    printf(";\n_centerY = ");
    mpf_out_str(stdout, 10, 0, uly);
    printf(";\n\n");
    mpf_clear(uly);
}

@end
