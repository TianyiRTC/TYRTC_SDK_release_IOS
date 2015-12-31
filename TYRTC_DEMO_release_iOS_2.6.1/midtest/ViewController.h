#import <UIKit/UIKit.h>
#import "sdkobj.h"
#import "tyrtchttpengine.h"
#import "MKNetworkOperationRTC.h"
#import "CCallingViewController.h"

@interface ViewController : UIViewController<SdkObjCallBackProtocol,AccObjCallBackProtocol,CallObjCallBackProtocol,UIActionSheetDelegate>//必须声明回调协议，在主线程实现回调函数

@property (nonatomic, retain) IBOutlet UITextField*           mStatus;
@property (nonatomic, retain) IBOutlet UITextField*           mUser1;
@property (nonatomic, retain) IBOutlet UITextField*           mUser2;


-(void)setLog:(NSString*)log;
-(CGRect)calcBtnRect:(CGPoint)start index:(int)index size:(CGSize)size linSep:(int)lineSep colSep:(int)colSep;
-(BOOL)addGridBtn:(NSString*)title  func:(SEL)func rect:(CGRect)rect;
- (void)onApplicationWillEnterForeground:(UIApplication *)application;
-(void)onAppEnterBackground;
-(void)onNetworkChanged:(BOOL)netstatus;
-(BOOL)accObjIsRegisted;
@end
