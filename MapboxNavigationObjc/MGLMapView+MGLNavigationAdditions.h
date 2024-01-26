#import <Mapbox/MGLMapView.h>

@interface MGLMapView (MGLNavigationAdditions)

- (void)mapViewDidFinishRenderingFrameFullyRendered:(BOOL)fullyRendered;

@end
