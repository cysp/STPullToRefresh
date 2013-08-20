//  Copyright (c) 2013 Scott Talbot. All rights reserved.

#import <UIKit/UIKit.h>


typedef enum STPullToRefreshDirection {
    STPullToRefreshDirectionUp = 0,
    STPullToRefreshDirectionDown,
} STPullToRefreshDirection;


@class STPullToRefreshHelper;

@protocol STPullToRefreshHelperDelegate <NSObject>
@optional
- (void)pullToRefreshHelperDidTriggerLoad:(STPullToRefreshHelper *)helper;
@end


@interface STPullToRefreshHelper : NSObject

- (id)initWithDirection:(STPullToRefreshDirection)direction delegate:(id<STPullToRefreshHelperDelegate>)delegate;

@property (nonatomic,unsafe_unretained) UIScrollView *scrollView;

- (void)didFinishLoading;

@end