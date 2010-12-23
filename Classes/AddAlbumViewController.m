//
//  AddAlbumViewController.m
//  Gallery3
//
//  Created by David Steinberger on 12/20/10.
//  Copyright 2010 -. All rights reserved.
//

#import "NSObject+YAJL.h"

#import "AppDelegate.h"
#import "MyImageUploader.h"

#import "AddAlbumViewController.h"


@implementation AddAlbumViewController

@synthesize albumID = _albumID;
@synthesize delegate = _delegate;

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		self.title = @"Add Album";
		self.navigationItem.backBarButtonItem =
		[[[UIBarButtonItem alloc] initWithTitle:@"Album" style:UIBarButtonItemStyleBordered
										 target:nil action:nil] autorelease];
		
		self.tableViewStyle = UITableViewStyleGrouped;
	}
	return self;
}

- (id)initWithAlbumID: (NSString* )albumID delegate: (MyThumbsViewController *)delegate {
	self.albumID = albumID;
	self.delegate = delegate;

	return [self initWithNibName:nil bundle: nil];
}

- (void)dealloc {
	[super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// TTModelViewController

- (void)createModel {
	_albumName = [[UITextField alloc] init];
	_albumName.placeholder = @"Name";
	_albumName.delegate = self;
	_albumName.text = @"Name";
	_albumName.returnKeyType = UIReturnKeyNext;

	_albumTitle = [[UITextField alloc] init];
	_albumTitle.placeholder = @"Title";
	_albumTitle.delegate = self;
	_albumTitle.text = @"Title";
	
	self.dataSource = [TTSectionedDataSource dataSourceWithObjects:
					   @"",
					   _albumName,
					   _albumTitle,
					   nil];	
	[_albumName becomeFirstResponder];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITextFieldDelegate methods


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.returnKeyType == UIReturnKeyNext) {
		[_albumTitle becomeFirstResponder];
    }
    else {
		[_albumTitle resignFirstResponder];
		//NSLog(@"add Album!");
		
		[self addAlbum];
    }
    return YES;
}

#pragma mark -
#pragma mark helpers

- (void)addAlbum {
	//NSLog(@"Add Album for albumID: %@", self.albumID);
	AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	//prepare http post parameter: item, text
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:    
							@"album", @"type",
							_albumName.text, @"name",
							_albumTitle.text, @"title",
							nil];  
	
	//json-encode & urlencode parameters
	NSString* requestString = [params yajl_JSONString];
	requestString = [@"entity=" stringByAppendingString:[self urlEncodeValue:requestString]];
	
	//create data for http-request body
	NSData *requestData = [NSData dataWithBytes: [requestString UTF8String] length: [requestString length]];
	
	//---bring everything together
	
	//create http-request
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:[[appDelegate.baseURL stringByAppendingString:@"/rest/item/"] stringByAppendingString:self.albumID]]];
	
	//set http-headers
	[request setValue:appDelegate.challenge forHTTPHeaderField:@"X-Gallery-Request-Key"];
	[request setValue:@"post" forHTTPHeaderField:@"X-Gallery-Request-Method"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];	
	
	//set 'post'-method
	[request setHTTPMethod: @"POST"];
	
	//set request body into HTTPBody.
	[request setHTTPBody: requestData];
	
	NSData *returnData = [NSURLConnection sendSynchronousRequest: request returningResponse: nil error: nil ];
	
	NSDictionary *arrayFromData = [returnData yajl_JSON];
	NSString* url = [arrayFromData objectForKey:@"url"];
	NSArray* chunks = [url componentsSeparatedByString: @"/"];
	NSString* newAlbumID = [chunks objectAtIndex:[chunks count] - 1 ];
	
	[request release];
	NSLog(@"returnString: %@", [chunks objectAtIndex:[chunks count] - 1 ]);
	MyImageUploader* uploader = [[MyImageUploader alloc] initWithAlbumID:[[[NSString alloc] initWithString:newAlbumID] autorelease] delegate:nil];
	[uploader uploadImage:nil];
	TT_RELEASE_SAFELY(uploader);
	
	[[TTURLCache sharedCache] removeURL:[[appDelegate.baseURL stringByAppendingString: @"/rest/item/"] stringByAppendingString:self.albumID] fromDisk:YES];
	
	[self.delegate loadAlbum:self.albumID];
	
	TTNavigator* navigator = [TTNavigator navigator];
	[navigator reload];
	
	[self.navigationController popViewControllerAnimated:YES];
}

- (NSString *)urlEncodeValue:(NSString *)str
{
	NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)str, NULL, CFSTR("?=&+"), kCFStringEncodingUTF8);
	return [result autorelease];
}

@end
