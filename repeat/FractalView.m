//
//  FractalView.m
//  repeat
//
//  Created by Mike Hays on 1/15/15.
//  Copyright (c) 2015 Mike Hays. All rights reserved.
//

#include <stdio.h> // include this before gmp for output methods
#include <gmp.h>
#include <mpc.h>

#import "FractalView.h"

// todo:
// - memory mapped file for... pixel data? intermediates?
// - rational implementation - mpir? gmp?
// - multithread
// - 

@implementation FractalView {
    NSInteger _width;
    NSInteger _height;
    double _zoom;
    double _upperLeftX;
    double _upperLeftY;

    int _precision;
    int _maxIterations;
    int _superSampleFactor;

    float _scaleFactor; // retina

    NSBitmapImageRep *_imageRep;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];

    NSLog(@"INIT %@, %f", NSStringFromRect([self frame]), [[self window] backingScaleFactor]);

//    _zoom = pow(2, 28);
    _zoom = pow(2, 34);

//    _upperLeftX = -0.3980979741493239632; //-0.398118114; //-1.110026;//
//    _upperLeftY = -0.5862009041356185390; //0.586216996; //-0.239508;
    [self reshape];

//    -0.398097974149323963199975651150452904403209686279296875e0
//    0.58620090413561853903701148738036863505840301513671875e0

//    _upperLeftX = -0.397050418792134873768873148947022855281829833984375e0; //-0.3972790212313;
//    _upperLeftY = 0.58642190698256901892904124906635843217372894287109375e0; //0.5863877199935;
//    _upperLeftX = -0.398166772903144228212823918511276133358478546142578125;
//    _upperLeftY = 0.5861980394549817230398502942989580333232879638671875;
//    _upperLeftX = -0.398117f;
//    _upperLeftY =  0.586217f;

//    _upperLeftX = -0.398158149211667478085;
//    _upperLeftY = 0.586318868445232510567;

//    _upperLeftX = -0.39815816949703730642795562744140625;
//    _upperLeftY = 0.58631978751509450376033782958984375;

//    _upperLeftX = -0.3981584191205911338329315185546875e0;
//    _upperLeftY = 0.58632068356382660567760467529296875e0;

//    _upperLeftX = -0.39815863900003023445606231689453125e0;
//    _upperLeftY = 0.58632139538531191647052764892578125e0;

    //    new zoom: 2147483648.000000
    //    2015-01-25 22:07:47.191 fracting[7304:312651] mouseUp! {687.80078125, 453.4609375}, {1436, 855}
    //    2015-01-25 22:07:47.191 fracting[7304:312651] panX x: -30.199219, y: 25.960938, _lowerLeftX: -0.205013, _lowerLeftY: -0.671357
//    _upperLeftX = -0.20501337922563933613417930246214382350444793701171875e0;
//    _upperLeftY = -0.671357861583430359786461849580518901348114013671875e0;
    _upperLeftX = -0.20501329632428777482999748826841823756694793701171875e0;
    _upperLeftY = -0.671357811261088510690342445741407573223114013671875e0;

    _precision = (1 << 8) - 1;
    mpf_set_default_prec(_precision);
    _maxIterations = 1 << 8;   // hmm

    _superSampleFactor = 1;

    mpf_t uly, ulx;
    mpf_inits(uly, ulx, NULL);
    mpf_set_d(ulx, _upperLeftX);
    mpf_set_d(uly, _upperLeftY);
    NSLog(@"PRINTING\n");
    printf("_upperLeftX = ");
    mpf_out_str(stdout, 10, 0, ulx);
    printf(";\n_upperLeftY = ");
    mpf_out_str(stdout, 10, 0, uly);
    printf(";\n\n");
    mpf_clear(uly);


    NSLog(@"init");
    [self printInfo];

    return self;
}

- (void)reshape
{
    NSSize size = [self frame].size;

    _upperLeftX -= (size.width - _width) / _zoom;
    _upperLeftY -= (size.height - _height) / _zoom;

    _width = size.width;
    _height = size.height;
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint point = [theEvent locationInWindow];
    NSRect frame = [self frame];
    //    point.
    NSLog(@"mouseUp! %@, %@", NSStringFromPoint([self convertPoint:point fromView:nil]), NSStringFromSize(frame.size));
    [self panX:(point.x - _width / 2.0) andY:(_height / 2.0 - point.y)];
    [self setNeedsDisplay:YES];
}

- (void)panX:(double)x andY:(double)y
{
    float scaleFactor = [[self window] backingScaleFactor];
    NSLog(@"RETINAAAA, %f", scaleFactor);
    _upperLeftX += x / _zoom * scaleFactor;
    _upperLeftY += y / _zoom * scaleFactor;
    NSLog(@"panX x: %f, y: %f, _lowerLeftX: %f, _lowerLeftY: %f", x, y, _upperLeftX, _upperLeftY);

    mpf_t uly, ulx;
    mpf_inits(uly, ulx);
    mpf_set_d(ulx, _upperLeftX);
    mpf_set_d(uly, _upperLeftY);
    NSLog(@"PRINTING\n");
    printf("_upperLeftX = ");
    mpf_out_str(stdout, 10, 0, ulx);
    printf(";\n");
    printf("_upperLeftY = ");
    mpf_out_str(stdout, 10, 0, uly);
    printf(";\n\n");
    mpf_clear(uly);
}

// for zoomIn/zoomOut (Document.xib)
- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)zoomIn:(NSEvent *)event
{
    float zoom = _zoom * 2.0;

    NSLog(@"old zoom: %f, new zoom: %f", _zoom, zoom);

    _upperLeftX += (_width / _zoom - _width / zoom) * _scaleFactor / 2.0;
    _upperLeftY += (_height / _zoom - _height / zoom) * _scaleFactor / 2.0;

    _zoom = zoom;
    [self setNeedsDisplay:YES];
}

- (void)zoomOut:(NSEvent *)event
{
    float zoom = _zoom / 2.0;

    NSLog(@"old zoom: %f, new zoom: %f", _zoom, zoom);

    _upperLeftX += (_width / _zoom - _width / zoom) * _scaleFactor / 2.0;
    _upperLeftY += (_height / _zoom - _height / zoom) * _scaleFactor / 2.0;

    _zoom = zoom;
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

    _imageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:dirtyRect];

    NSInteger width = [_imageRep pixelsWide];
    NSInteger height = [_imageRep pixelsHigh];
    NSDate *start = [NSDate date];
    NSUInteger numSectionsY = [[NSProcessInfo processInfo] processorCount];
    NSUInteger numSectionsX = 1;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    dispatch_group_t group = dispatch_group_create();
    for (int sectionY = 0; sectionY < numSectionsY; sectionY++) {
        for (int sectionX = 0; sectionX < numSectionsX; sectionX++) {
            dispatch_group_async(group, queue, ^{
                long startY = sectionY * height / numSectionsY;
                long stopY = (sectionY + 1) * height / numSectionsY; // first row of next section

                long startX = sectionX * width / numSectionsX;
                long stopX = (sectionX + 1) * width / numSectionsX; // first col of next section

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
                                mpf_set_d(cx, ((double)x + (double)offsetX / _superSampleFactor) / _zoom + _upperLeftX);
                                mpf_set_d(cy, ((double)y + (double)offsetY / _superSampleFactor) / _zoom + _upperLeftY);

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
//                    NSLog(@"thread %i, row %li / %li finished!", sectionY, y, (long)stopY);
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
        [self printInfo];

    });
}

- (void)printInfo
{
    NSLog(@"- iterations: %i", _maxIterations);
    NSLog(@"- precision: %i", _precision);
    NSLog(@"- zoom: %lu", (unsigned long)_zoom);
}

@end
