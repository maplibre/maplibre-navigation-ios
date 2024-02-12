#import <MapLibre/Mapbox.h>

@interface MLNMapView (MLNNavigationAdditions)

- (void)mapViewDidFinishRenderingFrameFullyRendered:(BOOL)fullyRendered;

@end
