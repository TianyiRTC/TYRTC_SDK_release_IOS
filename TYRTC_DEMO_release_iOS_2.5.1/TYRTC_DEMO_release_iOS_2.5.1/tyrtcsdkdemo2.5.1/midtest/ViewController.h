#import <UIKit/UIKit.h>
#import "sdkobj.h"
#import "CCallingViewController.h"
#import "tyrtchttpengine.h"
#import "MKNetworkOperation.h"

@interface ViewController : UIViewController<SdkObjCallBackProtocol,AccObjCallBackProtocol,CallObjCallBackProtocol,UIActionSheetDelegate>

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
