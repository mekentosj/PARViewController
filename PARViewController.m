//  PARViewController
//  Author: Charles Parnot
//  Licensed under the terms of the BSD License, as specified in the file 'LICENSE-BSD.txt' included with this distribution

#import "PARViewController.h"
#import "PARObjectObserver.h"

// NSViewController base subclass that ensures automatic insertion into the responder chain
// this is achieved simply by doing KVO on the nextResponder value for the controlled view, encapsulated in the PARViewObserver helper class

@interface PARViewController()
@property (readwrite, retain) PARObjectObserver *nextResponderObserver;
@property (assign, nonatomic) BOOL viewWindowObservationEnabled;
@property (assign, nonatomic) BOOL par_isViewLoaded;
@end

@implementation PARViewController

@synthesize nextResponderObserver;

static void * PARViewControllerContext = &PARViewControllerContext;

- (void)dealloc
{
    // Remove self.view.window KVO
    [self removeViewWindowObservation];
    
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    self.nextResponderObserver = nil;
    #if ! __has_feature(objc_arc)
	[super dealloc];
    #endif
}

- (void)patchResponderChain
{
	// set the view controller in the middle of the responder chain
	// to avoid recursion and responder chain cycle, make sure the controller is not already the next responder of the view
	NSResponder *currentNextResponder = [[self view] nextResponder];
	if (currentNextResponder != nil && currentNextResponder != self)
	{
		[self setNextResponder:currentNextResponder];
		[[self view] setNextResponder:self];
	}
}

- (void)unpatchResponderChain
{
    NSResponder *parentResponder = [self view];
    
    NSAssert(self.view.nextResponder == self, @"Our view is not actually the parent responder.");
    
    // Remove the current view controller from the responder chain
    [parentResponder setNextResponder:[self nextResponder]];
}

#pragma mark - KVO

- (void)removeViewWindowObservation
{
    if (self.viewWindowObservationEnabled)
    {
        [self removeObserver:self forKeyPath:@"view.window"];
        self.viewWindowObservationEnabled = NO;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == PARViewControllerContext) {
        if (object == self && [keyPath isEqual:@"view.window"]) {
            self.nextResponderObserver = nil;
            [self removeViewWindowObservation];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)loadView
{
    [super loadView];
    self.par_isViewLoaded = YES;
}

- (void)setView:(NSView *)newView
{
    if (self.par_isViewLoaded && self.view == newView)
    {
        [super setView:newView];
        return;
    }
    
    // Remove self.view.window KVO
    [self removeViewWindowObservation];
    [super setView:newView];
    
	[self patchResponderChain];
	[self.nextResponderObserver invalidate];
	if (newView != nil)
    {
		self.nextResponderObserver = [PARObjectObserver observerWithDelegate:self selector:@selector(nextResponderDidChange) observedKeys:@[@"nextResponder"] observedObject:[self view]];
    }
    
    // Add self.view.window KVO
    [self addObserver:self
           forKeyPath:@"view.window"
              options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
              context:PARViewControllerContext];
    self.viewWindowObservationEnabled = YES;

	// optionally observe the view frame
	if ([self respondsToSelector:@selector(viewFrameDidChange)])
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:nil];
		if ([self view])
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewFrameDidChange:) name:NSViewFrameDidChangeNotification object:[self view]];
	}
}

- (void)nextResponderDidChange
{
	[self patchResponderChain];
}

//- (void)superviewDidChange
//{
//	NSLog(@"new superview : %@", [[self view] superview]);
//}

- (void)viewFrameDidChange:(NSNotification *)aNotification
{
	if ([self respondsToSelector:@selector(viewFrameDidChange)])
		[self viewFrameDidChange];
}

- (IBAction)endEditing:(id)sender
{
	NSWindow *window = [[self view] window];
	if (window != nil && [window isKeyWindow] == YES)
		[window makeFirstResponder:nil];
}

@end

