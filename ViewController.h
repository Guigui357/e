//
//  BadKernelTestViewController.h
//  BadKernelTest
//

#import <UIKit/UIKit.h>
#import "BadKernel.h"

@interface BadKernelTestViewController : UIViewController

@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIButton *runButton;
@property (nonatomic, strong) UIButton *readButton;
@property (nonatomic, strong) UIButton *writeButton;
@property (nonatomic, assign) BOOL isReady;
@property (nonatomic, assign) uint64_t kernelBase;

@end
