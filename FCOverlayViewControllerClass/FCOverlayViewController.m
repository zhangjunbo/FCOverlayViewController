//
//  FCOverlayViewController.m
//
//  Created by Almer Lucke on 10/11/13.
//  Copyright (c) 2013 Farcoding. All rights reserved.
//


#import "FCOverlayViewController.h"
#import "FCOverlay.h"


// private interface
@interface FCOverlayViewController ()
@property (nonatomic, strong) UIWindow *currentWindow;
@property (nonatomic, strong) UIViewController *viewControllerToPresent;
@property (nonatomic) BOOL showAnimated;
@property (nonatomic, copy) void (^completionBlock)();
@property (nonatomic) BOOL queued;
@end


@implementation FCOverlayViewController

#pragma mark - Initialize, Appearance and Loading

- (instancetype)initWithWindow:(UIWindow *)window
                viewController:(UIViewController *)viewController
                      animated:(BOOL)animated
                        queued:(BOOL)queued
                    completion:(void (^)(void))completion {
    if ((self = [super init])) {
        self.currentWindow = window;
        self.viewControllerToPresent = viewController;
        self.showAnimated = animated;
        self.completionBlock = completion;
        self.queued = queued;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
}

// Do the actual presentation from viewDidAppear to make sure we don't get any complaints about
// view transitions in progress etc.
// This is the right way to present any view controller immediately from another view controller
// (viewDidLoad and viewWillAppear are NOT the methods you want to do this from)
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.viewControllerToPresent) {
        // present the view controller
        [self presentViewController:self.viewControllerToPresent
                           animated:self.showAnimated
                         completion:self.completionBlock];
        
        // make sure we never present the view controller again (for example after it is dismissed)
        self.viewControllerToPresent = nil;
    }
}


#pragma mark - Auto Rotation

- (BOOL)shouldAutorotate
{
    // forward call to presented view controller
    return [self.presentedViewController shouldAutorotate];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    // forward call to presented view controller
    return [self.presentedViewController shouldAutorotateToInterfaceOrientation:toInterfaceOrientation];
}

- (NSUInteger)supportedInterfaceOrientations
{
    // forward call to presented view controller
    return [self.presentedViewController supportedInterfaceOrientations];
}


#pragma mark - Show/Hide Overlay

// Overwrite dismissViewControllerAnimated to be able to close the current window and
// make the next window in line the top window. View controllers that are overlayed should call
// [self.presentingViewController dismissViewControllerAnimated:flag completion:completion] to
// dismiss the overlay controller and corresponding window
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    [super dismissViewControllerAnimated:flag completion:^{
        NSArray *windows = [UIApplication sharedApplication].windows;
        NSEnumerator *reverseEnumerator = [windows reverseObjectEnumerator];
        NSInteger topIndex = [windows count] - 1;
        NSInteger index = topIndex;
        
        // get current key window
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        
        // if we are the key window, find the next window in the hierarchy that
        // should be made key
        if (self.currentWindow == keyWindow) {
            for (UIWindow *window in reverseEnumerator) {
                if (window.rootViewController == self) {
                    break;
                } else {
                    --index;
                }
            }
            
            if (index == topIndex) {
                // we are the top level window, get the one below us to make key
                keyWindow = [windows objectAtIndex:index - 1];
            } else {
                // we are not the top level window, get the top level window to make key
                keyWindow = [windows objectAtIndex:topIndex];
            }
        }
        
        // set window level to normal, this is needed to restore activity for
        // any _UIModalItemHostingWindow that are below us in the window hierarchy
        self.currentWindow.windowLevel = UIWindowLevelNormal;
        
        // restore key window
        [keyWindow makeKeyAndVisible];
        
        // break retain cycle by setting ptr's to nil
        self.currentWindow.rootViewController = nil;
        
        if (self.queued) {
            // dequeue the next queued overlay
            [FCOverlay dequeue];
        }
        
        // call completion block
        if (completion) completion();
    }];
}



@end
