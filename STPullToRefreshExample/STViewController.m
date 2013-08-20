//  Copyright (c) 2013 Scott Talbot. All rights reserved.

#import "STViewController.h"
#import "STPullToRefreshHelper.h"


@interface STViewController () <STPullToRefreshHelperDelegate>
@property (nonatomic,strong) UIScrollView *scrollView;
@property (nonatomic,strong,readonly) STPullToRefreshHelper *pulltorefreshHelper;
@end

@implementation STViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        _pulltorefreshHelper = [[STPullToRefreshHelper alloc] initWithDirection:STPullToRefreshDirectionUp delegate:self];

        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    }
    return self;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:(CGRect){ .size = { .width = 320, .height = 480 }}];
    UIView * const view = self.view;

    UIScrollView * const scrollView = _scrollView = [[UITableView alloc] initWithFrame:view.bounds style:UITableViewStylePlain];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [view addSubview:scrollView];

    scrollView.alwaysBounceVertical = YES;
    scrollView.contentSize = scrollView.bounds.size;
    scrollView.bounces = YES;

    UIView * const bleh = [[UIView alloc] initWithFrame:(CGRect){ .size = { .width = 100, .height = 100 } }];
    bleh.backgroundColor = [UIColor blueColor];
    [scrollView addSubview:bleh];

    view.backgroundColor = [UIColor whiteColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    UIScrollView * const scrollView = self.scrollView;

    STPullToRefreshHelper * const pulltorefreshHelper = self.pulltorefreshHelper;
    pulltorefreshHelper.scrollView = scrollView;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIScrollView * const scrollView = self.scrollView;
    scrollView.contentSize = scrollView.bounds.size;
}

#pragma mark - STPullToRefreshHelperDelegate

- (void)pullToRefreshHelperDidTriggerLoad:(STPullToRefreshHelper *)helper {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        [helper didFinishLoading];
    });
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"foo");
}

@end
