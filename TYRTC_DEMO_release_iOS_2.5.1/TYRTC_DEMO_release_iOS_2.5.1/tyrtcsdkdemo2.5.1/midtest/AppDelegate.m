#import "AppDelegate.h"
#import "ViewController.h"
#import "Reachability.h"
#import "sdkobj.h"
#define KEEP_ALIVE_INTERVAL 600
@implementation AppDelegate

- (void)dealloc
{
    [_window release];
    [_viewController release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    self.viewController = [[ViewController alloc]init];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    initCWDebugLog();//可开启log进行调试
    [self checkNetWorkReachability];//检测网络切换
    
    return YES;
}

- (void)keepAlive
{
    [self.viewController onAppEnterBackground];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    //后台重连
    [NSRunLoop currentRunLoop];
    [self performSelectorOnMainThread:@selector(keepAlive) withObject:nil waitUntilDone:YES];
    [application setKeepAliveTimeout:KEEP_ALIVE_INTERVAL handler: ^{
        [self performSelectorOnMainThread:@selector(keepAlive) withObject:nil waitUntilDone:YES];
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self.viewController onApplicationWillEnterForeground:application];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [[UIApplication  sharedApplication] cancelAllLocalNotifications];
}

#pragma mark - NetWorkReachability

-(void)checkNetWorkReachability
{
    firstCheckNetwork=YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                      selector:@selector(reachabilityNetWorkStatusChanged:)
                          name: kReachabilityChangedNotification
                        object: nil];
    
    hostReach = [[Reachability reachabilityWithHostname:@"www.apple.com"] retain];
    [hostReach startNotifier];
}

- (void) reachabilityNetWorkStatusChanged: (NSNotification* )note
{
    
    Reachability* curReach = [note object];
    int networkStatus = [curReach currentReachabilityStatus];
    BOOL isLogin = [self.viewController accObjIsRegisted];
    if (isLogin)
    {
        if (networkStatus==NotReachable)
        {
            //网络断开后销毁网络数据
            [self.viewController onNetworkChanged:NO];
        }
        else
        {
            if (firstCheckNetwork)
            {
                firstCheckNetwork=NO;
                return;
            }
            //网络恢复后进行重连
            [self.viewController onNetworkChanged:YES];
        }
    }
    
    firstCheckNetwork=NO;
}
@end
