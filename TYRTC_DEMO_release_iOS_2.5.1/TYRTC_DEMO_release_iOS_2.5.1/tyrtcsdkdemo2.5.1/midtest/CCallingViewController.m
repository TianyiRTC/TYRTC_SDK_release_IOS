#import "CCallingViewController.h"
#import "sdkobj.h"
#import "DAPIPView.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <AVFoundation/AVCaptureSession.h>
#import <CoreMotion/CoreMotion.h>

#if(SDK_HAS_GROUP>0)
int isGroupCreator=0;//0为普通成员，1为创建者
SDK_GROUP_TYPE grpType=SDK_GROUP_CHAT_AUDIO;
int isCallGroup;//0表示点对点,1表示主动发起多人,2表示主动参加多人
#endif
@interface CCallingViewController ()
{
    int mRotate;
    CMMotionManager *mMotionManager;
    int mLogIndex;
    BOOL mMuteState;//NO 未静音;YES 已静音
    
    BOOL mHoldState;//NO 未Hold,YES 已HOLD
    //NSTimer* mCallDurationTimer;
}
@property (strong, nonatomic) UIView *localVideoView;
@property (strong, nonatomic) DAPIPView *dapiview;
@property (strong, nonatomic) IOSDisplay *remoteVideoView;
@property (strong, nonatomic) UIButton* btnMute;
@property (strong, nonatomic) UIButton* btnSpeaker;
@property (strong, nonatomic) UITextField*           mStatus;
@property (strong, nonatomic) UIButton* btnAccept;
@property (strong, nonatomic) UIButton* btnReject;
@property (strong, nonatomic) UIButton* btnHangup;
@property (strong, nonatomic) UILabel*  lblCallStatus;
@property (strong, nonatomic) UIButton* btnSwitchCamera;
@property (strong, nonatomic) UIButton* btnHideLocalVideo;
@property (strong, nonatomic) UIButton* btnRemoteVideoRotate;
@property (strong, nonatomic) UIButton* btnSnapRemote;
#if(SDK_HAS_GROUP>0)
@property (strong, nonatomic) UIButton* btnGroupList;
@property (strong, nonatomic) UIButton* btnGroupInvite;
@property (strong, nonatomic) UIButton* btnGroupKick;
@property (strong, nonatomic) UIButton* btnGroupClose;
@property (strong, nonatomic) UIButton* btnGroupMic;
@property (strong, nonatomic) UIButton* btnGroupUnMic;
@property (strong, nonatomic) UIButton* btnGroupDisplay;
#endif
@end

@implementation CCallingViewController
@synthesize localVideoView = _localVideoView;
@synthesize dapiview = _dapiview;
@synthesize remoteVideoView = _remoteVideoView;
@synthesize isCallOut;
@synthesize isVideo;
@synthesize isAutoRotate;
@synthesize btnHangup,btnAccept,btnReject,btnMute,btnSpeaker,lblCallStatus,mStatus,btnSwitchCamera,btnHideLocalVideo,btnRemoteVideoRotate,btnSnapRemote;
#if(SDK_HAS_GROUP>0)
@synthesize btnGroupList,btnGroupInvite,btnGroupKick,btnGroupClose,btnGroupMic,btnGroupUnMic,btnGroupDisplay;
@synthesize mUser3;
#endif

/**************************************界面部分*****************************************/
-(int)getLineIndex:(int) cntIndex
{
    return cntIndex/4;
}

-(int)getColIndex:(int) cntIndex
{
    return cntIndex%4;
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

-(UIButton*)addGridBtn:(NSString*)title  func:(SEL)func rect:(CGRect)rect
{
    UIButton* btnItem = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btnItem.frame = rect;
    [btnItem addTarget:self action:func forControlEvents:UIControlEventTouchDown];
    [btnItem setTitle:title forState:UIControlStateNormal];
    [btnItem setBackgroundColor:[UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1]];
    [btnItem.layer setMasksToBounds:YES];
    [btnItem.layer setCornerRadius:10.0];
    [self.view addSubview:btnItem];
    
    return btnItem;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view = [[UIView alloc]initWithFrame:CGRectMake(0.0, IOS7_STATUSBAR_DELTA, SCREEN_WIDTH, SCREEN_HEIGHT)];
    self.view.backgroundColor = [UIColor whiteColor];
    self.view.tag = CALLINGVIEW_TAG;
    int height = 30;
    int width = 60;
    int sep = 20;
    int x = 10;
    int y = 30;
    UIButton* btnItem;
    UITextField* tfItem;
    
    DAPIPView* dvItem = [[DAPIPView alloc] init];
    self.dapiview = dvItem;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        self.dapiview.borderInsets = UIEdgeInsetsMake(1.0f,       // top
                                                      1.0f,       // left
                                                      45.0f,      // bottom
                                                      1.0f);      // right
    }
    else
    {
        self.dapiview.borderInsets = UIEdgeInsetsMake(1.0f,       // top
                                                      1.0f,       // left
                                                      1.0f,       // bottom
                                                      1.0f);      // right
    }
    
    IOSDisplay* ivItem = [[IOSDisplay alloc]initWithFrame:self.view.bounds];
    //ivItem.backgroundColor = [UIColor blackColor];
    self.remoteVideoView = ivItem;
    [self.view addSubview:ivItem];
    [ivItem release];
    
    UIView* vItem = [[UIView alloc]initWithFrame:self.dapiview.bounds];
    vItem.backgroundColor = [UIColor redColor];
    vItem.center = CGPointMake(self.dapiview.bounds.size.width/2, self.dapiview.bounds.size.height/2);
    self.localVideoView = vItem;
    [self.dapiview addSubview:vItem];
    [vItem release];
    
    [self.view addSubview:dvItem];
    [dvItem release];
    
    btnItem = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btnItem.frame = CGRectMake(10, 20, height, height);
    [btnItem setTitle:@"日志" forState:UIControlStateNormal];
    [self.view addSubview:btnItem];
    
    tfItem = [[UITextField alloc]initWithFrame:CGRectMake(20+height+10, 20, 300-height-10, 30)];
    tfItem.placeholder = @"操作日志";
    tfItem.textAlignment = NSTextAlignmentLeft;
    tfItem.borderStyle = UITextBorderStyleRoundedRect;
    tfItem.keyboardType = UIKeyboardTypeNumberPad;
    [self.view addSubview:tfItem];
    self.mStatus = tfItem;
    [tfItem release];
    
#if(SDK_HAS_GROUP>0)
    CGRect tfItemFrame;
    CGFloat lblWidth = 80;
    CGFloat lblSep = 10;
    
    tfItemFrame.origin.y += sep + height;
    tfItemFrame = CGRectMake(10, tfItemFrame.origin.y, 320-x-lblWidth-lblSep, height);
    
    tfItem = [[UITextField alloc]initWithFrame:tfItemFrame];
    tfItem.placeholder = @"远端账号";
    tfItem.textAlignment = NSTextAlignmentLeft;
    tfItem.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:tfItem];
    mUser3 = tfItem;
    [tfItem release];
    [mUser3 setText:@"1113"];
    [mUser3  setHidden:YES];
#endif
    
    y += height*2;
    CGFloat xSep = 8;
    int totalIndex = 0;
    
    CGRect rect;
    CGPoint start = CGPointMake(x, y);
    CGSize size = CGSizeMake(width, height);
    
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnMute = [self addGridBtn:@"静音"     func:@selector(onMuteMic:)       rect:rect];
    totalIndex--;
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnAccept = [self addGridBtn:@"接听"   func:@selector(onBtnAccept:)     rect:rect];
    
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnSpeaker = [self addGridBtn:@"扬声器"    func:@selector(onSpeakerSwitch:) rect:rect];
    totalIndex--;
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnReject = [self addGridBtn:@"拒绝"   func:@selector(onBtnReject:)     rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnHangup = [self addGridBtn:@"结束"     func:@selector(onBtnExit:)       rect:rect];
    
    totalIndex++;
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnSwitchCamera = [self addGridBtn:@"切换"     func:@selector(onBtnSwapCamera:)       rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnRemoteVideoRotate = [self addGridBtn:@"旋转"    func:@selector(onRotateRemote:) rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnHideLocalVideo = [self addGridBtn:@"隐藏"   func:@selector(onLocalVideoShow:)     rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnSnapRemote = [self addGridBtn:@"截图"     func:@selector(onSnap:)       rect:rect];

#if(SDK_HAS_GROUP>0)
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnGroupList = [self addGridBtn:@"列表"     func:@selector(onBtnGroupList:)       rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnGroupInvite = [self addGridBtn:@"邀请"     func:@selector(onBtnGroupInvite:)       rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnGroupKick = [self addGridBtn:@"踢出"     func:@selector(onBtnGroupKick:)       rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnGroupClose = [self addGridBtn:@"关闭"     func:@selector(onBtnGroupClose:)       rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnGroupMic = [self addGridBtn:@"给麦"     func:@selector(onBtnGroupUnMute:)       rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnGroupUnMic = [self addGridBtn:@"收麦"     func:@selector(onBtnGroupMute:)       rect:rect];
    
    rect = [self calcBtnRect:start index:totalIndex size:size linSep:sep colSep:xSep];
    totalIndex++;
    self.btnGroupDisplay = [self addGridBtn:@"分屏"     func:@selector(onBtnGroupDisplay:)       rect:rect];
    
    [btnGroupList setHidden:YES];
    [btnGroupInvite setHidden:YES];
    [btnGroupKick setHidden:YES];
    [btnGroupClose setHidden:YES];
    [btnGroupMic setHidden:YES];
    [btnGroupUnMic setHidden:YES];
    [btnGroupDisplay setHidden:YES];
#endif
    
    [btnMute setHidden:YES];
    [btnSpeaker setHidden:YES];
    [btnSwitchCamera setHidden:YES];
    [btnRemoteVideoRotate setHidden:YES];
    [btnSnapRemote setHidden:YES];
    [btnHideLocalVideo setHidden:YES];
    if (isCallOut)
    {
        [btnAccept setHidden:YES];
        [btnReject setHidden:YES];
    }
    else
    {
        [btnHangup setHidden:YES];
    }
    if (!isVideo)
    {
        [self.dapiview setHidden:YES];
    }
    mRotate = 0;
    mMotionManager = [[CMMotionManager alloc]init];
    mLogIndex = 0;
    mMuteState = NO;
    mHoldState = NO;
    
    [[UIApplication sharedApplication]setIdleTimerDisabled:YES];
    UITapGestureRecognizer *tapGr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)];
    tapGr.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGr];
    [tapGr release];
    
    [self performSelector:@selector(onSendVideoParam) withObject:nil afterDelay:0.1];//触发呼叫事件
    
}

-(void)viewTapped:(UITapGestureRecognizer*)tapGr
{
    [mStatus resignFirstResponder];
#if(SDK_HAS_GROUP>0)
    [mUser3 resignFirstResponder];
#endif
}

//- (void)viewDidDisappear:(BOOL)animated
//{
//    [super viewDidDisappear:animated];
//    if ([mCallDurationTimer isValid])
//    {
//        [mCallDurationTimer invalidate];
//        mCallDurationTimer = nil;
//    }
//}

//-(void)viewDidAppear:(BOOL)animated
//{
//    [super viewDidAppear:animated];
//    mCallDurationTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(onUpdateCallDuration:) userInfo:nil repeats:YES];
//}

//-(void)onUpdateCallDuration:(NSTimer*)timer
//{
//    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
//                            [NSNumber numberWithInt:MSG_UPDATE_CALLDURATION],@"msgid",
//                            [NSNumber numberWithInt:0],@"arg",
//                            nil];
//    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
//}

//可以实时获取通话时长以及设备状态
//-(void)setCallDuration:(unsigned int)callDuration  withCPU:(float)cpuUseage withMem:(float)memUse
//{
//    int sec = callDuration%60;
//    int temp = callDuration/60;
//    int min = temp%60;
//    temp = temp/60;
//    int hour = temp%60;
//    mDuration.text = [NSString stringWithFormat:@"时长:%02d:%02d:%02d",hour,min,sec];
//}
/**************************************控件响应*****************************************/
//挂断
-(IBAction)onBtnExit:(id)sender
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_HANGUP],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//发起呼叫
-(void)onSendVideoParam
{
    long long rVideo = 0;
    long long lVideo = 0;
    
    if (isVideo)
    {
        rVideo = (long long)(self.remoteVideoView);
        lVideo = (long long)(self.localVideoView);
    }
    
#if(SDK_HAS_GROUP>0)
    int myCallGroup = 0;
    if(isCallGroup == 0)//点对点
        myCallGroup = MSG_NEED_VIDEO;
    else if(isCallGroup == 1)//发起多人
        myCallGroup = MSG_GROUP_CREATE;
    else if(isCallGroup == 2)//加入多人
        myCallGroup = MSG_GROUP_JOIN;
#endif
    
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
#if(SDK_HAS_GROUP>0)
                            [NSNumber numberWithInt:isCallGroup],@"iscallgroup",
                            [NSNumber numberWithInt:myCallGroup],@"msgid",
#else
                            [NSNumber numberWithInt:MSG_NEED_VIDEO],@"msgid",
#endif
                            [NSNumber numberWithInt:0],@"arg",
                            [NSNumber numberWithLongLong:rVideo],@"rvideo",
                            [NSNumber numberWithLongLong:lVideo],@"lvideo",
                            [NSNumber numberWithBool:self.isCallOut],@"iscallout",
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//拒接
-(void)onBtnReject:(id)sender
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_REJECT],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            nil];
    
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//接听
-(void)onBtnAccept:(id)sender
{
    [self setLog:@"已接听"];
    [btnHangup setHidden:NO];
    [btnAccept setHidden:YES];
    [btnReject setHidden:YES];
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_ACCEPT],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            [NSNumber numberWithLongLong:(long long)(self.remoteVideoView)],@"rvideo",
                            [NSNumber numberWithLongLong:(long long)(self.localVideoView)],@"lvideo",
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//静音
- (IBAction)onMuteMic:(id)sender
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_MUTE],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            nil];
    [self setLog:mMuteState?@"解除静音":@"静音"];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
    mMuteState = !mMuteState;
}

//切换扬声器
- (IBAction)onSpeakerSwitch:(id)sender
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_SET_AUDIO_DEVICE],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//切换摄像头
-(IBAction)onBtnSwapCamera:(id)sender
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_SET_VIDEO_DEVICE],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            nil];
    [self setLog:@"摄像头切换"];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//隐藏视频
-(IBAction)onLocalVideoShow:(id)sender
{
    int val = 0;
    if (self.dapiview.hidden)
    {
        val = DO_SHOW_LOCAL_VIDEO;
    }
    else
    {
        val = DO_HIDE_LOCAL_VIDEO;
    }
    [self.dapiview setHidden:!self.dapiview.hidden];
    [self setLog:[NSString stringWithFormat:@"本地视频隐藏:%@",self.dapiview.hidden?@"开启":@"关闭"]];
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_HIDE_LOCAL_VIDEO],@"msgid",
                            [NSNumber numberWithInt:val],@"arg",
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//截取视频
-(IBAction)onSnap:(id)sender
{
    [self setLog:@"远端视频截屏"];
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_SNAP],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

-(IBAction)onRotateRemote:(id)sender
{
//    if (isVideo)
//    {
//        [self setLog:[NSString stringWithFormat:@"自动旋转适配:%@",isAutoRotate?@"开启":@"关闭"]];
//        [self setMotionStatus:isAutoRotate];
//        isAutoRotate = !isAutoRotate;
//    }
    
    mRotate += 1;
    if (mRotate > SDK_VIDEO_ROTATE_270)
        mRotate = SDK_VIDEO_ROTATE_0;
    [self setLog:[NSString stringWithFormat:@"旋转摄像头:%d",mRotate]];
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_ROTATE_REMOTE_VIDEO],@"msgid",
                            [NSNumber numberWithInt:mRotate],@"arg",
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

#if (SDK_HAS_GROUP>0)
//获取多人会话列表
-(IBAction)onBtnGroupList:(id)sender
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_GROUP_LIST],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//邀请加入多人会话
-(IBAction)onBtnGroupInvite:(id)sender
{
    NSString* remoteUri2 = mUser3.text;//账号之间用逗号隔开
    
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_GROUP_INVITE],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            remoteUri2,KEY_GRP_INVITEDMBLIST,
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//踢出多人会话成员
-(IBAction)onBtnGroupKick:(id)sender
{
    NSString* remoteUri2 = mUser3.text;//账号之间用逗号隔开
    
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_GROUP_KICK],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            remoteUri2,KEY_GRP_KICKEDMBLIST,
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//结束多人会话
-(IBAction)onBtnGroupClose:(id)sender
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_GROUP_CLOSE],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//给麦
-(IBAction)onBtnGroupUnMute:(id)sender
{
    NSString* remoteUri2 = mUser3.text;
    
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_GROUP_UNMUTE],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            remoteUri2,KEY_GRP_MEMBER,
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//收麦
-(IBAction)onBtnGroupMute:(id)sender
{
    NSString* remoteUri2 = mUser3.text;
    
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_GROUP_MUTE],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            remoteUri2,KEY_GRP_MEMBER,
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}

//多人画面分屏
-(IBAction)onBtnGroupDisplay:(id)sender
{
    NSString* remoteUri2 = mUser3.text;
    
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"params",
                            [NSNumber numberWithInt:MSG_GROUP_DISPLAY],@"msgid",
                            [NSNumber numberWithInt:0],@"arg",
                            remoteUri2,KEY_GRP_MEMBER,
                            nil];
    [[NSNotificationCenter defaultCenter]  postNotificationName:@"NOTIFY_EVENT" object:nil userInfo:params];
}
#endif

//接通
-(void)onCallOk:(BOOL)callOK
{
    if(callOK)
    {
        [btnMute setHidden:NO];
        [btnSpeaker setHidden:NO];
        if (isVideo)
        {
            [self.dapiview setHidden:NO];
            if (isAutoRotate)
            {
                [self setLog:[NSString stringWithFormat:@"自动旋转适配:%@",isAutoRotate?@"开启":@"关闭"]];
                [self setMotionStatus:YES];
                isAutoRotate = !isAutoRotate;
            }
            [btnSwitchCamera setHidden:NO];
            [btnRemoteVideoRotate setHidden:NO];
            [btnSnapRemote setHidden:NO];
            [btnHideLocalVideo setHidden:NO];
        }
        
    #if(SDK_HAS_GROUP>0)
        if(isGroupCreator==1)
        {
            [btnGroupClose setHidden:NO];
        }
        if(isCallGroup!=0)
        {
            [mUser3  setHidden:NO];
            [btnGroupList setHidden:NO];
            [btnGroupInvite setHidden:NO];
            [btnGroupKick setHidden:NO];
            [btnGroupDisplay setHidden:NO];
            if(grpType==1||grpType==21)
            {
                [btnGroupMic setHidden:NO];
                [btnGroupUnMic setHidden:NO];
            }
            else if(isGroupCreator&&(grpType==2||grpType==22))
            {
                [btnGroupMic setTitle:@"收麦" forState:UIControlStateNormal];
                [btnGroupUnMic setTitle:@"给麦" forState:UIControlStateNormal];
                [btnGroupMic setHidden:NO];
                [btnGroupUnMic setHidden:NO];
            }
            else
            {
                [btnGroupMic setHidden:YES];
                [btnGroupUnMic setHidden:YES];
            }
        }
        else
        {
            [mUser3  setHidden:YES];
            [btnGroupList setHidden:YES];
            [btnGroupInvite setHidden:YES];
            [btnGroupKick setHidden:YES];
            [btnGroupClose setHidden:YES];
            [btnGroupMic setHidden:YES];
            [btnGroupUnMic setHidden:YES];
            [btnGroupDisplay setHidden:YES];
        }
    #endif
    }
    else
        [self setMotionStatus:NO];
}

-(void)dealloc
{
    [self.localVideoView release];
    self.localVideoView = nil;
    
    [self.remoteVideoView release];
    self.remoteVideoView = nil;
    
    [self.dapiview release];
    [self.btnMute release];
    [self.btnSpeaker release];
    [self.mStatus release];
    [self.btnAccept release];
    [self.btnReject release];
    [self.btnHangup release];
    [self.lblCallStatus release];
    [self.btnSwitchCamera release];
    [self.btnRemoteVideoRotate release];
    [self.btnSnapRemote release];
    [self.btnHideLocalVideo release];
    
#if(SDK_HAS_GROUP>0)
    [self.btnGroupList release];
    [self.btnGroupInvite release];
    [self.btnGroupKick release];
    [self.btnGroupClose release];
    [self.btnGroupMic release];
    [self.btnGroupUnMic release];
    [self.btnGroupDisplay release];
    [self.mUser3 release];
#endif
    
    [mMotionManager stopDeviceMotionUpdates];
    [mMotionManager release];
    [super dealloc];
}

-(void)setCallStatus:(NSString*)log
{
    [self setLog:log];
}

+(NSInteger)calcRotation:(double)xy z:(double)z
{
    if ((z >= 45 && z <= 135) || (z >= -135 && z <= -45))//处于正向水平,反向水平位置,此时可作为竖直方向
    {
        return 0;
    }
    if (xy <= 180 && xy > 135)//竖直方向,向右侧倾斜,但未到角度
    {
        return 0;
    }
    if (xy <= 135 && xy >= 90)//竖直方向,向右倾斜,已经到位
    {
        return 90;
    }
    if (xy < 90 && xy >= 45) //斜向下方向,尚未到位
    {
        return 90;
    }
    if (xy < 45 && xy >= 0)//头朝下,已到位
    {
        return 180;
    }
    if (xy < 0 && xy >= -45)//头朝下,未到位
    {
        return 180;
    }
    if (xy < -45 && xy >= -90)//头朝下,已到位
    {
        return 270;
    }
    if (xy < -90 && xy >= -135)//头朝下,未到位
    {
        return 270;
    }
    if (xy < -135 && xy >= -180)//头朝上,偏左,已到位
    {
        return 0;
    }
    return 0;
}

-(void)setMotionStatus:(BOOL)doStart
{
    if (!doStart)
    {
        [mMotionManager stopDeviceMotionUpdates];
        [[NSNotificationCenter defaultCenter]postNotificationName:@"MOTIONCHECK_NOTIFY"
                                                           object:nil
                                                         userInfo:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSNumber numberWithInteger:0],@"rotation",
          nil]];
        
    }
    else
    {
        [mMotionManager startDeviceMotionUpdatesToQueue:[[[NSOperationQueue alloc] init] autorelease]
                                            withHandler:^(CMDeviceMotion *motion, NSError *error) {
                                                dispatch_sync(dispatch_get_main_queue(), ^(void) {
                                                    double gravityX = motion.gravity.x;
                                                    double gravityY = motion.gravity.y;
                                                    double gravityZ = motion.gravity.z;
                                                    double xyTheta = atan2(gravityX,gravityY)/M_PI*180.0;
                                                    double zTheta = atan2(gravityZ,sqrtf(gravityX*gravityX+gravityY*gravityY))/M_PI*180.0;
                                                    NSInteger rotation = [CCallingViewController calcRotation:xyTheta z:zTheta];
                                                    [[NSNotificationCenter defaultCenter]postNotificationName:@"MOTIONCHECK_NOTIFY"
                                                                                                       object:nil
                                                                                                     userInfo:
                                                     [NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithInteger:rotation],@"rotation",
                                                      nil]];
                                                    
                                                });
                                            }];
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
    [[NSUserDefaults standardUserDefaults]setObject:str forKey:[NSString stringWithFormat:@"CallLog%d",mLogIndex]];
    mLogIndex++;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
