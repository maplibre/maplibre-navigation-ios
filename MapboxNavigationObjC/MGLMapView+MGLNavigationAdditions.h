#import <MapLibre/Mapbox.h>

@interface MLNMapView (MGLNavigationAdditions)

- (void)mapViewDidFinishRenderingFrameFullyRendered:(BOOL)fullyRendered;

@end
