<<<<<<<< HEAD:MapboxNavigationObjc/MGLMapView+MGLNavigationAdditions.h
#import <Mapbox/MGLMapView.h>
========
#import <MapLibre/Mapbox.h>
>>>>>>>> upstream/main:MapboxNavigation/MLNMapView+MLNNavigationAdditions.h

@interface MLNMapView (MLNNavigationAdditions)

- (void)mapViewDidFinishRenderingFrameFullyRendered:(BOOL)fullyRendered;

@end
