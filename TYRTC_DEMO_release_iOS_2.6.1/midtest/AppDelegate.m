#import "sdkobj.h"
#import "AppDelegate.h"
#import "ViewController.h"
#import "ReachabilityRTC.h"

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
    self.window.rootViewController = self.viewController;//viewController作为根节点控制事件监听和回调响应
    [self.window makeKeyAndVisible];
    
//    请开发者们在集成调试过程中务必开启log打印，以便于在出现问题时把log发给我们，从而快速定位问题。
//    SDKObj初始化成功后，日志就会打印到cwlog.txt中，log保存最近的500k内容，同时也会在控制台显示。
//    可通过iFunBox软件进行日志查看，软件在天翼RTC开发者支持群里可以下载，日志路径为：应用文件夹->tmp->cwlog.txt。
//    请在正式发布时注释掉此语句。
    initCWDebugLog();
    [self checkNetWorkReachability];//检测网络切换
    
    //注册本地推送
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]&&[[[UIDevice currentDevice]systemVersion]floatValue]>=8.0)
    {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound categories:nil]];
        CWLogDebug(@"registerUserNotificationSettings");
    }
    
    return YES;
}

- (void)keepAlive
{
    [self.viewController onAppEnterBackground];
}

//如果希望在后台仍能接收来电，必须实现后台重连机制
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [NSRunLoop currentRunLoop];
    //[self performSelectorOnMainThread:@selector(keepAlive) withObject:nil waitUntilDone:YES];
    [application setKeepAliveTimeout:600 handler: ^{//后台托管
        [self performSelectorOnMainThread:@selector(keepAlive) withObject:nil waitUntilDone:YES];
    }];
}

//回到前台后弹出来电界面
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self.viewController onApplicationWillEnterForeground:application];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [[UIApplication  sharedApplication] cancelAllLocalNotifications];
}

#pragma mark - NetWorkReachability
//监测网络连接状态
-(void)checkNetWorkReachability
{
    firstCheckNetwork=YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                      selector:@selector(reachabilityNetWorkStatusChanged:)
                          name: kReachabilityChangedNotificationRTC
                        object: nil];
    
    hostReach = [[ReachabilityRTC reachabilityWithHostname:@"www.apple.com"] retain];
    [hostReach startNotifier];
}

- (void) reachabilityNetWorkStatusChanged: (NSNotification* )note
{
    
    ReachabilityRTC* curReach = [note object];
    int networkStatus = [curReach currentReachabilityStatus];
//    BOOL isLogin = [self.viewController accObjIsRegisted];
//    if (isLogin)
//    {
        if (networkStatus==NotReachableRTC)
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
//    }
    
    firstCheckNetwork=NO;
}
@end
