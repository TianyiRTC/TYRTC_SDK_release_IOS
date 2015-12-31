#import <UIKit/UIKit.h>
#import "mknetwork/tyrtchttpengine.h"

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
    dispatch_queue_t mGCDQueue;
    BOOL  firstCheckNetwork;
    ReachabilityRTC* hostReach;
    UIBackgroundTaskIdentifier bgTask;
}
@property (retain, nonatomic) UIWindow *window;
@property (retain, nonatomic) ViewController *viewController;

@end
