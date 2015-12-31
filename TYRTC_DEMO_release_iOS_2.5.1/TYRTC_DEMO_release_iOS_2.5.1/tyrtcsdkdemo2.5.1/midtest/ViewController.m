#import "ViewController.h"
#import "JSONKit.h"
#import "sdkobj.h"
#import "sdkkey.h"
#import "sdkerrorcode.h"
#import "CCallingViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <AVFoundation/AVCaptureSession.h>

#define APP_USER_AGENT      @"vvdemo"
#define APP_VERSION         @"V2.5.1_B20151015"
#define U1 @"5668"
#define U2 @"8889"

static int cameraIndex = 1;//切换摄像头索引,1为前置
#if(SDK_HAS_GROUP>0)
extern int isGroupCreator;
extern SDK_GROUP_TYPE grpType;
extern int isCallGroup;
NSString*   joinCallID;
#endif

typedef enum _ACTIONSHEETTAG
{
    TAG_ACCEPT_CALL = 1000,
    TAG_TRANSPORT_SELECT,
    TAG_VIDEOSIZE_SET,
    TAG_AUDIO_CODEC_SELECT,
    TAG_VIDEO_CODEC_SELECT,
    TAG_GROUP_TYPE_SELECT,
    TAG_ACCTYPE_SELECT,
    TAG_REMOTE_ACCTYPE_SELECT,
    TAG_TERMINAL_TYPE_SELECT,
    TAG_REMOTE_TERMINAL_TYPE_SELECT,
}ACTIONSHEETTAG;

@interface ViewController()
{
    SdkObj* mSDKObj;
    AccObj* mAccObj;
    CallObj*  mCallObj;
    CGSize  mVideoSize;
    
    SDK_ACCTYPE         accType;
    NSString*   terminalType;
    NSString*   remoteTerminalType;
    SDK_ACCTYPE         remoteAccType;
    
#if (SDK_HAS_GROUP>0)
    NSString*   callID;
#endif
    
    BOOL isAutoRotationVideo;//是否自动适配本地采集的视频,使发送出去的视频永远是人头朝上
    int     mLogIndex;
    IOSDisplay *videoView;
    UIView *localVideoView;
    CCallingViewController* callingView;
    NSString *mToken;
    NSString *mAccountID;
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
    
    //账户行
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
    [self addGridBtn:@"登录"         func:@selector(onSDKInit:)         rect:rect];
    
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
    
    //totalIndex++;
    
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRecvEvent:) name:@"NOTIFY_EVENT" object:nil];
   
    [mUser1 setText:U1];
    [mUser2 setText:U2];
    mSDKObj = nil;
    mAccObj = nil;
    mVideoSize = CGSizeMake(288, 352);
    mLogIndex = 0;
    [self setLog:APP_VERSION];
    
    isAutoRotationVideo = YES;
    
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
    [videoView release];
    videoView = nil;
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
- (IBAction)onSDKInit:(id)sender
{
    if (mSDKObj)
    {
        if ([mSDKObj isInitOk])
        {
            [self setLog:@"已初始化成功"];
            return;
        }
    }
    
    signal(SIGPIPE, SIG_IGN);
    mLogIndex = 0;
    mSDKObj = [[SdkObj alloc]init];
    [mSDKObj setSdkAgent:APP_USER_AGENT terminalType:terminalType UDID:[OpenUDID value] appID:@"123" appKey:@"123456"];
    [mSDKObj setDelegate:self];
    [mSDKObj doNavigation:@"default"];
}

/**************************************用户登录/注销*****************************************/
- (void)onRegister
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    if (!mAccObj)
    {
        [self setLog:@"登录中..."];
        mAccObj = [[AccObj alloc]init];
        [mAccObj bindSdkObj:mSDKObj];
        mAccObj.Delegate = self;
        //此句getToken代码为临时做法，开发者需通过第三方应用平台获取token，无需通过此接口获取
        //获取到返回结果后，请调用doAccRegister接口进行注册，传入参数为服务器返回的结构
        //不要重复获取token，除非token失效才需重新获取
        if(!mToken)
            [mAccObj getToken:mUser1.text andType:accType andGrant:@"100<200<301<302<303<304<400" andAuthType:ACC_AUTH_TO_APPALL];
        else
        {
            NSMutableDictionary *newResult = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
            [newResult setObject:mToken forKey:KEY_CAPABILITYTOKEN];
            [newResult setObject:mAccountID forKey:KEY_RTCACCOUNTID];
            //[newResult setObject:[NSNumber numberWithDouble:2] forKey:KEY_ACC_SRTP];//若与浏览器互通则打开
            [mAccObj doAccRegister:newResult];
        }
    }
    else if ([mAccObj isRegisted])
    {
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
    if (mAccObj)
    {
        [mAccObj doUnRegister];
        [mAccObj release];
        mAccObj = nil;
        mToken = nil;
        mAccountID = nil;
        [self setLog:@"注销完毕"];
        
        if(mSDKObj)
        {
            [mSDKObj release];
            mSDKObj = nil;
            mLogIndex = 0;
            [self setLog:@"release完毕"];
        }
    }
    else
    {
        [self setLog:@"请先登录"];
    }
}

/**************************************创建呼叫界面*****************************************/
- (IBAction)onMakeAudioCall:(id)sender
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    CCallingViewController* view1 = [[CCallingViewController alloc]init];//触发onSendVideoParam
    view1.isVideo = NO;
    view1.isCallOut = YES;
    
#if(SDK_HAS_GROUP>0)
    isCallGroup = 0;
#endif
    
    view1.view.frame = self.view.frame;
    callingView = view1;
    [self presentViewController:view1 animated:NO completion:nil];
    [view1 release];
}

- (IBAction)onMakeVideoCall:(id)sender
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    CCallingViewController* view1 = [[CCallingViewController alloc]init];//触发onSendVideoParam
    view1.isVideo = YES;
    view1.isCallOut = YES;
    
#if(SDK_HAS_GROUP>0)
    isCallGroup = 0;
#endif
    
    view1.isAutoRotate = isAutoRotationVideo;
    view1.view.frame = self.view.frame;
    callingView = view1;
    [self presentViewController:view1 animated:NO completion:nil];
    [view1 release];
}

#if (SDK_HAS_GROUP>0)
- (IBAction)onGroupCall:(id)sender
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    CCallingViewController* view1 = [[CCallingViewController alloc]init];
    view1.isCallOut = YES;
    isCallGroup = 1;
    if(grpType>=20)
    {
        view1.isVideo = YES;
        view1.isAutoRotate = isAutoRotationVideo;
    }
    else
        view1.isVideo = NO;
    view1.view.frame = self.view.frame;
    callingView = view1;
    [self presentViewController:view1 animated:NO completion:nil];
    [view1 release];
}

- (IBAction)onGroupJoin:(id)sender
{
    if(!mSDKObj)
    {
        [self setLog:@"请先初始化"];
        return;
    }
    CCallingViewController* view1 = [[CCallingViewController alloc]init];
    view1.isCallOut = YES;
    isCallGroup = 2;
    if(grpType>=20)
    {
        view1.isVideo = YES;
        view1.isAutoRotate = isAutoRotationVideo;
    }
    else
        view1.isVideo = NO;
    view1.view.frame = self.view.frame;
    callingView = view1;
    [self presentViewController:view1 animated:NO completion:nil];
    [view1 release];
}

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
                         @"嗨，你好！",KEY_CALL_INFO,
                         nil];
    [mAccObj doSendIM:dic];
}

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
    [dateFormat setDateFormat:@"mm:ss"];
    [dateFormat setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [dateFormat setLocale:usLocale];
    [usLocale release];
    NSString* datestr = [dateFormat stringFromDate:[NSDate date]];
    [dateFormat release];
    
    NSString* str = [NSString stringWithFormat:@"%@:%@",datestr,log];
    [mStatus setText:str];
    [[NSUserDefaults standardUserDefaults]setObject:str forKey:[NSString stringWithFormat:@"ViewLog%d",mLogIndex]];
    mLogIndex++;
}

#pragma mark - UIActionSheetDelegate
/**************************************事件监听/回调*****************************************/

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
        long long localV = [[data objectForKey:@"lvideo"]longLongValue];
        long long remoteV = [[data objectForKey:@"rvideo"]longLongValue];
        videoView = (IOSDisplay*)remoteV;
        localVideoView = (UIView*)localV;
        BOOL isCallOut = [[data objectForKey:@"iscallout"]boolValue];
        
        if (nil == mCallObj && isCallOut )
        {
            mCallObj = [[CallObj alloc]init];
            mCallObj.Delegate = self;
            [mCallObj bindAcc:mAccObj];
#if (SDK_HAS_VIDEO>0)
            SDK_CALLTYPE callType = (remoteV != 0)? VIDEO_CALL:AUDIO_CALL;
            mCallObj.CallMedia = (remoteV != 0)? MEDIA_TYPE_VIDEO:MEDIA_TYPE_AUDIO;
#else
            SDK_CALLTYPE callType = AUDIO_CALL;
            mCallObj.CallMedia = MEDIA_TYPE_AUDIO;
#endif
            
            NSString* remoteUri = mUser2.text;
            NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 remoteUri,KEY_CALLED,
                                 [NSNumber numberWithInt:callType],KEY_CALL_TYPE,
                                 [NSNumber numberWithInt:remoteAccType],KEY_CALL_REMOTE_ACC_TYPE,
                                 remoteTerminalType,KEY_CALL_REMOTE_TERMINAL_TYPE,
                                 @"yewuxinxi",KEY_CALL_INFO,
                                 nil];
            int ret = [mCallObj doMakeCall:dic];
            if (EC_OK > ret)
            {
                if (mCallObj)
                    [mCallObj doHangupCall];
                if (mCallObj)
                {
                    [mCallObj release];
                    mCallObj = nil;
                }
                
                [self closeCallingView];
                [self setLog:[NSString stringWithFormat:@"创建呼叫失败:%@",[SdkObj ECodeToStr:ret]]];
                
            }
            [mCallObj doSwitchAudioDevice:SDK_AUDIO_OUTPUT_DEFAULT];
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
        SDK_AUDIO_OUTPUT_DEVICE ad = [mCallObj getAudioOutputDeviceType];
        if (SDK_AUDIO_OUTPUT_DEFAULT == ad || SDK_AUDIO_OUTPUT_HEADSET == ad)
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
        if (mCallObj)
            [mCallObj doHangupCall];
        if (mCallObj)
        {
            [mCallObj release];
        }
        mCallObj = nil;
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
            [mCallObj doAcceptCall:[NSNumber numberWithInt:AUDIO_CALL]];
            //[mCallObj doSwitchAudioDevice:SDK_AUDIO_OUTPUT_SPEAKER];
        }
#if (SDK_HAS_VIDEO>0)
        else
        {
            long long localV = [[data objectForKey:@"lvideo"]longLongValue];
            long long remoteV = [[data objectForKey:@"rvideo"]longLongValue];
            videoView = (IOSDisplay*)remoteV;
            localVideoView = (UIView*)localV;
            [mCallObj doAcceptCall:[NSNumber numberWithInt:VIDEO_CALL]];
        }
#endif
        [callingView onCallOk:YES];
        return;
    }
    if (MSG_REJECT == msgid)//拒接
    {
        [mCallObj doRejectCall];
        [self closeCallingView];
        if (mCallObj)
        {
            [mCallObj release];
        }
        mCallObj = nil;
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
    if (MSG_GROUP_CREATE == msgid)//创建多人会话
    {
        long long localV = [[data objectForKey:@"lvideo"]longLongValue];
        long long remoteV = [[data objectForKey:@"rvideo"]longLongValue];
        videoView = (IOSDisplay*)remoteV;
        localVideoView = (UIView*)localV;
        BOOL isCallOut = [[data objectForKey:@"iscallout"]boolValue];
        
        if (nil == mCallObj && isCallOut )
        {
            mCallObj = [[CallObj alloc]init];
            mCallObj.Delegate = self;
            [mCallObj bindAcc:mAccObj];
#if (SDK_HAS_VIDEO>0)
            mCallObj.CallMedia = (remoteV != 0)? MEDIA_TYPE_VIDEO:MEDIA_TYPE_AUDIO;
#else
            mCallObj.CallMedia = MEDIA_TYPE_AUDIO;
#endif
            
            NSString* remoteUri = mUser1.text;
            NSString* remoteUri2 = [NSString stringWithFormat:@"%@,%@",mUser1.text,mUser2.text];//账号之间用逗号隔开
            NSArray* remoteAccArr = [remoteUri2 componentsSeparatedByString:@","];
            NSUInteger countMem=[remoteAccArr count];
            NSMutableArray* remoteTypeArr = [NSMutableArray arrayWithObjects:
                                             [NSNumber numberWithInt:accType],
                                             nil];
            for(int i = 1; i<countMem; i++)
            {
                [remoteTypeArr addObject:[NSNumber numberWithInt:remoteAccType]];
            }
            NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 remoteUri,KEY_GRP_CREATER,
                                 terminalType,KEY_GRP_CREATERTYPE,
                                 [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                                 remoteTypeArr,KEY_CALL_REMOTE_ACC_TYPE,
                                 [NSNumber numberWithInt:grpType],KEY_GRP_TYPE,
                                 @"groupname",KEY_GRP_NAME,
                                 remoteUri2,KEY_GRP_INVITEELIST,
                                 @"kong",KEY_GRP_PASSWORD,
                                 nil];
            int ret = [mCallObj groupCall:SDK_GROUP_CREATE param:dic];
            if (EC_OK > ret)
            {
                if (mCallObj)
                    [mCallObj doHangupCall];
                if (mCallObj)
                {
                    [mCallObj release];
                    mCallObj = nil;
                }
                
                [self closeCallingView];
                [self setLog:[NSString stringWithFormat:@"创建呼叫失败:%@",[SdkObj ECodeToStr:ret]]];
                
            }
            [mCallObj doSwitchAudioDevice:SDK_AUDIO_OUTPUT_DEFAULT];
        }
        return;
    }
    if (MSG_GROUP_ACCEPT == msgid)//多人创建者自动接听
    {
        if (mCallObj.CallMedia == MEDIA_TYPE_AUDIO)
            [mCallObj performSelector:@selector(doAcceptCall:) withObject:[NSNumber numberWithInt:AUDIO_CALL] afterDelay:0.1];
#if (SDK_HAS_VIDEO>0)
        else
        {
            long long localV = [[data objectForKey:@"lvideo"]longLongValue];
            long long remoteV = [[data objectForKey:@"rvideo"]longLongValue];
            videoView = (IOSDisplay*)remoteV;
            localVideoView = (UIView*)localV;
            [mCallObj performSelector:@selector(doAcceptCall:) withObject:[NSNumber numberWithInt:VIDEO_CALL] afterDelay:0.1];
        }
#endif
        [callingView onCallOk:YES];
        return;
    }
    if (MSG_GROUP_LIST == msgid)//获取多人列表
    {
        NSString* remoteUri = mUser1.text;
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
        videoView = (IOSDisplay*)remoteV;
        localVideoView = (UIView*)localV;
        BOOL isCallOut = [[data objectForKey:@"iscallout"]boolValue];
        
        if (nil == mCallObj && isCallOut )
        {
            mCallObj = [[CallObj alloc]init];
            mCallObj.Delegate = self;
            [mCallObj bindAcc:mAccObj];
#if (SDK_HAS_VIDEO>0)
            mCallObj.CallMedia = (remoteV != 0)? MEDIA_TYPE_VIDEO:MEDIA_TYPE_AUDIO;
#else
            mCallObj.CallMedia = MEDIA_TYPE_AUDIO;
#endif
            
            NSString* remoteUri = mUser1.text;
            NSString* joinID = joinCallID;//此处填入callID
            
            int mode=SDK_GROUP_AUDIO_SENDRECV;//语音群聊
            if(grpType == 21 || grpType == 22 || grpType == 29)//视频对讲或两方或直播
                mode = SDK_GROUP_AUDIO_RECVONLY_VIDEO_RECVONLY;
            else if(grpType == 1 || grpType == 2 || grpType == 9)//语音对讲或两方或直播
                mode = SDK_GROUP_AUDIO_RECVONLY;
            else if(grpType == 20 )//视频群聊
                mode = -1;
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
            if (EC_OK > ret)
            {
                [self setLog:[NSString stringWithFormat:@"加入会议失败:%@",[SdkObj ECodeToStr:ret]]];
            }
            [mCallObj doSwitchAudioDevice:SDK_AUDIO_OUTPUT_DEFAULT];
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
        NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:
                             remoteUri,KEY_GRP_CREATER,
                             terminalType,KEY_GRP_CREATERTYPE,
                             [NSNumber numberWithInt:accType],KEY_CALL_ACC_TYPE,
                             remoteTypeArr,KEY_CALL_REMOTE_ACC_TYPE,
                             callID,KEY_GRP_CALLID,
                             memberList,KEY_GRP_MEMBERLIST,
                             memberList,KEY_GRP_MBTOSET,
                             [NSNumber numberWithInt:1],KEY_GRP_MBSETSTYLE,
                             [NSNumber numberWithInt:1],KEY_GRP_SCREENSPLIT,
                             [NSNumber numberWithInt:1],KEY_GRP_LV,
                             nil];
        int ret = [mCallObj groupCall:SDK_GROUP_VIDEO param:dic];
        if (EC_OK > ret)
        {
            [self setLog:[NSString stringWithFormat:@"分屏失败:%@",[SdkObj ECodeToStr:ret]]];
        }
    }
#endif
}

//导航结果回调
-(void)onNavigationResp:(int)code error:(NSString*)error
{
    if (0 == code)
    {
        [self setLog:[NSString stringWithFormat:@"初始化成功"]];
        
        
        [mSDKObj setAudioCodec:[NSNumber numberWithInt:1]];//iLBC
#if (SDK_HAS_VIDEO>0)
        [mSDKObj setVideoCodec:[NSNumber numberWithInt:1]];//VP8
        [mSDKObj setVideoAttr:[NSNumber numberWithInt:5]];//4CIF
#endif

        [self onRegister];
    }
    else
    {
        [self setLog:[NSString stringWithFormat:@"初始化失败:%d,%@",code,error]];
        [mSDKObj release];
        mSDKObj = nil;
    }
}

//在这里增加来电后台通知或前台弹呼叫接听页面
-(int)onCallIncoming:(NSDictionary*)param withNewCallObj:(CallObj*)newCallObj accObj:(AccObj*)accObj
{
    mCallObj = newCallObj;
    [mCallObj setDelegate:self];
    int callType = [[param objectForKey:KEY_CALL_TYPE]intValue];
    NSString* uri = [param objectForKey:KEY_CALLER];
    
    if ([self isBackground])
    {
        [self setCallIncomingFlag:YES];
        [[NSUserDefaults standardUserDefaults]setObject:[NSNumber numberWithInt:callType] forKey:KEY_CALL_TYPE];
        [[NSUserDefaults standardUserDefaults]setObject:uri     forKey:KEY_CALLER];
#if(SDK_HAS_GROUP>0)
        [[NSUserDefaults standardUserDefaults]setObject:@""     forKey:KEY_GRP_NAME];
#endif
        makeNotification(@"接听",[NSString stringWithFormat:@"来电:%@",uri],UILocalNotificationDefaultSoundName,YES);
        return 0;
    }
    CCallingViewController* view1 = [[CCallingViewController alloc]init];//弹呼叫接听页面
    view1.isVideo = !(callType == AUDIO_CALL || callType == AUDIO_CALL_RECVONLY || callType == AUDIO_CALL_SENDONLY);
    view1.isCallOut = NO;
#if(SDK_HAS_GROUP>0)
    isCallGroup = 0;
#endif
    if (view1.isVideo)
        view1.isAutoRotate = isAutoRotationVideo;
    view1.view.frame = self.view.frame;
    callingView = view1;
    [self presentViewController:view1 animated:NO completion:nil];
    [view1 release];
    
    return 0;
}

/////////////////////////////////回调函数：消息到达通知///////////////////////////////////////
-(int)onReceiveIM:(NSDictionary*)param withAccObj:(AccObj*)accObj
{
    CWLogDebug(@"result is %@onCall:%@",param,accObj);
    
    NSString* mime = [param objectForKey:KEY_CALL_TYPE];
    NSString* uri = [param objectForKey:KEY_CALLER];
    NSString* content = [param objectForKey:KEY_CALL_INFO];
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
    NSString* accNum = [[NSString stringWithUTF8String:cacc] substringWithRange:NSMakeRange(strindex1+1, strindex2-strindex1-1)];
    
    return 0;
}

/////////////////////////////////回调函数：消息发送通知///////////////////////////////////////
-(int)onSendIM:(int)status
{
    [self setLog:[NSString stringWithFormat:@"发送消息:%d",status]];
    
    return 0;
}

#if (SDK_HAS_GROUP>0)
//多人创建回调
-(int)onGroupCreate:(NSDictionary*)param withNewCallObj:(CallObj*)newCallObj accObj:(AccObj*)accObj
{
    CWLogDebug(@"%s result is %@onCall:%@",__FUNCTION__,param,accObj);
    //在这里增加来电后台通知或前台弹呼叫接听页面
    
    mCallObj = newCallObj;
    [mCallObj setDelegate:self];
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
    
    if (!isGroupCreator)
    {
        if ([self isBackground])
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
        isCallGroup = 1;//1或2
        
        if (view1.isVideo)
            view1.isAutoRotate = isAutoRotationVideo;
        view1.view.frame = self.view.frame;
        callingView = view1;
        [self presentViewController:view1 animated:NO completion:nil];
        [view1 release];
    }
    else
    {
        [self setLog:@"已接听"];
        NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                                [NSNumber numberWithInt:MSG_GROUP_ACCEPT],@"msgid",
                                [NSNumber numberWithInt:0],@"arg",
                                [NSNumber numberWithLongLong:(long long)(videoView)],@"rvideo",
                                [NSNumber numberWithLongLong:(long long)(localVideoView)],@"lvideo",
                                nil];
        //CWLogDebug(@"param is %@",params);
        [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
    }
    
    return EC_OK;
}
#endif

//用户在线状态查询结果回调
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
        int i = 0;
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

//注册结果回调
-(int)onRegisterResponse:(NSDictionary*)result  accObj:(AccObj*)accObj
{
    mToken = [result objectForKey:KEY_CAPABILITYTOKEN];
    mAccountID = [result objectForKey:KEY_RTCACCOUNTID];
    if(mToken)
    {
        NSMutableDictionary *newResult = [NSMutableDictionary dictionaryWithObjectsAndKeys:nil];
        [newResult setObject:mToken forKey:KEY_CAPABILITYTOKEN];
        [newResult setObject:mAccountID forKey:KEY_RTCACCOUNTID];
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
        [self setLog:[NSString stringWithFormat:@"登录失败:%d:%@",nRspCode,sReason]];
        
        if (mAccObj)
        {
            [mAccObj doUnRegister];
            [mAccObj release];
            mAccObj = nil;
            mToken = nil;
            mAccountID = nil;
            [self setLog:@"注销完毕"];
            
            if(mSDKObj)
            {
                [mSDKObj release];
                mSDKObj = nil;
                mLogIndex = 0;
                [self setLog:@"release完毕"];
            }
        }
    }
    
    return EC_OK;
}

/////////////////////////////////////回调函数：反馈消息上报///////////////////////////////////////////////
-(int)onNotifyMessage:(NSDictionary*)result  accObj:(AccObj*)accObj
{
    CWLogDebug(@"%s result is %@onNotify:%@",__FUNCTION__,result,accObj);
    NSString* changeInfo = [result objectForKey:@"ChangedInfo"];//成员状态变化，@"callID"表示会话id,@"memberlist"表示成员列表
    NSString* connection = [result objectForKey:@"CheckConnection"];//成员异常掉线,@"ConfID"表示会话id
    NSString* kickedBy = [result objectForKey:@"kickedBy"];//成员被踢出
    NSString* multiLogin = [result objectForKey:@"multiLogin"];//多终端登录
    
    NSArray* gvcList = [result objectForKey:@"gvcList"];//会议列表
    if([gvcList count]>0)
    {
        [joinCallID release];
        joinCallID = [gvcList[0] objectForKey:@"callId"];
        [joinCallID retain];
        [self setLog:[NSString stringWithFormat:@"joinCallID is %@",joinCallID]];
    }
    else
        [self setLog:@"no group found"];
    
    return EC_OK;
}

//呼叫事件回调
-(int)onCallBack:(SDK_CALLBACK_TYPE)type code:(int)code callObj:(CallObj*)callObj
{
    [self setLog:[NSString stringWithFormat:@"呼叫事件:%d code:%d",type,code]];
    //不同事件类型见SDK_CALLBACK_TYPE
    if(type == SDK_CALLBACK_RING)
    {
        //[self setLog:[NSString stringWithFormat:@"呼叫中%d...",code]];
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
        if (mCallObj)
        {
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
    if(isCallGroup != 0 && grpType<20)//多人语音
    {
        [self setCallIncomingFlag:NO];
        return 0;
    }
#endif
    
#if (SDK_HAS_VIDEO>0)
    if (mediaType == MEDIA_TYPE_VIDEO)
    {
        int ret = [callObj doSetCallVideoWindow:videoView localVideoWindow:localVideoView];
    }
#endif
    [self setCallIncomingFlag:NO];
    return 0;
}

//呼叫网络状态事件通知
-(int)onNetworkStatus:(NSString*)desc callObj:(CallObj*)callObj
{
//    if (desc && callingView)
//    {
//        NSDictionary* dic = [desc objectFromJSONString];
//        //int msg = [[dic objectForKey:@"msg"]intValue];
//        //int codec = [[dic objectForKey:@"codec"]intValue];
//        int w = [[dic objectForKey:@"w"]intValue];
//        int h = [[dic objectForKey:@"h"]intValue];
//        int recvFrameRate = [[dic objectForKey:@"rf"]intValue];
//        //int recvBitrate = [[dic objectForKey:@"rb"]intValue];
//        int recvLost = [[dic objectForKey:@"lost"]intValue];
//        int sendFrameRate = [[dic objectForKey:@"sf"]intValue];
//        //int sendBitrate = [[dic objectForKey:@"sb"]intValue];
//        if (w == 0 || h == 0)
//            return 0;
////        [callingView setVideoStatus:
////         [NSString stringWithFormat:@"[V:%d*%d][SF:%d][RF:%d[RL:%d]",
////          w,h,
////          sendFrameRate,
////          recvFrameRate,recvLost
////          ]];//在界面显示网络状态
//        
//        
//    }
    return 0;
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

- (void)onApplicationWillEnterForeground:(UIApplication *)application
{
    if ([self getCallIncomingFlag])//应用从后台切换到前台时，若来电则弹出来电界面
    {
        [self setCallIncomingFlag:NO];
        int callType = [[[NSUserDefaults standardUserDefaults]objectForKey:KEY_CALL_TYPE]intValue];
        
#if(SDK_HAS_GROUP>0)
        NSString* gvcName=@"";
        gvcName = [[NSUserDefaults standardUserDefaults]objectForKey:KEY_GRP_NAME];
#endif
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^
                       {CCallingViewController* view1 = [[CCallingViewController alloc]init];
                           view1.isVideo = !(callType == AUDIO_CALL || callType == AUDIO_CALL_RECVONLY || callType == AUDIO_CALL_SENDONLY);
                           view1.isCallOut = NO;

#if(SDK_HAS_GROUP>0)
                           if([gvcName isEqualToString:@""])//点对点
                               isCallGroup = 0;
                           else
                           {
                               isCallGroup = 1;
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
    if (nil == mSDKObj || nil == mAccObj || NO == [mSDKObj isInitOk] || NO == [mAccObj isRegisted])
        return;
    [mSDKObj onAppEnterBackground];
}

-(void)onNetworkChanged:(BOOL)netstatus
{
    if (nil == mSDKObj || nil == mAccObj || NO == [mSDKObj isInitOk] || NO == [mAccObj isRegisted])
        return;
    CWLogDebug(@"networkChanged");
    if(netstatus)
        [mSDKObj onAppEnterBackground];//网络恢复后进行重连
    else
    {
        [mSDKObj onNetworkChanged];//网络断开后销毁网络数据

        if(mCallObj)//呼叫中
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
