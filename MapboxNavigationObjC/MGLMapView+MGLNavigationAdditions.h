//#if SWIFT_PACKAGE
//#import "Mapbox.h"
//#else
#import <Mapbox/Mapbox.h>
//#endif

@interface MGLMapView (MGLNavigationAdditions)

- (void)mapViewDidFinishRenderingFrameFullyRendered:(BOOL)fullyRendered;

@end
