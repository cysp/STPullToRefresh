//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2013 Scott Talbot. All rights reserved.

#import <UIKit/UIKit.h>


typedef enum STPullToRefreshDirection {
    STPullToRefreshDirectionUp = 0,
} STPullToRefreshDirection;

typedef enum STPullToRefreshState {
    STPullToRefreshStateIdle = 0,
    STPullToRefreshStateWaitingForRelease,
    STPullToRefreshStateLoading,
    STPullToRefreshStateLoaded,
} STPullToRefreshState;


@class STPullToRefreshHelper;

@protocol STPullToRefreshHelperDelegate <NSObject>
@optional
- (void)pullToRefreshHelperDidTriggerLoad:(STPullToRefreshHelper *)helper;
@end


@protocol STPullToRefreshHelperView <NSObject>
+ (CGFloat)naturalHeight;
- (void)setState:(STPullToRefreshState)state animated:(BOOL)animated;
@optional
- (void)setTriggerPrimingProgress:(CGFloat)progress;
@end

@interface STPullToRefreshHelperView : UIView<STPullToRefreshHelperView>
- (void)setState:(STPullToRefreshState)state animated:(BOOL)animated;
@end


@interface STPullToRefreshHelper : NSObject

- (id)initWithDirection:(STPullToRefreshDirection)direction delegate:(id<STPullToRefreshHelperDelegate>)delegate;
- (id)initWithDirection:(STPullToRefreshDirection)direction viewClass:(Class)viewClass delegate:(id<STPullToRefreshHelperDelegate>)delegate;

@property (nonatomic) CGFloat triggerDistance;
@property (nonatomic,unsafe_unretained) UIScrollView *scrollView;
@property (nonatomic,strong,readonly) UIView<STPullToRefreshHelperView> *view;

- (void)setStateLoadingAnimated:(BOOL)animated;

- (void)didFinishLoading;

@end
