#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <AVFoundation/AVCaptureSession.h>
#import "sdkobj.h"
#import "sdkkey.h"
#import "sdkerrorcode.h"
#import "ViewController.h"
#import "CCallingViewController.h"

#define APP_USER_AGENT      @"vvdemo"
#define APP_VERSION         @"V2.6.1_B20151230"
#define U1 @"5668"
#define U2 @"8889"

static int cameraIndex = 1;//切换摄像头索引，1为前置，0为后置
#if(SDK_HAS_GROUP>0)
extern int isGroupCreator;
extern SDK_GROUP_TYPE grpType;
extern int isGroup;
NSString*   joinCallID;//主动参会id
#endif

typedef enum _ACTIONSHEETTAG
{
    TAG_GROUP_TYPE_SELECT,
}ACTIONSHEETTAG;

@interface ViewController()
{
    //不要在多个interface中定义SdkObj、AccObj和CallObj，
    //SdkObj、AccObj指针有且只有一个，即同时只能有一个账户存在，
    //不要同时创建多个指针，以免造成回调代理指向不清。
    SdkObj* mSDKObj;
    AccObj* mAccObj;
    CallObj*  mCallObj;
    
    SDK_ACCTYPE         accType;
    NSString*   terminalType;
    NSString*   remoteTerminalType;
    SDK_ACCTYPE         remoteAccType;
    
#if (SDK_HAS_GROUP>0)
    NSString*   callID;
#endif
    
    BOOL isAutoRotationVideo;//是否自动适配本地采集的视频,使发送出去的视频永远是人头朝上
    int     mLogIndex;//控制上方状态栏，第三方应用可删掉此句
    IOSDisplay *remoteVideoView;//callingView传来的远端窗口
    UIView *localVideoView;//callingView传来的本地窗口
    CCallingViewController* callingView;//呼叫和通话界面
    NSString *mToken;//缓存token
    NSString *mAccountID;//获取token返回的accountid
    BOOL  isGettingToken;//正在获取token时不能重复获取
}
@end

@implementation ViewController
@synthesize mStatus;
@synthesize mUser1;
@synthesize mUser2;

/**************************************界面部分*****************************************/
-(int)getLineIndex:(int) cntIndex
{
    return cntIndex/3;
}

-(int)getColIndex:(int) cntIndex
{
    return cntIndex%3;
}

-(CGRect)calcBtnRect:(CGPoint)start index:(int)index size:(CGSize)size linSep:(int)lineSep colSep:(int)colSep
{
    int lineIdx = 0;
    int colIdx = 0;
    lineIdx = [self getLineIndex:index];
    colIdx = [self getColIndex:index];
    CGFloat x = start.x + colIdx*(size.width+colSep);
    CGFloat y = start.y + lineIdx*(size.height+lineSep);
    return CGRectMake(x, y, size.width, size.height);
}

-(BOOL)addGridBtn:(NSString*)title  func:(SEL)func rect:(CGRect)rect
{
    UIButton* btnItem = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btnItem.frame = rect;
    [btnItem addTarget:self action:func forControlEvents:UIControlEventTouchDown];
    [btnItem setTitle:title forState:UIControlStateNormal];
    [btnItem setBackgroundColor:[UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1]];
    [btnItem.layer setMasksToBounds:YES];
    [btnItem.layer setCornerRadius:10.0];
    [self.view addSubview:btnItem];
    
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view = [[UIView alloc]initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    self.view.backgroundColor = [UIColor whiteColor];
    UITextField* tfItem = nil;
    CGRect tfItemFrame;
    CGRect lblItemFrame;
    
    CGFloat sep = 4;
    CGFloat height = 30;
    CGFloat lblWidth = 80;
    CGFloat lblSep = 10;
    CGFloat x = 10;
    CGFloat y = 20;
    CGRect btnItemRect;
    UIButton* btnItem;
    
    tfItemFrame = CGRectMake(x, y, 200, height);
    
    //上方状态栏mStatus显示log，第三方应用可删除
    btnItemRect = CGRectMake(x, y, 50, height);
    btnItem = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btnItem.frame = btnItemRect;
    btnItem.backgroundColor = [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1];
    [btnItem.layer setMasksToBounds:YES];
    [btnItem.layer setCornerRadius:10.0];
    [btnItem setTitle:@"日志" forState:UIControlStateNormal];
    
    [self.view addSubview:btnItem];
    
    tfItem = [[UITextField alloc]initWithFrame:CGRectMake(20+height+10, y, 300-height-10, 30)];
    tfItem.placeholder = @"操作日志";
    tfItem.textAlignment = NSTextAlignmentLeft;
    tfItem.borderStyle = UITextBorderStyleRoundedRect;
    tfItem.keyboardType = UIKeyboardTypeNumberPad;
    [self.view addSubview:tfItem];
    mStatus = tfItem;
    [tfItem release];
    
    tfItemFrame.origin.y += sep + height;
    lblItemFrame = CGRectMake(x, tfItemFrame.origin.y, lblWidth, height);
    tfItemFrame = CGRectMake(x + lblWidth+lblSep, tfItemFrame.origin.y, 310-x-lblWidth-lblSep, height);
    btnItem = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btnItem.frame = lblItemFrame;
    [btnItem setTitle:@"本地账号" forState:UIControlStateNormal];
    btnItem.backgroundColor = [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1];
    [btnItem.layer setMasksToBounds:YES];
    [btnItem.layer setCornerRadius:10.0];
    [self.view addSubview:btnItem];
    tfItem = [[UITextField alloc]initWithFrame:tfItemFrame];
    tfItem.placeholder = @"本地账号";
    tfItem.textAlignment = NSTextAlignmentLeft;
    tfItem.borderStyle = UITextBorderStyleRoundedRect;
    tfItem.keyboardType = UIKeyboardTypeNumberPad;
    [self.view addSubview:tfItem];
    mUser1 = tfItem;
    [tfItem release];
    
    tfItemFrame.origin.y += sep + height;
    lblItemFrame = CGRectMake(x, tfItemFrame.origin.y, lblWidth, height);
    tfItemFrame = CGRectMake(x + lblWidth+lblSep, tfItemFrame.origin.y, 310-x-lblWidth-lblSep, height);
    btnItem = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btnItem.frame = lblItemFrame;
    [btnItem setTitle:@"远端账号" forState:UIControlStateNormal];
    btnItem.backgroundColor = [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1];
    [btnItem.layer setMasksToBounds:YES];
    [btnItem.layer setCornerRadius:10.0];
    [self.view addSubview:btnItem];
    tfItem = [[UITextField alloc]initWithFrame:tfItemFrame];
    tfItem.placeholder = @"远端账号";
    tfItem.textAlignment = NSTextAlignmentLeft;
    tfItem.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:tfItem];
    mUser2 = tfItem;
    [tfItem release];
    
    CGFloat xSep = 50;
    CGFloat width = 80;
    
    btnItemRect = lblItemFrame;
    btnItemRect.origin.y += sep + height;
    btnItemRect.size.width = width;
    btnItemRect.size.height = height;
    btnItemRect.origin.x = 0;
    
    int totalIndex = 0;
    CGRect rect;
    CGPoint start = CGPointMake(xSep, lblItemFrame.origin.y+sep+height+5);
    CGSize size = CGSizeMake(width, height);
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    [self addGridBtn:@"登录"         func:@selector(onInit:)         rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    [self addGridBtn:@"注销"       func:@selector(onUnRegister:)       rect:rect];
    
    totalIndex++;
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    [self addGridBtn:@"音频呼叫"    func:@selector(onMakeAudioCall:)    rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    [self addGridBtn:@"视频呼叫"    func:@selector(onMakeVideoCall:)    rect:rect];
    totalIndex++;
    
#if (SDK_HAS_GROUP>0)
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    [self addGridBtn:@"多人会话"   func:@selector(onGroupCall:)     rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    [self addGridBtn:@"会话类型"   func:@selector(onSetGroupType:)     rect:rect];
    
    totalIndex++;
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    [self addGridBtn:@"会话列表"   func:@selector(onGetGroupList:)     rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    [self addGridBtn:@"加入会话"   func:@selector(onGroupJoin:)     rect:rect];
    
    totalIndex++;
#endif
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    [self addGridBtn:@"发送消息"   func:@selector(onBtnSendIM:)     rect:rect];
    
    //在这里绑定监听函数，监听callingview的button响应里抛出的事件
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRecvEvent:) name:@"NOTIFY_EVENT" object:nil];
   
    //初始化变量
    [mUser1 setText:U1];
    [mUser2 setText:U2];
    mSDKObj = nil;
    mAccObj = nil;
    mLogIndex = 0;
    [self setLog:APP_VERSION];

    isAutoRotationVideo = YES;
    isGettingToken = NO;
    
    accType = ACCTYPE_APP;
    terminalType = TERMINAL_TYPE_PHONE;
    [terminalType retain];
    
    remoteAccType = ACCTYPE_APP;
    remoteTerminalType = TERMINAL_TYPE_ANY;
    [remoteTerminalType retain];
    
#if (SDK_HAS_GROUP>0)
    callID = @"";
    [callID retain];
#endif
    
    UITapGestureRecognizer *tapGr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onKeyboard:)];
    tapGr.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGr];
    [tapGr release];
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [mStatus release];
    [mUser1 release];
    [mUser2 release];
    [terminalType release];
    [remoteTerminalType release];
#if (SDK_HAS_GROUP>0)
    [callID release];
#endif
    [remoteVideoView release];
    remoteVideoView = nil;
    [localVideoView release];
    localVideoView = nil;
    [super dealloc];
}

- (IBAction)onKeyboard:(id)sender
{
    [mUser1 resignFirstResponder];
    [mUser2 resignFirstResponder];
    [mStatus resignFirstResponder];
}

/**************************************初始化sdk*****************************************/
- (IBAction)onInit:(id)sender
{
    if(!isGettingToken)
    {
        isGettingToken = YES;
        [self onSDKInit];
    }
}

- (void)onSDKInit
{
    if (mSDKObj && [mSDKObj isInitOk])
    {
        //若sdk已成功初始化，请不要重复创建，更不要频繁重复向RTC平台发送请求
        [self setLog:@"已初始化成功"];
        [self onRegister];
        return;
    }
    
    signal(SIGPIPE, SIG_IGN);
    mLogIndex = 0;
    mSDKObj = [[SdkObj alloc]init];//创建sdkobj指针
    
    //设置sdk基础信息，在此传入您在RTC平台申请的AppId和AppKey，
    //demo中的AppId和AppKey只用于测试，不可用于应用的正式发布使用，
    //APP_USER_AGENT参数应用自定义，一般传入应用名称即可
    //UDID传入[OpenUDID value]即可
    [mSDKObj setSdkAgent:APP_USER_AGENT terminalType:terminalType UDID:[OpenUDIDRTC value] appID:@"70038" appKey:@"MTQxMDkyMzU1NTI4Ng=="];
    
    [mSDKObj setDelegate:self];//必须设置回调代理，否则无法执行回调
    [mSDKObj doNavigation:@"default"];//参数传入@"default"即可，采用平台默认地址
}

/**************************************用户登录/注销*****************************************/
- (void)onRegister
{
    if(!mSDKObj)//只有sdkobj初始化成功才可以创建accobj
    {
        [self setLog:@"请先初始化"];
        CWLogDebug(@"isGettingToken:%d",isGettingToken);
        if(!isGettingToken)
        {
            isGettingToken = YES;
            CWLogDebug(@"初始化rtc");
            [self doUnRegister];
            [self onSDKInit];
        }
        return;
    }
    if (!mAccObj)
    {
        [self setLog:@"登录中..."];
        mAccObj = [[AccObj alloc]init];//创建accobj
        [mAccObj bindSdkObj:mSDKObj];//必须与sdkobj绑定
        [mAccObj setDelegate:self];//必须设置回调代理，否则无法执行回调
        
        //此句getToken代码为临时做法，开发者需参考文档通过第三方应用平台获取token，不要通过此接口获取
        //获取到返回结果后，请调用doAccRegister接口进行注册，传入参数为服务器返回的结构
        //请在应用层做好token的缓存，不要重复获取token，除非token失效才需重新获取
        if(!mToken)
            [mAccObj getToken:mUser1.text andType:accType andGrant:@"100<200<301<302<303<304<400" andAuthType:ACC_AUTH_TO_APPALL];
        else
        {
            isGettingToken = NO;
            NSMutableDictionary *newResult = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
            [newResult setObject:mToken forKey:KEY_CAPABILITYTOKEN];
            [newResult setObject:mAccountID forKey:KEY_RTCACCOUNTID];//形如"账号类型-账号~appid~终端类型@chinartc.com"
            //[newResult setObject:[NSNumber numberWithDouble:2] forKey:KEY_ACC_SRTP];//若与浏览器互通则加上此句
            [mAccObj doAccRegister:newResult];
        }
    }
    else if ([mAccObj isRegisted])//若已登录成功，则不需要重复获取token，只要刷新即可，此时token不会改变
    {
        isGettingToken = NO;
        [self setLog:@"登录刷新"];
        [mAccObj doRegisterRefresh];
    }
    else
    {
        [self setLog:@"重新发起登录动作"];
        [mAccObj getToken:mUser1.text andType:accType andGrant:@"100<200<301<302<303<304<400" andAuthType:ACC_AUTH_TO_APPALL];
    }
}

- (IBAction)onUnRegister:(id)sender
{
    [self doUnRegister];
}

- (void)doUnRegister
{
    //切换账号前，需先将当前账号注销，释放accobj，然后再发起新的登录操作
    if (mAccObj)
    {
        [mAccObj doUnRegister];
        [mAccObj release];
        mAccObj = nil;
        mToken = nil;
        mAccountID = nil;
        [self setLog:@"注销完毕"];
    }
    //注销账号可以不释放sdkobj，但必须释放accobj
    //demo由于初始化和登录在一个button完成，所以此处要销毁sdkobj
    if(mSDKObj)
    {
        [mSDKObj release];
        mSDKObj = nil;
        mLogIndex = 0;
        [self setLog:@"release完毕"];
    }
}

- (void)checkUserStatus:(NSString*)accIds
{
    [self setLog:@"检查用户状态..."];
    if (nil == mAccObj)
    {
        [self setLog:@"请先登录"];
        return;
    }
    [mAccObj doAccStatusQuery:accIds andSearchFlag:ACC_SEARCH_ALL];//请求查询账号在线状态，多个账号以逗号隔开
}

/**************************************创建呼叫界面*****************************************/
//音频呼叫
- (IBAction)onMakeAudioCall:(id)sender
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    CCallingViewController* view1 = [[CCallingViewController alloc]init];
    view1.isVideo = NO;
    view1.isCallOut = YES;
    
#if(SDK_HAS_GROUP>0)
    isGroup = 0;
#endif
    
    view1.view.frame = self.view.frame;
    callingView = view1;
    [self presentViewController:view1 animated:NO completion:nil];//触发onSendVideoParam
    [view1 release];
}

//视频呼叫
- (IBAction)onMakeVideoCall:(id)sender
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    CCallingViewController* view1 = [[CCallingViewController alloc]init];
    view1.isVideo = YES;
    view1.isCallOut = YES;
    
#if(SDK_HAS_GROUP>0)
    isGroup = 0;
#endif
    
    view1.isAutoRotate = isAutoRotationVideo;
    view1.view.frame = self.view.frame;
    callingView = view1;
    [self presentViewController:view1 animated:NO completion:nil];//触发onSendVideoParam
    [view1 release];
}

#if (SDK_HAS_GROUP>0)
//多人呼叫
- (IBAction)onGroupCall:(id)sender
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    CCallingViewController* view1 = [[CCallingViewController alloc]init];
    view1.isCallOut = YES;
    isGroup = 1;
    if(grpType>=20)
    {
        view1.isVideo = YES;
        view1.isAutoRotate = isAutoRotationVideo;
    }
    else
        view1.isVideo = NO;
    view1.view.frame = self.view.frame;
    callingView = view1;
    [self presentViewController:view1 animated:NO completion:nil];//触发onSendVideoParam
    [view1 release];
}

//加入多人
- (IBAction)onGroupJoin:(id)sender
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    CCallingViewController* view1 = [[CCallingViewController alloc]init];
    view1.isCallOut = YES;
    isGroup = 2;
    if(grpType>=20)
    {
        view1.isVideo = YES;
        view1.isAutoRotate = isAutoRotationVideo;
    }
    else
        view1.isVideo = NO;
    view1.view.frame = self.view.frame;
    callingView = view1;
    [self presentViewController:view1 animated:NO completion:nil];//触发onSendVideoParam
    [view1 release];
}

//发送IM消息，结果在onReceiveIM回调
- (IBAction)onBtnSendIM:(id)sender
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    NSString* remoteUri = mUser2.text;
    NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                         remoteUri,KEY_CALLED,
                         [NSNumber numberWithInt:remoteAccType],KEY_CALL_REMOTE_ACC_TYPE,
                         remoteTerminalType,KEY_CALL_REMOTE_TERMINAL_TYPE,
                         @"hello world",KEY_CALL_INFO,
                         nil];
    [mAccObj doSendIM:dic];
}

//设置多人会议类型
-(IBAction)onSetGroupType:(id)sender
{
    UIActionSheet* act = [[UIActionSheet alloc]initWithTitle:@"Group Type Select"
                                                    delegate:self
                                           cancelButtonTitle:@"Cancel"
                                      destructiveButtonTitle:nil
                                           otherButtonTitles:
                          @"CHAT_A",
                          @"SPEAK_A",
                          @"TWO_A",
                          @"LIVE_A",
                          @"CHAT_V",
                          @"SPEAK_V",
                          @"TWO_V",
                          @"LIVE_V",
                          nil];
    act.tag = TAG_GROUP_TYPE_SELECT;
    [act showInView:self.view];
    [act release];
}

//获取多人会议列表，结果在onNotifyMesage回调
- (IBAction)onGetGroupList:(id)sender
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    NSString* remoteUri = mUser1.text;
    NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                         remoteUri,KEY_GRP_CREATER,
                         terminalType,KEY_GRP_CREATERTYPE,
                         [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                         nil];
    int ret = [mAccObj getGroupList:dic];
}
#endif

//关闭并销毁callingview
-(void)closeCallingView
{
    @synchronized(self) {
        if (callingView)
        {
            [callingView dismissViewControllerAnimated:NO completion:nil];
        }
        else
        {
            for(UIView * v in self.view.subviews)
            {
                if (v.tag == CALLINGVIEW_TAG)
                {
                    [v removeFromSuperview];
                }
            }
        }
        callingView = nil;
    }
}

-(void)setLog:(NSString*)log
{
    NSDateFormatter *dateFormat=[[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"HH:mm:ss"];
    NSString* datestr = [dateFormat stringFromDate:[NSDate date]];
    [dateFormat release];
    
    CWLogDebug(@"SDKTEST:%@:%@",datestr,log);
    NSString* str = [NSString stringWithFormat:@"%@:%@",datestr,log];
    [mStatus setText:str];
    [[NSUserDefaults standardUserDefaults]setObject:str forKey:[NSString stringWithFormat:@"ViewLog%d",mLogIndex]];
    mLogIndex++;
}

#pragma mark - UIActionSheetDelegate
/**************************************事件监听*****************************************/

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    #if (SDK_HAS_GROUP>0)
    if (actionSheet.tag == TAG_GROUP_TYPE_SELECT)
    {
        int idx = buttonIndex - actionSheet.firstOtherButtonIndex;
        if (idx >= 0 && idx <= 7)
        {
            switch (idx)
            {
                case 1:
                    grpType = SDK_GROUP_SPEAK_AUDIO;
                    break;
                case 2:
                    grpType = SDK_GROUP_TWOVOICE_AUDIO;
                    break;
                case 3:
                    grpType = SDK_GROUP_MICROLIVE_AUDIO;
                    break;
                case 4:
                    grpType = SDK_GROUP_CHAT_VIDEO;
                    break;
                case 5:
                    grpType = SDK_GROUP_SPEAK_VIDEO;
                    break;
                case 6:
                    grpType = SDK_GROUP_TWOVOICE_VIDEO;
                    break;
                case 7:
                    grpType = SDK_GROUP_MICROLIVE_VIDEO;
                    break;
                default:
                    grpType = SDK_GROUP_CHAT_AUDIO;
                    break;
            }
        }
        return;
    }
    #endif
}

-(void)onRecvEvent:(NSNotification *)notification
{
    if (nil == notification)
    {
        return;
    }
    if (nil == [notification userInfo])
    {
        return;
    }
    NSDictionary *data=[notification userInfo];
    int msgid = [[data objectForKey:@"msgid"]intValue];
    int arg = [[data objectForKey:@"arg"]intValue];
    
    if (MSG_NEED_VIDEO == msgid)//发起呼叫
    {
        //将callingview的视频窗口传过来
        //第三方应用也可将窗口指针定义为全局变量，不这样传递
        long long localV = [[data objectForKey:@"lvideo"]longLongValue];
        long long remoteV = [[data objectForKey:@"rvideo"]longLongValue];
        remoteVideoView = (IOSDisplay*)remoteV;
        localVideoView = (UIView*)localV;
        BOOL isCallOut = [[data objectForKey:@"iscallout"]boolValue];
        
        if (nil == mCallObj && isCallOut )//当callobj不存在且为主叫时创建
        {
            mCallObj = [[CallObj alloc]init];//创建callobj
            [mCallObj setDelegate:self];//必须设置回调代理，否则无法执行回调
            [mCallObj bindAcc:mAccObj];//必须绑定accobj
            
#if (SDK_HAS_VIDEO>0)
            SDK_CALLTYPE callType = (remoteV != 0)? AUDIO_VIDEO:AUDIO;
            mCallObj.CallMedia = (remoteV != 0)? MEDIA_TYPE_VIDEO:MEDIA_TYPE_AUDIO;
#else
            SDK_CALLTYPE callType = AUDIO;
            mCallObj.CallMedia = MEDIA_TYPE_AUDIO;
#endif
            NSString* remoteUri = mUser2.text;
            
            //dic参数应用自定义
            NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 remoteUri,KEY_CALLED,
                                 [NSNumber numberWithInt:callType],KEY_CALL_TYPE,
                                 [NSNumber numberWithInt:remoteAccType],KEY_CALL_REMOTE_ACC_TYPE,
                                 remoteTerminalType,KEY_CALL_REMOTE_TERMINAL_TYPE,
                                 @"yewuxinxi",KEY_CALL_INFO,//KEY_CALL_INFO不可包含逗号，多个信息用分号隔开
                                 nil];
            int ret = [mCallObj doMakeCall:dic];
            [mCallObj doSwitchAudioDevice:SDK_AUDIO_OUTPUT_DEFAULT];
            
            if (EC_OK > ret)
            {
                if (mCallObj)//若通话失败或结束，必须释放callobj
                {
                    //[mCallObj doHangupCall];
                    [mCallObj release];
                    mCallObj = nil;
                }
                
                [self closeCallingView];
                [self setLog:[NSString stringWithFormat:@"创建呼叫失败:%@",[SdkObj ECodeToStr:ret]]];//错误码含义请参照sdkerrorcode.h
            }
        }
        return;
    }
    if (MSG_SET_AUDIO_DEVICE == msgid)//切换音频输出设备
    {
        if (!mCallObj)
        {
            [self setLog:@"切换放音设备前请先呼叫"];
            return;
        }
        //SDK_AUDIO_OUTPUT_DEVICE ad = [mCallObj getAudioOutputDeviceType];
        if (arg == 1/*SDK_AUDIO_OUTPUT_DEFAULT == ad || SDK_AUDIO_OUTPUT_HEADSET == ad*/)
        {
            [mCallObj doSwitchAudioDevice:SDK_AUDIO_OUTPUT_SPEAKER];
            [callingView setCallStatus:@"放音设备切换到外放"];
        }
        else
        {
            [mCallObj doSwitchAudioDevice:SDK_AUDIO_OUTPUT_DEFAULT];
            [callingView setCallStatus:@"放音设备切换到听筒/耳机"];
        }
        
        return;
    }
    if (MSG_HANGUP == msgid)//挂断
    {
        if (mCallObj)//若通话失败或结束，必须释放callobj
        {
            [mCallObj doHangupCall];
            [mCallObj release];
            mCallObj = nil;
        }
        cameraIndex = 1;
#if (SDK_HAS_GROUP>0)
        [callID release];
        callID = @"";
        [callID retain];
#endif
        [callingView onCallOk:NO];
        [self closeCallingView];
        [self setLog:@"呼叫已结束"];
        return;
    }
    if (MSG_ACCEPT == msgid)//接听
    {
        if (mCallObj.CallMedia == MEDIA_TYPE_AUDIO)
        {
            [mCallObj doAcceptCall:[NSNumber numberWithInt:AUDIO]];
        }
#if (SDK_HAS_VIDEO>0)
        else
        {
            long long localV = [[data objectForKey:@"lvideo"]longLongValue];
            long long remoteV = [[data objectForKey:@"rvideo"]longLongValue];
            remoteVideoView = (IOSDisplay*)remoteV;
            localVideoView = (UIView*)localV;
            [mCallObj doAcceptCall:[NSNumber numberWithInt:AUDIO_VIDEO]];
        }
#endif
        [callingView onCallOk:YES];
        return;
    }
    if (MSG_REJECT == msgid)//拒接
    {
        [self closeCallingView];
        if (mCallObj)
        {
            [mCallObj doRejectCall];
            [mCallObj release];
            mCallObj = nil;
        }
        return;
        
    }
    if (MSG_MUTE == msgid)//静音
    {
        if (!mCallObj)
        {
            [self setLog:@"静音前请先呼叫"];
            return;
        }
        if ([mCallObj MuteStatus] == NO)
        {
            [mCallObj doMuteMic:MUTE_DOMUTE];
        }
        else
        {
            [mCallObj doMuteMic:MUTE_DOUNMUTE];
        }
        return;
    }
    if (MSG_SET_VIDEO_DEVICE == msgid)//切换摄像头
    {
        if (!mCallObj)
        {
            [self setLog:@"切换摄像头前请先呼叫"];
            return;
        }
        cameraIndex++;
        if (cameraIndex > 1)
        {
            cameraIndex = 0;
        }
        [mCallObj doSwitchCamera:cameraIndex];
        [callingView setCallStatus:[NSString stringWithFormat:@"摄像头切换到:%d",cameraIndex]];
        return;
    }
    if (MSG_HIDE_LOCAL_VIDEO == msgid)//隐藏摄像头
    {
        if (!mCallObj || mCallObj.CallMedia!= MEDIA_TYPE_VIDEO)
        {
            [self setLog:@"隐藏摄像头前请先呼叫"];
            return;
        }
        [mCallObj doHideLocalVideo:(SDK_HIDE_LOCAL_VIDEO)arg];
        return;
    }
    if (MSG_SNAP == msgid)//截图
    {
        if (!mCallObj || mCallObj.CallMedia!= MEDIA_TYPE_VIDEO)
        {
            [self setLog:@"请先呼叫"];
            return;
        }
        [mCallObj doSnapImage];
        return;
    }
    if (MSG_ROTATE_REMOTE_VIDEO == msgid)//旋转摄像头
    {
        if (!mCallObj || mCallObj.CallMedia!= MEDIA_TYPE_VIDEO)
        {
            [self setLog:@"请先呼叫"];
            return;
        }
        [mCallObj doRotateRemoteVideo:arg];
        return;
    }
//    if (MSG_UPDATE_CALLDURATION == msgid)//刷新通话时长
//    {
//        if (!mCallObj)
//        {
//            [self setLog:@"呼叫尚未开始"];
//            return;
//        }
//        unsigned int cd = mCallObj.CallDuration;
//        if (cd == 0)
//            return;
//        
////        [callingView setCallDuration:cd
////                             withCPU:[[UIDevice currentDevice]cpuUseage]
////                             withMem:[[UIDevice currentDevice]usedMemory]];
//        return;
//    }
    
#if (SDK_HAS_GROUP>0)
    if (MSG_GROUP_CREATE == msgid)//创建多人会话，这里与MSG_NEED_VIDEO类似
    {
        long long localV = [[data objectForKey:@"lvideo"]longLongValue];
        long long remoteV = [[data objectForKey:@"rvideo"]longLongValue];
        remoteVideoView = (IOSDisplay*)remoteV;
        localVideoView = (UIView*)localV;
        BOOL isCallOut = [[data objectForKey:@"iscallout"]boolValue];
        
        if (nil == mCallObj && isCallOut )
        {
            mCallObj = [[CallObj alloc]init];
            [mCallObj setDelegate:self];//必须设置回调代理，否则无法执行回调
            [mCallObj bindAcc:mAccObj];
            
            NSString* remoteUri = mUser1.text;
            NSString* remoteUri2 = [NSString stringWithFormat:@"%@,%@",mUser1.text,mUser2.text];//账号之间用逗号隔开
            NSArray* remoteAccArr = [remoteUri2 componentsSeparatedByString:@","];
            NSUInteger countMem=[remoteAccArr count];
            NSMutableArray* remoteTypeArr = [NSMutableArray arrayWithObjects:
                                             [NSNumber numberWithInt:accType],
                                             nil];
            for(int i = 1; i<countMem; i++)
            {
                [remoteTypeArr addObject:[NSNumber numberWithInt:remoteAccType]];//这里假设所有远端账号类型一致
            }
            
            //dic参数应用自定义
            NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 remoteUri,KEY_GRP_CREATER,
                                 terminalType,KEY_GRP_CREATERTYPE,
                                 [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                                 remoteTypeArr,KEY_CALL_REMOTE_ACC_TYPE,
                                 [NSNumber numberWithInt:grpType],KEY_GRP_TYPE,
                                 @"groupname",KEY_GRP_NAME,//KEY_GRP_NAME可传入多个自定义信息，用冒号隔开
                                 remoteUri2,KEY_GRP_INVITEELIST,//如果创建者参与会话，必须放在第一项
                                 @"kong",KEY_GRP_PASSWORD,//密码自定义
                                 [NSNumber numberWithInt:1],KEY_GRP_CODEC,//不传则默认h264，codec格式必须与setVideoCodec设置格式一致
                                 nil];
            int ret = [mCallObj groupCall:SDK_GROUP_CREATE param:dic];
            [mCallObj doSwitchAudioDevice:SDK_AUDIO_OUTPUT_DEFAULT];
            
            if (EC_OK > ret)
            {
                if (mCallObj)//若通话失败或结束，必须释放callobj
                {
                    //[mCallObj doHangupCall];
                    [mCallObj release];
                    mCallObj = nil;
                }
                
                [self closeCallingView];
                [self setLog:[NSString stringWithFormat:@"创建呼叫失败:%@",[SdkObj ECodeToStr:ret]]];
                
            }
        }
        return;
    }
    if (MSG_GROUP_ACCEPT == msgid)//多人创建者自动接听
    {
        //无论是音频还是视频，多人会议下callobj.callmedia都为视频类型
#if (SDK_HAS_VIDEO>0)
        long long localV = [[data objectForKey:@"lvideo"]longLongValue];
        long long remoteV = [[data objectForKey:@"rvideo"]longLongValue];
        remoteVideoView = (IOSDisplay*)remoteV;
        localVideoView = (UIView*)localV;
        [mCallObj performSelector:@selector(doAcceptCall:) withObject:[NSNumber numberWithInt:AUDIO_VIDEO] afterDelay:0.1];
#endif
        [callingView onCallOk:YES];
        return;
    }
    if (MSG_GROUP_LIST == msgid)//获取多人列表
    {
        NSString* remoteUri = mUser1.text;
        
        //dic参数应用自定义
        NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                             remoteUri,KEY_GRP_CREATER,
                             terminalType,KEY_GRP_CREATERTYPE,
                             [NSNumber numberWithInt:isGroupCreator],KEY_GRP_ISCREATOR,
                             [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                             callID,KEY_GRP_CALLID,
                             nil];
        int ret = [mCallObj groupCall:SDK_GROUP_GETMEMLIST param:dic];
        
        if (EC_OK > ret)
        {
            [self setLog:[NSString stringWithFormat:@"获取成员列表失败:%@",[SdkObj ECodeToStr:ret]]];
        }
    }
    if (MSG_GROUP_INVITE == msgid)//邀请多人成员
    {
        NSString* memberList = [data objectForKey:KEY_GRP_INVITEDMBLIST];
        NSArray* remoteAccArr = [memberList componentsSeparatedByString:@","];
        NSUInteger countMem=[remoteAccArr count];
        NSMutableArray* remoteTypeArr = [NSMutableArray arrayWithObjects:
                                         nil];
        for(int i = 0; i<countMem; i++)
        {
            [remoteTypeArr addObject:[NSNumber numberWithInt:remoteAccType]];
        }
        
        NSString* remoteUri = mUser1.text;
        int mode=SDK_GROUP_AUDIO_SENDRECV;//语音群聊
        if(grpType == 21 || grpType == 22 || grpType == 29)//视频对讲或两方或直播
            mode = SDK_GROUP_AUDIO_RECVONLY_VIDEO_RECVONLY;
        else if(grpType == 1 || grpType == 2 || grpType == 9)//语音对讲或两方或直播
            mode = SDK_GROUP_AUDIO_RECVONLY;
        else if(grpType == 20 )//视频群聊
            mode = -1;
        
        //dic参数应用自定义
        NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                             remoteUri,KEY_GRP_CREATER,
                             terminalType,KEY_GRP_CREATERTYPE,
                             [NSNumber numberWithInt:isGroupCreator],KEY_GRP_ISCREATOR,
                             [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                             remoteTypeArr,KEY_CALL_REMOTE_ACC_TYPE,
                             callID,KEY_GRP_CALLID,
                             memberList,KEY_GRP_INVITEDMBLIST,
                             [NSNumber numberWithInt:mode],KEY_GRP_MODE,
                             nil];
        int ret = [mCallObj groupCall:SDK_GROUP_INVITEMEMLIST param:dic];
        
        if (EC_OK > ret)
        {
            [self setLog:[NSString stringWithFormat:@"邀请成员失败:%@",[SdkObj ECodeToStr:ret]]];
        }
    }
    if (MSG_GROUP_JOIN == msgid)//主动加入会议
    {
        long long localV = [[data objectForKey:@"lvideo"]longLongValue];
        long long remoteV = [[data objectForKey:@"rvideo"]longLongValue];
        remoteVideoView = (IOSDisplay*)remoteV;
        localVideoView = (UIView*)localV;
        BOOL isCallOut = [[data objectForKey:@"iscallout"]boolValue];
        
        if (nil == mCallObj && isCallOut )
        {
            mCallObj = [[CallObj alloc]init];
            [mCallObj setDelegate:self];//必须设置回调代理，否则无法执行回调
            [mCallObj bindAcc:mAccObj];
            
            NSString* remoteUri = mUser1.text;
            NSString* joinID = joinCallID;//此处填入callID
            
            int mode=SDK_GROUP_AUDIO_SENDRECV;//语音群聊
            if(grpType == 21 || grpType == 22 || grpType == 29)//视频对讲或两方或直播
                mode = SDK_GROUP_AUDIO_RECVONLY_VIDEO_RECVONLY;
            else if(grpType == 1 || grpType == 2 || grpType == 9)//语音对讲或两方或直播
                mode = SDK_GROUP_AUDIO_RECVONLY;
            else if(grpType == 20 )//视频群聊
                mode = -1;
            
            //dic参数应用自定义
            NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 remoteUri,KEY_GRP_CREATER,
                                 terminalType,KEY_GRP_CREATERTYPE,
                                 [NSNumber numberWithInt:1],KEY_GRP_JOINONLY,
                                 [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                                 joinID,KEY_GRP_CALLID,
                                 remoteUri,KEY_GRP_INVITEDMBLIST,
                                 [NSNumber numberWithInt:mode],KEY_GRP_MODE,
                                 @"kong",KEY_GRP_PASSWORD,
                                 nil];
            int ret = [mCallObj groupCall:SDK_GROUP_JOIN param:dic];
            [mCallObj doSwitchAudioDevice:SDK_AUDIO_OUTPUT_DEFAULT];
            
            if (EC_OK > ret)
            {
                [self setLog:[NSString stringWithFormat:@"加入会议失败:%@",[SdkObj ECodeToStr:ret]]];
            }
        }
        return;
    }
    if (MSG_GROUP_KICK == msgid)//踢出多人成员
    {
        NSString* memberList = [data objectForKey:KEY_GRP_KICKEDMBLIST];
        NSArray* remoteAccArr = [memberList componentsSeparatedByString:@","];
        NSUInteger countMem=[remoteAccArr count];
        NSMutableArray* remoteTypeArr = [NSMutableArray arrayWithObjects:
                                         nil];
        for(int i = 0; i<countMem; i++)
        {
            [remoteTypeArr addObject:[NSNumber numberWithInt:remoteAccType]];
        }
        
        NSString* remoteUri = mUser1.text;
        
        //dic参数应用自定义
        NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                             remoteUri,KEY_GRP_CREATER,
                             terminalType,KEY_GRP_CREATERTYPE,
                             [NSNumber numberWithInt:isGroupCreator],KEY_GRP_ISCREATOR,
                             [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                             remoteTypeArr,KEY_CALL_REMOTE_ACC_TYPE,
                             callID,KEY_GRP_CALLID,
                             memberList,KEY_GRP_KICKEDMBLIST,
                             nil];
        int ret = [mCallObj groupCall:SDK_GROUP_KICKMEMLIST param:dic];
        
        if (EC_OK > ret)
        {
            [self setLog:[NSString stringWithFormat:@"踢出成员失败:%@",[SdkObj ECodeToStr:ret]]];
        }
    }
    if (MSG_GROUP_CLOSE == msgid)//结束多人会话
    {
        NSString* remoteUri = mUser1.text;
        
        //dic参数应用自定义
        NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                             remoteUri,KEY_GRP_CREATER,
                             terminalType,KEY_GRP_CREATERTYPE,
                             [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                             callID,KEY_GRP_CALLID,
                             nil];
        int ret = [mCallObj groupCall:SDK_GROUP_CLOSE param:dic];
        
        if (EC_OK > ret)
        {
            [self setLog:[NSString stringWithFormat:@"关闭会话失败:%@",[SdkObj ECodeToStr:ret]]];
        }
    }
    if (MSG_GROUP_UNMUTE == msgid)//给麦
    {
        NSString* member = [data objectForKey:KEY_GRP_MEMBER];
        int mode;
        if(grpType >= 20)
            mode = SDK_GROUP_UNMUTE_AUDIO_VIDEO;
        else
            mode = SDK_GROUP_UNMUTE_AUDIO;
        NSMutableArray* mbOperationList = [NSMutableArray arrayWithObjects:
                                           [NSDictionary dictionaryWithObjectsAndKeys:
                                            member,KEY_GRP_MEMBER,
                                            [NSNumber numberWithInt:mode],KEY_GRP_UPOPERATIONTYPE,
                                            [NSNumber numberWithInt:mode],KEY_GRP_DWOPERATIONTYPE,
                                            nil],
                                           nil];
        NSString* remoteUri = mUser1.text;
        NSArray* remoteAccArr = [member componentsSeparatedByString:@","];
        NSUInteger countMem=[remoteAccArr count];
        NSMutableArray* remoteTypeArr = [NSMutableArray arrayWithObjects:
                                         nil];
        for(int i = 0; i<countMem; i++)
        {
            [remoteTypeArr addObject:[NSNumber numberWithInt:remoteAccType]];
        }
        
        //dic参数应用自定义
        NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                             remoteUri,KEY_GRP_CREATER,
                             terminalType,KEY_GRP_CREATERTYPE,
                             [NSNumber numberWithInt:isGroupCreator],KEY_GRP_ISCREATOR,
                             [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                             remoteTypeArr,KEY_CALL_REMOTE_ACC_TYPE,
                             callID,KEY_GRP_CALLID,
                             mbOperationList,KEY_GRP_MBOPERATIONLIST,
                             nil];
        int ret = [mCallObj groupCall:SDK_GROUP_MIC param:dic];
        
        if (EC_OK > ret)
        {
            [self setLog:[NSString stringWithFormat:@"给麦失败:%@",[SdkObj ECodeToStr:ret]]];
        }
    }
    if (MSG_GROUP_MUTE == msgid)//收麦
    {
        NSString* member = [data objectForKey:KEY_GRP_MEMBER];
        int mode;
        if(grpType >= 20)
            mode = SDK_GROUP_MUTE_AUDIO_VIDEO;
        else
            mode = SDK_GROUP_MUTE_AUDIO;
        NSMutableArray* mbOperationList = [NSMutableArray arrayWithObjects:
                                           [NSDictionary dictionaryWithObjectsAndKeys:
                                            member,KEY_GRP_MEMBER,
                                            [NSNumber numberWithInt:mode],KEY_GRP_UPOPERATIONTYPE,
                                            [NSNumber numberWithInt:mode],KEY_GRP_DWOPERATIONTYPE,
                                            nil],
                                           nil];
        NSString* remoteUri = mUser1.text;
        NSArray* remoteAccArr = [member componentsSeparatedByString:@","];
        NSUInteger countMem=[remoteAccArr count];
        NSMutableArray* remoteTypeArr = [NSMutableArray arrayWithObjects:
                                         nil];
        for(int i = 0; i<countMem; i++)
        {
            [remoteTypeArr addObject:[NSNumber numberWithInt:remoteAccType]];
        }
        
        //dic参数应用自定义
        NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                             remoteUri,KEY_GRP_CREATER,
                             terminalType,KEY_GRP_CREATERTYPE,
                             [NSNumber numberWithInt:isGroupCreator],KEY_GRP_ISCREATOR,
                             [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                             remoteTypeArr,KEY_CALL_REMOTE_ACC_TYPE,
                             callID,KEY_GRP_CALLID,
                             mbOperationList,KEY_GRP_MBOPERATIONLIST,
                             nil];
        int ret = [mCallObj groupCall:SDK_GROUP_MIC param:dic];
        
        if (EC_OK > ret)
        {
            [self setLog:[NSString stringWithFormat:@"收麦失败:%@",[SdkObj ECodeToStr:ret]]];
        }
    }
    if (MSG_GROUP_DISPLAY == msgid)//多人画面分屏
    {
        NSString* memberList = [data objectForKey:KEY_GRP_MEMBER];
        NSString* remoteUri = mUser1.text;
        //SDK_GROUP_DISPLAYMODE dismode = SDK_GROUP_EQUALDIS;
        NSArray* remoteAccArr = [memberList componentsSeparatedByString:@","];
        NSUInteger countMem=[remoteAccArr count];
        NSMutableArray* remoteTypeArr = [NSMutableArray arrayWithObjects:
                                         [NSNumber numberWithInt:accType],
                                         nil];
        for(int i = 1; i<countMem; i++)
        {
            [remoteTypeArr addObject:[NSNumber numberWithInt:remoteAccType]];
        }
        
        //dic参数应用自定义
        NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                             remoteUri,KEY_GRP_CREATER,
                             terminalType,KEY_GRP_CREATERTYPE,
                             [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                             remoteTypeArr,KEY_CALL_REMOTE_ACC_TYPE,
                             callID,KEY_GRP_CALLID,
                             /*memberList,KEY_GRP_MEMBERLIST,//optional
                             memberList,KEY_GRP_MBTOSET,//optional
                             [NSNumber numberWithInt:1],KEY_GRP_MBSETSTYLE,//optional
                             [NSNumber numberWithInt:1],,KEY_GRP_MBTOSHOW,//optional
                             [NSNumber numberWithInt:1],KEY_GRP_LV,//optional*/
                             [NSNumber numberWithInt:4],KEY_GRP_SCREENSPLIT,//optional
                             nil];
        int ret = [mCallObj groupCall:SDK_GROUP_VIDEO param:dic];
        
        if (EC_OK > ret)
        {
            [self setLog:[NSString stringWithFormat:@"分屏失败:%@",[SdkObj ECodeToStr:ret]]];
        }
    }
#endif
    if (MSG_START_RECORDING == msgid)//开始录像
    {
        if (!mCallObj || mCallObj.CallMedia!= MEDIA_TYPE_VIDEO)
        {
            [self setLog:@"录制视频前请先呼叫"];
            return;
        }
        [mCallObj doStartRecording];
        return;
    }
    if (MSG_STOP_RECORDING == msgid)//停止录像
    {
        if (!mCallObj || mCallObj.CallMedia!= MEDIA_TYPE_VIDEO)
        {
            [self setLog:@"停止录制视频前请先呼叫"];
            return;
        }
        [mCallObj doStopRecording];
        
        return;
    }
}

/**************************************SDK回调*****************************************/
//所有SDK回调都需要应用层在主线程实现，若某些回调应用层不需要调用，实现一个空的函数体即可

//获取服务器地址结果回调
-(void)onNavigationResp:(int)code error:(NSString*)error
{
    if (0 == code)
    {
        [self setLog:[NSString stringWithFormat:@"初始化成功"]];
        
        //音视频编解码以及分辨率可以不设置，若不设置则采用默认配置
        [mSDKObj setAudioCodec:[NSNumber numberWithInt:1]];//iLBC
#if (SDK_HAS_VIDEO>0)
        [mSDKObj setVideoCodec:[NSNumber numberWithInt:1]];//VP8
        [mSDKObj setVideoAttr:[NSNumber numberWithInt:3]];//CIF
#endif
        //开发者可以将初始化和登录分开进行，
        //demo是将初始化和登录合并为一个button进行，因此在此处进行登录
        //请在初始化成功之后再进行登录，不要在尚未获得初始化返回结果时就登录
        [self onRegister];
    }
    else
    {
        //常见错误：初始化失败-1002，请检查网络是否正常，以及appID、appKey、address参数是否传入正确
        [self setLog:[NSString stringWithFormat:@"初始化失败:%d,%@",code,error]];
        [mSDKObj release];//初始化失败后请及时销毁sdk指针，以免下次创建失败
        mSDKObj = nil;
        isGettingToken = NO;
    }
}

//注册结果回调
//result形如：
//{
//    capabilityToken = CB568F38A1EF6B4B9B17CB5EA749156C;
//    code = 0;
//    currentUserTerminalSN = "<null>";
//    currentUserTerminalType = "<null>";
//    reason = "\U7533\U8bf7\U6210\U529f";
//    requestId = "2015-10-28 13:15:45:045";
//    rtcaccountID = "10-1111~70038~Phone@chinartc.com";
//}
-(int)onRegisterResponse:(NSDictionary*)result  accObj:(AccObj*)accObj
{
    mToken = [result objectForKey:KEY_CAPABILITYTOKEN];
    mAccountID = [result objectForKey:KEY_RTCACCOUNTID];
    isGettingToken = NO;
    if(mToken)
    {
        NSMutableDictionary *newResult = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
        [newResult setObject:mToken forKey:KEY_CAPABILITYTOKEN];
        [newResult setObject:mAccountID forKey:KEY_RTCACCOUNTID];//形如"账号类型-账号~appid~终端类型@chinartc.com"
        //[newResult setObject:[NSNumber numberWithDouble:2] forKey:KEY_ACC_SRTP];//若与浏览器互通则打开
        [mAccObj doAccRegister:newResult];
        return EC_OK;
    }
    if (nil == result || nil == accObj)
    {
        [self setLog:@"注册请求失败-未知原因"];
        return EC_PARAM_WRONG;
    }
    id obj = [result objectForKey:KEY_REG_EXPIRES];
    if (nil == obj)
    {
        [self setLog:@"注册请求失败-丢失字段KEY_REG_EXPIRES"];
        return EC_PARAM_WRONG;
    }
    int nExpire = [obj intValue];
    
    obj = [result objectForKey:KEY_REG_RSP_CODE];
    if (nil == obj)
    {
        [self setLog:@"注册请求失败-丢失字段KEY_REG_RSP_CODE"];
        return EC_PARAM_WRONG;
    }
    int nRspCode = [obj intValue];
    
    obj = [result objectForKey:KEY_REG_RSP_REASON];
    if (nil == obj)
    {
        [self setLog:@"注册请求失败-丢失字段KEY_REG_RSP_REASON"];
        return EC_PARAM_WRONG;
    }
    NSString* sReason = obj;
    
    if (nRspCode == 200)
    {
        [self setLog:[NSString stringWithFormat:@"登录成功,距下次注册%d秒",nExpire]];
    }
    else
    {
        //常见错误：登录失败403，表示token失效，此时需要重新获取新的token注册。
        //如果同一账号、同一终端类型的用户互踢下线，被踢的用户会返回403。
        //若错误码返回401请检查appid和appkey是否可用。
        //若错误码返回-1007格式非法，请检查账号，账号不可包含空格、中文和'~'字符。
        [self setLog:[NSString stringWithFormat:@"登录失败:%d:%@",nRspCode,sReason]];
        
//        if (mAccObj)
//        {
//            [mAccObj doUnRegister];
//            [mAccObj release];
//            mAccObj = nil;
//            mToken = nil;
//            mAccountID = nil;
//            [self setLog:@"注销完毕"];
//            
//            if(mSDKObj)
//            {
//                [mSDKObj release];
//                mSDKObj = nil;
//                mLogIndex = 0;
//                [self setLog:@"release完毕"];
//            }
//        }
    }
    
    return EC_OK;
}

//用户在线状态查询结果回调
//result形如：
//{
//    code = 0;
//    reason = "\U67e5\U8be2\U6210\U529f";
//    requestId = "2015-10-28 13:19:57:057";
//    userStatusList =     (
//                          {
//                              appAccountId = "10-1117~70038~Any";
//                              othOnlineInfoList = "<null>";
//                              presenceTime = "2015-10-28-13-19-55";
//                              status = 1;
//                          }
//                          );
//}
-(int)onAccStatusQueryResponse:(NSDictionary*)result accObj:(AccObj*)accObj
{
    if (nil == result || nil == accObj)
    {
        [self setLog:@"查询请求失败-未知原因"];
        return EC_PARAM_WRONG;
    }
    id obj = [result objectForKey:KEY_RESULT];
    if (nil == obj)
    {
        [self setLog:@"查询请求失败-丢失字段KEY_RESULT"];
        return EC_PARAM_WRONG;
    }
    int code = [obj intValue];
    if (0 == code)
    {
        int i = 0;//获取第i个账号的在线状态
        while (TRUE)
        {
            int online = 0;
            NSString* sAccId = [mAccObj getUserStatus:result online:&online atIndex:i];//获取在线状态
            if (nil != sAccId)
            {
                [self setLog:[NSString stringWithFormat:@"%@_%@",online?@"在线":@"离线",sAccId]];
                i++;
            }
            else
            {
                break;
            }
            
        }
    }
    else
    {
        NSString* reason = [result objectForKey:KEY_REASON];
        [self setLog:[NSString stringWithFormat:@"查询失败:%d:%@",code,reason]];
    }
    return EC_OK;
    
}

//点对点来点回调
//param形如：
//{
//    "call.er" = "10-18910903997~70038~Phone";
//    "call.type" = 1;
//    "ci" = "custom";
//}
-(int)onCallIncoming:(NSDictionary*)param withNewCallObj:(CallObj*)newCallObj accObj:(AccObj*)accObj
{
    mCallObj = newCallObj;//来电时无需alloc，将回调参数赋给callobj即可
    [mCallObj setDelegate:self];//必须设置回调代理，否则无法执行回调
    int callType = [[param objectForKey:KEY_CALL_TYPE]intValue];//呼叫类型
    NSString* uri = [param objectForKey:KEY_CALLER];//形如"10-18901012345~123~Phone"
    NSString* ci = [param objectForKey:KEY_CALL_INFO];//自定义信息
    
    const char* cacc = [uri UTF8String];
    int strindex1=0,strindex2=0;
    int l = (int)strlen(cacc);
    for(int i = 0;i<l;i++)
    {
        if(cacc[i]=='-')
        {
            strindex1=i;
            break;
        }
    }
    for(int i = 0;i<l;i++)
    {
        if(cacc[i]=='~')
        {
            strindex2=i;
            break;
        }
    }
    NSString* accNum = [[NSString stringWithUTF8String:cacc] substringWithRange:NSMakeRange(strindex1+1, strindex2-strindex1-1)];
    
    if ([self isBackground])//后台来电只弹通知
    {
        [self setCallIncomingFlag:YES];
        [[NSUserDefaults standardUserDefaults]setObject:[NSNumber numberWithInt:callType] forKey:KEY_CALL_TYPE];
        [[NSUserDefaults standardUserDefaults]setObject:uri     forKey:KEY_CALLER];
#if(SDK_HAS_GROUP>0)
        [[NSUserDefaults standardUserDefaults]setObject:@""     forKey:KEY_GRP_NAME];
#endif
        makeNotification(@"接听",[NSString stringWithFormat:@"来电:%@",accNum],UILocalNotificationDefaultSoundName,YES);
        return 0;
    }
    CCallingViewController* view1 = [[CCallingViewController alloc]init];//弹呼叫接听页面
    view1.isVideo = !(callType == AUDIO || callType == AUDIO_RECV || callType == AUDIO_SEND);
    view1.isCallOut = NO;
#if(SDK_HAS_GROUP>0)
    isGroup = 0;//点对点
#endif
    if (view1.isVideo)
        view1.isAutoRotate = isAutoRotationVideo;
    view1.view.frame = self.view.frame;
    callingView = view1;
    [self presentViewController:view1 animated:NO completion:nil];
    [view1 release];
    
    //若要实现来电自动接听，可在此处这样写，同时onApplicationWillEnterForeground也要相应修改
//    [self setLog:@"已接听"];
//    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
//                            [NSNumber numberWithInt:MSG_ACCEPT],@"msgid",
//                            [NSNumber numberWithInt:0],@"arg",
//                            [NSNumber numberWithLongLong:(long long)(self.remoteVideoView)],@"rvideo",
//                            [NSNumber numberWithLongLong:(long long)(self.localVideoView)],@"lvideo",
//                            nil];
//    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
    
    return 0;
}

//呼叫事件回调
-(int)onCallBack:(SDK_CALLBACK_TYPE)type code:(int)code callObj:(CallObj*)callObj
{
    [self setLog:[NSString stringWithFormat:@"呼叫事件:%d code:%d",type,code]];
    //常见呼叫code码含义：
    //404：呼叫的账号不存在，主被叫appid可能不一致
    //408：本地或对端网络异常
    //480：被叫未登录，或网络断开了
    //487：发起呼叫后被叫网络断开，或是通话过程中对端挂断，或是收到来电后主叫挂断。
    //603：发起呼叫后被叫挂断，或是收到来电后主叫网络断开
    
    //不同事件类型见SDK_CALLBACK_TYPE
    if(type == SDK_CALLBACK_RING)
    {
        [self setLog:[NSString stringWithFormat:@"呼叫中%d...",code]];
    }
    else if (type == SDK_CALLBACK_ACCEPTED)
    {
        [callingView onCallOk:YES];
        [self setCallIncomingFlag:NO];
    }
    else
    {
        [self closeCallingView];
        [callingView onCallOk:NO];
        if (mCallObj)//若通话失败或结束，必须释放callobj
        {
            //[mCallObj doHangupCall];
            [mCallObj release];
            mCallObj = nil;
        }
        
        cameraIndex = 1;
#if (SDK_HAS_GROUP>0)
        [callID release];
        callID = @"";
        [callID retain];
#endif
        [self setCallIncomingFlag:NO];
    }
    return 0;
}

//呼叫媒体建立事件通知
-(int)onCallMediaCreated:(int)mediaType callObj:(CallObj *)callObj
{
#if(SDK_HAS_GROUP>0)
    //在多人会话下，mediaType不区分音频和视频，
    //因此通过会话类型区分，多人语音则直接退出
    if(isGroup != 0 && grpType<20)
    {
        [self setCallIncomingFlag:NO];
        return 0;
    }
#endif
    
#if (SDK_HAS_VIDEO>0)
    //视频通话下，若SDK内部建立媒体成功，会进入此回调
    //需要在此处设置本地和远端窗口
    if (mediaType == MEDIA_TYPE_VIDEO)
    {
        int ret = [callObj doSetCallVideoWindow:remoteVideoView localVideoWindow:localVideoView];//第一个参数必须为IOSDisplay*类型
    }
#endif
    [self setCallIncomingFlag:NO];
    return 0;
}

//呼叫网络状态事件通知，仅限点对点视频
-(int)onNetworkStatus:(NSString*)desc callObj:(CallObj*)callObj
{
//    if (desc && callingView)
//    {
//        NSDictionary* dic = [desc objectFromJSONString];
//        //int msg = [[dic objectForKey:@"msg"]intValue];
//        //int codec = [[dic objectForKey:@"codec"]intValue];
//        int w = [[dic objectForKey:@"w"]intValue];
//        int h = [[dic objectForKey:@"h"]intValue];
//        //        int recvFrameRate = [[dic objectForKey:@"rf"]intValue];
//        //        int sendFrameRate = [[dic objectForKey:@"sf"]intValue];
//        int sendBitrate = [[dic objectForKey:@"sb"]intValue];
//        int recvBitrate = [[dic objectForKey:@"rb"]intValue];
//        int rtt = [[dic objectForKey:@"lost"]intValue];
//        
//        if (w == 0 || h == 0 || sendBitrate == 0 || recvBitrate == 0 || rtt == 0)
//            return 0;
//        
//        CWLogDebug(@"sb=%dkbps, rb=%dkbps, rtt=%dms,onCall:%@",sendBitrate/1000,recvBitrate/1000,rtt,callObj);
//        int SB_LEVEL_1 = 99360;
//        int SB_LEVEL_2 = 40360;
//        int RTT_LEVEL_1 = 500;
//        int RTT_LEVEL_2 = 1000;
//        //显示5秒
//        if(sendBitrate>SB_LEVEL_1 && rtt<RTT_LEVEL_1 && recvBitrate>SB_LEVEL_1)
//        {
//            [callingView setVideoStatus:[NSString stringWithFormat:@"发送速率:%dkbps, 接收速率:%dkbps, \nrtt:%dms",sendBitrate/1000,recvBitrate/1000,rtt] txtColor:[UIColor colorWithRed:0.0 green:240.0/255.0 blue:0.0 alpha:1]];
//        }
//        else if (sendBitrate>SB_LEVEL_2 && rtt<RTT_LEVEL_2 && recvBitrate>SB_LEVEL_2)
//        {
//            [callingView setVideoStatus:[NSString stringWithFormat:@"网络不稳定\n发送速率:%dkbps, 接收速率:%dkbps,\nrtt:%dms",sendBitrate/1000,recvBitrate/1000,rtt] txtColor:[UIColor colorWithRed:240.0/255.0 green:240.0/255.0 blue:0.0 alpha:1]];
//        }
//        else if(recvBitrate<SB_LEVEL_2 && sendBitrate>SB_LEVEL_2)
//        {
//            [callingView setVideoStatus:[NSString stringWithFormat:@"对方网络很差，无法保证正常视频\n发送速率:%dkbps, 接收速率:%dkbps,\nrtt:%dms",sendBitrate/1000,recvBitrate/1000,rtt] txtColor:[UIColor colorWithRed:240.0/255.0 green:0.0 blue:0.0 alpha:1]];
//        }
//        else
//        {
//            [callingView setVideoStatus:[NSString stringWithFormat:@"网络很差，无法保证正常视频\n发送速率:%dkbps, 接收速率:%dkbps,\nrtt:%dms",sendBitrate/1000,recvBitrate/1000,rtt] txtColor:[UIColor colorWithRed:240.0/255.0 green:0.0 blue:0.0 alpha:1]];
//        }
//    }
    
    return 0;
}

//消息到达回调
//param形如:
//{
//    "call.er" = "10-1446013949~70038~Browser";
//    "call.type" = "text/plain";
//    ci = "123";
//}
-(int)onReceiveIM:(NSDictionary*)param withAccObj:(AccObj*)accObj
{
    CWLogDebug(@"result is %@onCall:%@",param,accObj);
    
    NSString* mime = [param objectForKey:KEY_CALL_TYPE];
    NSString* uri = [param objectForKey:KEY_CALLER];
    NSString* content = [param objectForKey:KEY_CALL_INFO];//消息内容
    [self setLog:[NSString stringWithFormat:@"接收消息:%@",content]];
    
    const char* cacc = [uri UTF8String];
    int strindex1=0,strindex2=0;
    int l = (int)strlen(cacc);
    for(int i = 0;i<l;i++)
    {
        if(cacc[i]=='-')
        {
            strindex1=i;
            break;
        }
    }
    for(int i = 0;i<l;i++)
    {
        if(cacc[i]=='~')
        {
            strindex2=i;
            break;
        }
    }
    NSString* accNum = [[NSString stringWithUTF8String:cacc] substringWithRange:NSMakeRange(strindex1+1, strindex2-strindex1-1)];//解析出的来电号码
    
    return 0;
}

//消息发送回调
-(int)onSendIM:(int)status
{
    [self setLog:[NSString stringWithFormat:@"发送消息:%d",status]];//200为成功
    
    return 0;
}

#if (SDK_HAS_GROUP>0)
//多人来电回调，创建者调用发起多人会话接口后，会作为被叫收到平台的来电消息，
//收到来电后，创建者需要自动触发接听，只有创建者先接听，其他成员才能收到来电。
//param形如：
//{
//    callId = "YmVpamluZy1KVDAwMjAzMjE5ODE0NDYwMTQyNDQ3Mw==";
//    gvcname = groupname;
//    gvctype = 0;
//    isgrpcreator = 0;
//}
-(int)onGroupCreate:(NSDictionary*)param withNewCallObj:(CallObj*)newCallObj accObj:(AccObj*)accObj
{
    CWLogDebug(@"%s result is %@onCall:%@",__FUNCTION__,param,accObj);
    
    mCallObj = newCallObj;
    [mCallObj setDelegate:self];//必须设置回调代理，否则无法执行回调
    NSString* uri = [param objectForKey:KEY_GRP_CALLID];
    isGroupCreator = [[param objectForKey:KEY_GRP_ISCREATOR]intValue];
    grpType = [[param objectForKey:KEY_GRP_TYPE]intValue];
    NSString* grpName = [param objectForKey:KEY_GRP_NAME];
    
    if([param objectForKey:KEY_GRP_CALLID]!=nil&&[param objectForKey:KEY_GRP_CALLID]!=[NSNull null])
    {
        [callID release];
        callID = uri;
        [callID retain];
    }
    
    if (!isGroupCreator)//被叫弹出来电界面
    {
        if ([self isBackground])//后台弹出通知
        {
            [self setCallIncomingFlag:YES];
            [[NSUserDefaults standardUserDefaults]setObject:[NSNumber numberWithInt:0] forKey:KEY_CALL_TYPE];
            [[NSUserDefaults standardUserDefaults]setObject:uri     forKey:KEY_CALLER];
            [[NSUserDefaults standardUserDefaults]setObject:grpName     forKey:KEY_GRP_NAME];
            makeNotification(@"接听",[NSString stringWithFormat:@"来电:%@",uri],UILocalNotificationDefaultSoundName,
                             YES);
            return EC_OK;
        }
        CCallingViewController* view1 = [[CCallingViewController alloc]init];
        view1.isCallOut = NO;
        
        if(grpType < 20)
            view1.isVideo = NO;
        else
            view1.isVideo = YES;
        isGroup = 1;//1或2
        
        if (view1.isVideo)
            view1.isAutoRotate = isAutoRotationVideo;
        view1.view.frame = self.view.frame;
        callingView = view1;
        [self presentViewController:view1 animated:NO completion:nil];
        [view1 release];
    }
    else//创建者自动接听
    {
        [self setLog:@"已接听"];
        NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                                [NSNumber numberWithInt:MSG_GROUP_ACCEPT],@"msgid",
                                [NSNumber numberWithInt:0],@"arg",
                                [NSNumber numberWithLongLong:(long long)(remoteVideoView)],@"rvideo",
                                [NSNumber numberWithLongLong:(long long)(localVideoView)],@"lvideo",
                                nil];
        //CWLogDebug(@"param is %@",params);
        [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
    }
    
    return EC_OK;
}
#endif

//反馈消息回调
-(int)onNotifyMessage:(NSDictionary*)result  accObj:(AccObj*)accObj
{
    CWLogDebug(@"%s result is %@onNotify:%@",__FUNCTION__,result,accObj);
    NSString* changeInfo = [result objectForKey:@"ChangedInfo"];//多人会议成员状态变化
    NSString* connection = [result objectForKey:@"CheckConnection"];//多人会议成员异常掉线
    NSArray* gvcList = [result objectForKey:@"gvcList"];//会议列表
    NSString* multiLogin = [result objectForKey:@"multiLogin"];//同一号码在多终端类型登录
    NSString* kickedBy = [result objectForKey:@"kickedBy"];//同一账号在不同设备登录被踢下线
    NSArray* memberInfoList = [result objectForKey:@"memberInfoList"];//本人加入会议时sdk自动获取一次成员列表
    
    if(changeInfo)
    {
        //解析result,result形如：
        //{
        //    ChangedInfo =     {
        //        callID = "YmVpamluZy1KVDAwMjA4MjE3MjE0NDYwMDk4NjQzMQ==";
        //        memberlist =         (
        //                              {
        //                                  appAccountID = "10-1111~70038~Phone";
        //                                  memberStatus = 2;
        //                              }
        //                              );
        //    };
        //}
        //操作麦克后结果形如：
        //{
        //    ChangedInfo =     {
        //        callID = YmVpamluZy1KVDAwMjA5MjQ0NTE0NDYwMTQ0OTM3;
        //        memberlist =         (
        //                              {
        //                                  appAccountID = "10-1111~70038~Phone";
        //                                  downAudioState = 0;
        //                                  downVideoState = 0;
        //                                  upAudioState = 0;
        //                                  upVideoState = 0;
        //                              }
        //                              );
        //    };
        //}
    }
    if(connection)
    {
        //解析result,result形如：
        //{
        //    CheckConnection= {
        //        ConfID = ”100734”;
        //    } 
        //}
    }
    if(gvcList)
    {
        //解析result,result形如：
        //{
        //        code = 200;
        //        gvcList =     (
        //        {
        //            callId = "YmVpamluZy1KVDAwMjA2MjA0NDE0NDU1Nzk0MDg0MQ==";
        //            gvcattendingPolicy = 1;
        //            gvcname = test;
        //        }
        //        )；
        //        reason = "\U8bf7\U6c42\U88ab\U6267\U884c";
        //}
        if([gvcList count]>0)
        {
            [joinCallID release];
            joinCallID = [gvcList[0] objectForKey:@"callId"];//这里假设要主动加入第一个会议
            [joinCallID retain];
            [self setLog:[NSString stringWithFormat:@"joinCallID is %@",joinCallID]];
        }
        else
            [self setLog:@"no group found"];
    }
    if(multiLogin)
    {
        // 解析result,result形如：
        //{
        //    multiLogin = {
        //        utt = <userTerminalType>;
        //        utsn = "<userTerminalSN>";
        //        lc = "<logCount>";
        //        oi = " <OtherInfo>";
        //    };
        //}
    }
    if(kickedBy)
    {
        // 解析result,result形如：
        //{
        //    kickedBy =     {
        //        ut = "<userTerminalSN>";
        //        oi = " <OtherInfo>";
        //    };
        //}
    }
    
    return EC_OK;
}

#if (SDK_HAS_GROUP>0)
//多人请求回调
-(int)onGroupResponse:(NSDictionary*)result grpObj:(CallObj*)grpObj
{
    CWLogDebug(@"%s result is %@onCall:%@",__FUNCTION__,result,grpObj);
    [callingView setCallStatus:[NSString stringWithFormat:@"result is %@",result]];
    
    if([result objectForKey:KEY_GRP_CALLID]!=nil&&[result objectForKey:KEY_GRP_CALLID]!=[NSNull null])
    {
        [callID release];
        callID = [result objectForKey:KEY_GRP_CALLID];
        [callID retain];
        CWLogDebug(@"callID in onGroupResponse is %@",callID);
    }
 
    //由哪种请求产生的回调，用action区分，result形如：
    //1、发起会话请求：
    //{
    //    action = 101;
    //    callId = "YmVpamluZy1KVDAwMjA3MTkwNzE0NDYwMTQ3NjkxNg==";
    //    code = 0;
    //    mode = "<null>";
    //    reason = "";
    //    requestId = "2015-10-28 14:46:09:009";
    //}
    //2、获取成员列表请求：
    //{
    //    action = 102;
    //    callId = "YmVpamluZy1KVDAwMjA3MTkxMDE0NDYwMTQ4NTQ1OA==";
    //    code = 0;
    //    memberInfoList =     (
    //                          {
    //                              appAccountID = "10-1111~70038~Phone";
    //                              downAudioState = 1;
    //                              downVideoState = 0;
    //                              duration = 0;
    //                              memberStatus = 2;
    //                              role = 1;
    //                              startTime = 20151028144735;
    //                              upAudioState = 1;
    //                              upVideoState = 0;
    //                          }
    //                          );
    //    reason = success;
    //    requestId = "2015-10-28 14:47:38:038";
    //}
    //3、邀请成员请求：
    //{
    //    action = 103;
    //    callId = "<null>";
    //    code = 0;
    //    mode = 0;
    //    reason = success;
    //    requestId = "2015-10-28 14:49:19:019";
    //}
    //4、踢出成员请求：
    //{
    //    action = 104;
    //    callId = "<null>";
    //    code = 0;
    //    mode = "<null>";
    //    reason = "10-18910903997~70038~Any delete member success !";
    //    requestId = "2015-10-28 14:49:01:001";
    //}
    //5、操作麦克请求：
    //{
    //    action = 105;
    //    code = 0;
    //    controlResult = "<null>";
    //    reason = success;
    //    requestId = "2015-10-28 14:51:59:059";
    //}
    //6、关闭会议请求：
    //{
    //    action = 106;
    //    callId = "<null>";
    //    code = 0;
    //    mode = "<null>";
    //    reason = success;
    //    requestId = "2015-10-28 14:52:28:028";
    //}
    //7、主动加入会议请求：
    //{
    //    action = 107;
    //    code = 0;
    //    mode = 0;
    //    reason = success;
    //    requestId = "2015-10-28 14:51:14:014";
    //}
    //8、分屏请求：
    //{
    //    action = 108;
    //    code = 0;
    //    reason = "screen switch: success!";
    //    requestId = "2015-11-13 18:30:25:025";
    //}
    if([[result objectForKey:KEY_REASON] hasSuffix:@"success!"])
    {
        [mCallObj doChangeView];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6*NSEC_PER_SEC)),dispatch_get_main_queue(),^
       {
           [mCallObj doSetCallVideoWindow:remoteVideoView localVideoWindow:localVideoView];
       });
    }
    
    return EC_OK;
}
#endif

#pragma mark - LocalNotification delegates
#define CALL_INCOMING_FLAG  @"CALL_INCOMING_FLAG"
-(BOOL)isBackground
{
    return [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground
    ||[[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive;
}

//标志后台来电中的状态
-(void)setCallIncomingFlag:(BOOL)reg
{
    [[NSUserDefaults standardUserDefaults]setObject:[NSNumber numberWithBool:reg] forKey:CALL_INCOMING_FLAG];
}

-(BOOL)getCallIncomingFlag
{
    id obj = [[NSUserDefaults standardUserDefaults]objectForKey:CALL_INCOMING_FLAG];
    if (obj)
    {
        return [obj boolValue];
    }
    return NO;
}

//应用从后台切换到前台时，若有来电则弹出来电界面
- (void)onApplicationWillEnterForeground:(UIApplication *)application
{
    if (!mSDKObj || ![mSDKObj isInitOk] || !mAccObj || ![mAccObj isRegisted])
    {
        CWLogDebug(@"isGettingToken:%d",isGettingToken);
        if(!isGettingToken)
        {
            isGettingToken = YES;
            CWLogDebug(@"重新初始化rtc");
            [self doUnRegister];
            [self onSDKInit];
        }
        return;
    }
    if ([self getCallIncomingFlag])
    {
        [self setCallIncomingFlag:NO];
        int callType = [[[NSUserDefaults standardUserDefaults]objectForKey:KEY_CALL_TYPE]intValue];
        
#if(SDK_HAS_GROUP>0)
        NSString* gvcName=@"";
        gvcName = [[NSUserDefaults standardUserDefaults]objectForKey:KEY_GRP_NAME];
#endif
        
        //延时等待应用唤醒后，再创建界面
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^
                       {CCallingViewController* view1 = [[CCallingViewController alloc]init];
                           view1.isVideo = !(callType == AUDIO || callType == AUDIO_RECV || callType == AUDIO_SEND);
                           view1.isCallOut = NO;

#if(SDK_HAS_GROUP>0)
                           if([gvcName isEqualToString:@""])//点对点
                               isGroup = 0;
                           else
                           {
                               isGroup = 1;
                               if(grpType < 20)
                                   view1.isVideo = NO;
                               else
                                   view1.isVideo = YES;
                           }
#endif
                           
        if (view1.isVideo)
        {
            view1.isAutoRotate = isAutoRotationVideo;
        }
        
        view1.view.frame = self.view.frame;
        [callingView release];
        callingView = view1;
        [callingView retain];
        [self presentViewController:view1 animated:NO completion:nil];
        [view1 release];
        });
    }
}

//后台重连
-(void)onAppEnterBackground
{
    if (!mSDKObj || ![mSDKObj isInitOk] || !mAccObj || ![mAccObj isRegisted])
    {
        CWLogDebug(@"isGettingToken:%d",isGettingToken);
        if(!isGettingToken)
        {
            isGettingToken = YES;
            CWLogDebug(@"重新初始化rtc");
            [self doUnRegister];
            [self onSDKInit];
        }
        return;
    }
    [mSDKObj onAppEnterBackground];//SDK长连接
}

-(void)onNetworkChanged:(BOOL)netstatus
{
    if(netstatus)
    {
        CWLogDebug(@"networkChanged to YES");
        if (!mSDKObj || ![mSDKObj isInitOk] || !mAccObj || ![mAccObj isRegisted])
        {
            CWLogDebug(@"isGettingToken:%d",isGettingToken);
            if(!isGettingToken)
            {
                isGettingToken = YES;
                CWLogDebug(@"重新初始化rtc");
                [self doUnRegister];
                [self onSDKInit];
            }
            return;
        }
        
        [mSDKObj onAppEnterBackground];//网络恢复后进行重连
    }
    else
    {
        CWLogDebug(@"networkChanged to NO");
        [mSDKObj onNetworkChanged];//网络断开后销毁网络数据

        if(mCallObj)//通话被迫结束，销毁通话界面
        {
            NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                                    [NSNumber numberWithInt:MSG_HANGUP],@"msgid",
                                    [NSNumber numberWithInt:0],@"arg",
                                    nil];
            [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
        }
    }
}

-(BOOL)accObjIsRegisted
{
    if (mAccObj && [mAccObj isRegisted])
        return  YES;
    return NO;
}
@end
