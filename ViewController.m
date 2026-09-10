//
//  BadKernelTestViewController.m
//  BadKernelTest
//

#import "BadKernelTestViewController.h"

@implementation BadKernelTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.isReady = NO;
    self.kernelBase = 0;
    [self setupUI];
    [self log:@"BadKernel Test App loaded"];
    [self log:@"Target: iOS 27.0 Beta 4 on A15"];
    [self log:@"Using libBadKernel.a"];
}

- (void)setupUI {
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    // Log view
    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, width - 20, height - 200)];
    self.logView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    self.logView.textColor = [UIColor greenColor];
    self.logView.font = [UIFont fontWithName:@"Menlo" size:12];
    self.logView.editable = NO;
    self.logView.layer.cornerRadius = 8;
    self.logView.layer.borderColor = [UIColor grayColor].CGColor;
    self.logView.layer.borderWidth = 1;
    [self.view addSubview:self.logView];

    // Run button
    self.runButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.runButton.frame = CGRectMake(10, height - 150, width - 20, 50);
    [self.runButton setTitle:@"Run BadKernel Init" forState:UIControlStateNormal];
    [self.runButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.runButton.backgroundColor = [UIColor greenColor];
    self.runButton.layer.cornerRadius = 10;
    [self.runButton addTarget:self action:@selector(runExploit) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.runButton];

    // Read button
    self.readButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.readButton.frame = CGRectMake(10, height - 90, (width - 30) / 2, 40);
    [self.readButton setTitle:@"Read Kernel" forState:UIControlStateNormal];
    [self.readButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.readButton.backgroundColor = [UIColor blueColor];
    self.readButton.layer.cornerRadius = 8;
    self.readButton.enabled = NO;
    self.readButton.alpha = 0.5;
    [self.readButton addTarget:self action:@selector(readKernel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.readButton];

    // Write button
    self.writeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.writeButton.frame = CGRectMake((width - 30) / 2 + 20, height - 90, (width - 30) / 2, 40);
    [self.writeButton setTitle:@"Write Kernel" forState:UIControlStateNormal];
    [self.writeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.writeButton.backgroundColor = [UIColor redColor];
    self.writeButton.layer.cornerRadius = 8;
    self.writeButton.enabled = NO;
    self.writeButton.alpha = 0.5;
    [self.writeButton addTarget:self action:@selector(writeKernel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.writeButton];
}

- (void)log:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                             dateStyle:NSDateFormatterNoStyle
                                                             timeStyle:NSDateFormatterMediumStyle];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
        self.logView.text = [self.logView.text stringByAppendingString:line];
        NSRange range = NSMakeRange(self.logView.text.length - 1, 1);
        [self.logView scrollRangeToVisible:range];
    });
}

- (void)runExploit {
    self.runButton.enabled = NO;
    self.runButton.alpha = 0.5;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self log:@"Starting BadKernelInit()..."];
        int result = BadKernelInit();
        [self log:[NSString stringWithFormat:@"BadKernelInit returned: %d", result]];

        if (result == 0 && BadKernelIsReady()) {
            self.isReady = YES;
            self.kernelBase = BadKernelGetBase();
            uint64_t slide = BadKernelGetSlide();
            [self log:[NSString stringWithFormat:@"✅ Kernel base: 0x%016llx", self.kernelBase]];
            [self log:[NSString stringWithFormat:@"✅ Kernel slide: 0x%016llx", slide]];

            // Test read
            uint64_t val = BadKernelKRead64(self.kernelBase + 0x1000);
            [self log:[NSString stringWithFormat:@"📖 Read at base+0x1000: 0x%016llx", val]];

            // Test write
            uint64_t testAddr = self.kernelBase + 0x2000;
            uint64_t original = BadKernelKRead64(testAddr);
            int wret = BadKernelKWrite64(testAddr, 0xdeadbeefcafebabe);
            uint64_t modified = BadKernelKRead64(testAddr);
            BadKernelKWrite64(testAddr, original); // restore
            [self log:[NSString stringWithFormat:@"✏️ Write returned: %d, modified: 0x%016llx", wret, modified]];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.readButton.enabled = YES;
                self.readButton.alpha = 1.0;
                self.writeButton.enabled = YES;
                self.writeButton.alpha = 1.0;
            });
        } else {
            [self log:@"❌ BadKernel initialization failed or not ready"];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.runButton.enabled = YES;
            self.runButton.alpha = 1.0;
        });
    });
}

- (void)readKernel {
    if (!self.isReady) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Read Kernel"
                                                                   message:@"Enter address (hex)"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"0xfffffff007004000";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Read" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *addrStr = alert.textFields.firstObject.text;
        uint64_t addr = 0;
        if ([addrStr hasPrefix:@"0x"]) {
            [[NSScanner scannerWithString:addrStr] scanHexLongLong:&addr];
        } else {
            addr = [addrStr longLongValue];
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            uint64_t val = BadKernelKRead64(addr);
            [self log:[NSString stringWithFormat:@"📖 Read 0x%016llx -> 0x%016llx", addr, val]];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)writeKernel {
    if (!self.isReady) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Write Kernel"
                                                                   message:@"Enter address and value (hex)"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Address (0x...)";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Value (0x...)";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Write" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *addrStr = alert.textFields[0].text;
        NSString *valStr = alert.textFields[1].text;
        uint64_t addr = 0, value = 0;
        if ([addrStr hasPrefix:@"0x"]) {
            [[NSScanner scannerWithString:addrStr] scanHexLongLong:&addr];
        } else {
            addr = [addrStr longLongValue];
        }
        if ([valStr hasPrefix:@"0x"]) {
            [[NSScanner scannerWithString:valStr] scanHexLongLong:&value];
        } else {
            value = [valStr longLongValue];
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            int ret = BadKernelKWrite64(addr, value);
            [self log:[NSString stringWithFormat:@"✏️ Write 0x%016llx -> 0x%016llx returned %d", addr, value, ret]];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
