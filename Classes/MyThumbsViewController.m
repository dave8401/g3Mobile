
#import "AppDelegate.h"
#import "MyThumbsViewController.h"
#import "PhotoSource.h"
#import "MyAlbum.h"

#import "MyImageUploader.h"
#import "MyItemDeleter.h"
#import "AddAlbumViewController.h"
#import "UpdateAlbumViewController.h"

#import "UIImage+cropping.h"
#import "MyUploadViewController.h"
#import "Three20UI/TTPhotoSource.h"
#import "MyViewController.h"
#import "Three20UICommon/UIViewControllerAdditions.h"

@interface MyThumbsViewController ()

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated;

@end

@implementation MyThumbsViewController

@synthesize albumID = _albumID;

- (void)dealloc {
    [[RKRequestQueue sharedQueue] cancelAllRequests];
	self.albumID = nil;
	TT_RELEASE_SAFELY(_photoSource);
	TT_RELEASE_SAFELY(self->_toolbar);
	TT_RELEASE_SAFELY(self->_clickActionItem);
	TT_RELEASE_SAFELY(self->_pickerController);

	[super dealloc];
}

- (id)initWithAlbumID:(NSString *)albumID {
	if ((self = [super init])) {
		self.albumID = albumID;
		PhotoSource* photosource = [[PhotoSource alloc] initWithItemID:albumID];
		self.photoSource = photosource;
		TT_RELEASE_SAFELY(photosource);
	}
	return self;
}

- (void)modelDidFinishLoad:(id <TTModel>)model {
	self.title = self.photoSource.title;

    self.photoSource = ((id<TTPhotoSource>)model);
	[super modelDidFinishLoad:model];
    
    [self invalidateView];
    [self refresh];
    [self reloadIfNeeded];
}

// Shows the Login page with all the settings
- (void)setSettings {
	TTNavigator* navigator = [TTNavigator navigator];
	[navigator openURLAction:[[TTURLAction actionWithURLPath:@"tt://login"] applyAnimated:YES]];
}

- (NSString *)urlEncodeValue:(NSString *)str
{
	NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)str, NULL, CFSTR("?=&+"), kCFStringEncodingUTF8);
	return [result autorelease];
}

- (void)addAlbum {	
	AddAlbumViewController* addAlbum = [[AddAlbumViewController alloc] initWithParentAlbumID: self.albumID];
	[self.navigationController pushViewController:addAlbum animated:YES];
	TT_RELEASE_SAFELY(addAlbum);
}

- (void)updateAlbum {
	PhotoSource* ps = (PhotoSource* ) self.photoSource;
	if (![ps.albumID isEqualToString: @"1"]) {
		UpdateAlbumViewController* updateAlbum = [[UpdateAlbumViewController alloc] initWithAlbumID: self.albumID];
		[self.navigationController pushViewController:updateAlbum animated:YES];	
		TT_RELEASE_SAFELY(updateAlbum);
	}
}

- (void)viewDidLoad {
	[super viewDidLoad];
		
	PhotoSource* ps = (PhotoSource* ) self.photoSource;
	
	//show logout only when on root-album
	if ([ps.albumID isEqualToString: @"1"]) {
		self.navigationItem.rightBarButtonItem
		= [[[UIBarButtonItem alloc] initWithTitle:@"Settings" style:UIBarButtonItemStyleBordered
										   target:self action:@selector(setSettings)] autorelease];	
		
	}
	
	_clickActionItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction//TTIMAGE(@"UIBarButtonReply.png")
																	 target:self action:@selector(clickActionItem)];
	_toolbar = [[UIToolbar alloc] initWithFrame:
				CGRectMake(0, self.view.height - TT_ROW_HEIGHT,
						   self.view.width, TT_ROW_HEIGHT)];
	
	UIBarItem* space = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:
						 UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease];
	
	if (self.navigationBarStyle == UIBarStyleDefault) {
		_toolbar.tintColor = TTSTYLEVAR(toolbarTintColor);
	}
	
	_toolbar.barStyle = self.navigationBarStyle;
	_toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin;
	_toolbar.items = [NSArray arrayWithObjects:
					  _clickActionItem, space, nil];
	
	[self.view addSubview:_toolbar];
	
	_pickerController = [[UIImagePickerController alloc] init];
	_pickerController.delegate = self;
	if ( [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront] == YES) {
		_pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
	} else {
		_pickerController.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
	}
}

- (void) clickActionItem {
	UIActionSheet *actionSheet = [[[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:nil
											   destructiveButtonTitle:nil
													otherButtonTitles:nil] autorelease];
	
	actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	
	[actionSheet addButtonWithTitle:@"Upload"];
	[actionSheet addButtonWithTitle:@"Add Album"];
	[actionSheet addButtonWithTitle:@"Change Album"];
	[actionSheet addButtonWithTitle:@"Delete"];
	[actionSheet addButtonWithTitle:@"Cancel"];
	actionSheet.cancelButtonIndex = 4;
	actionSheet.destructiveButtonIndex = 3; 
	
    [actionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
		
	//NSLog(@"[actionSheet clickedButtonAtIndex] ... (button: %i)", buttonIndex);
	
	if (buttonIndex == 0) {
		[self presentModalViewController:_pickerController animated:YES];		
		
	}	
	if (buttonIndex == 1) {
		[self addAlbum];
	}
	if (buttonIndex == 2) {
		[self updateAlbum];
	}
	if (buttonIndex == 3) {
		UIAlertView *dialog = [[[UIAlertView alloc] init] autorelease];
		[dialog setDelegate:self];
		[dialog setTitle:@"Confirm Deletion"];
		[dialog addButtonWithTitle:@"Cancel"];
		[dialog addButtonWithTitle:@"OK"];
		[dialog show];		
	}
}

- (void)modalView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([alertView isKindOfClass:[UIAlertView class]]) {
		if (buttonIndex == 1) {
			// start the indicator ...
			[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
			[self performSelector:@selector(deleteCurrentItem) withObject:Nil afterDelay:0.05];
		}
	}
}

- (void)deleteCurrentItem {
	PhotoSource* ps = (PhotoSource* ) self.photoSource;
	[MyItemDeleter initWithItemID:ps.albumID];
	
	//TTNavigator* navigator = [TTNavigator navigator];
	//[navigator removeAllViewControllers];
	//[navigator openURLAction:[[TTURLAction actionWithURLPath:@"tt://thumbs/1"] applyAnimated:YES]];
	
	// stop the indicator ...
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

    [((id<MyViewController>)self) reloadViewController:YES];
}

#pragma mark UIImagePickerController Methods

- (void)uploadImage:(id)sender {
	[self presentModalViewController:_pickerController animated:YES];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	PhotoSource* ps;
	ps = (PhotoSource* ) self.photoSource;
	
	// get high-resolution picture (used for upload)
	UIImage* image = [info objectForKey:@"UIImagePickerControllerOriginalImage"];

	// get screenshot (used for confirmation-dialog)
	UIWindow *theScreen = [[UIApplication sharedApplication].windows objectAtIndex:0];
	UIGraphicsBeginImageContext(theScreen.frame.size);
	[[theScreen layer] renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	screenshot = [UIImage imageByCropping:screenshot
								toRect:CGRectMake(0, 0, 320, 426)];
	
	// prepare params
	NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
							self, @"delegate",
							image, @"image",
							screenshot, @"screenShot",
							ps.albumID, @"albumID",
							nil];
	
	[[TTNavigator navigator] openURLAction:[[[TTURLAction actionWithURLPath:@"tt://nib/MyUploadViewController"]
											applyQuery:params] applyAnimated:YES]];
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissModalViewControllerAnimated:YES];
}


#pragma mark UINavigationController Methods
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
	
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
	
}

// Reloads the data -> resets the detail-view
- (void)reload {
	[super reload];
}

// Reloads after an action was taken
- (void)reloadViewController:(BOOL)goBack {
    self->_goBack = goBack;
    
    [((PhotoSource*)self.photoSource) load:TTURLRequestCachePolicyDefault more:NO];
    //[((PhotoSource*)self.photoSource) invalidate:YES];
    
    [NSTimer scheduledTimerWithTimeInterval:2 target:self  
                                   selector:@selector(finishUp) userInfo:nil repeats:NO];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)finishUp {
    PhotoSource* photosource = [[PhotoSource alloc] initWithItemID:self.albumID];
    self.photoSource = photosource;
    TT_RELEASE_SAFELY(photosource);
    [self reload];
    [((MyThumbsViewController*)self.ttPreviousViewController) invalidateView];
    
    NSArray *viewControllers = [self.navigationController viewControllers];
    TTViewController* viewController;
    if ([viewControllers count] > 1 && self->_goBack) {
        viewController = [viewControllers objectAtIndex:[viewControllers count] - 2];
        [self.navigationController popToViewController:viewController animated:YES];
        [(TTNavigator*)[TTNavigator navigator] performSelector:@selector(reload) withObject:nil afterDelay:1];
	}
}


@end
