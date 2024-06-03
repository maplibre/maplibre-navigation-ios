#import <MapLibre/Mapbox.h>

@interface MLNMapView (MLNNavigationAdditions)

- (void)mapViewDidFinishRenderingFrameFullyRendered:(BOOL)fullyRendered
                                  frameEncodingTime:(double)frameEncodingTime
                                 frameRenderingTime:(double)frameRenderingTime;

@end
