
#import "MyLoginModel.h"
#import "MyDatabase.h"
#import "sqlite3.h"

#import "MyLogin.h"

#import "AppDelegate.h"
#import "MySettings.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation MyLoginModel


@synthesize credentials = _credentials;


- (void)dealloc {
    TT_RELEASE_SAFELY(_credentials);
    [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark MyDatabaseRequestDelegate

- (void)login:(MyLogin *)settings {
	NSString* url = [settings.baseURL stringByAppendingString:@"/rest"];
    TTURLRequest *request = [TTURLRequest requestWithURL:url delegate:self];
	
    NSString *request_body = [NSString 
							  stringWithFormat:@"user=%@&password=%@",
							  [settings.username stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
							  [settings.password stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
							  ];
	//set request body into HTTPBody.
	request.httpBody = [request_body dataUsingEncoding:NSUTF8StringEncoding];
	
    request.httpMethod = @"POST";
    request.cachePolicy = TTURLRequestCachePolicyNone;
    //request.shouldHandleCookies = NO;
    
	request.contentType = @"application/x-www-form-urlencoded";
    
    id<TTURLResponse> response = [[TTURLDataResponse alloc] init];
    request.response = response;
    TT_RELEASE_SAFELY(response);    
    
    request.userInfo = settings;
    
    [request send];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark TTURLRequestDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)requestDidFinishLoad:(TTURLRequest*)request {
	TTURLDataResponse* dr = request.response;
	NSData* data = dr.data;

	MyLogin* login = request.userInfo;

	NSString* challenge = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	login.challenge = nil;
	login.challenge = [[challenge substringFromIndex: 1] substringToIndex:[challenge length] - 2];
	TT_RELEASE_SAFELY(challenge);
	
	// the model stores for all other controllers the credentials in singleton GlobalSettings
	[GlobalSettings save:login.baseURL withUsername:login.username withPassword:login.password withChallenge:login.challenge withImageQuality:login.imageQuality];

	// the model further saves credentials to the database:
	// this is for security only! should the app crash, 
	// then the GlobalSettings class will automatically restore data from the database
	// the overall datastorage should be switched to core-data with a proper schema later on!
	[self store:login];
	
	// notify the controller that we are done
	[super didUpdateObject:login atIndexPath:nil];
}

-(void) store:(MyLogin *)login {
	NSString *filePath = [MyDatabase copyDatabaseToDocuments];

	sqlite3 *database;
	
	if(sqlite3_open([filePath UTF8String], &database) == SQLITE_OK) {
	
		//delete everything	
		const char *deleteStatement = "delete from settings";
		sqlite3_stmt *compiledStatement;
		//baseURL
		sqlite3_prepare_v2(database, deleteStatement, -1, &compiledStatement, NULL);
		if(sqlite3_step(compiledStatement) == SQLITE_DONE) {
			sqlite3_finalize(compiledStatement);
		}
		
		//insert
		const char *sqlStatement = "insert into settings (var, value) VALUES (?, ?);";
		//baseURL
		if(sqlite3_prepare_v2(database, sqlStatement, -1, &compiledStatement, NULL) == SQLITE_OK) {
		    sqlite3_bind_text( compiledStatement, 1, [@"baseURL" UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text( compiledStatement, 2, [login.baseURL UTF8String], -1, SQLITE_TRANSIENT);	
		}
		if(sqlite3_step(compiledStatement) == SQLITE_DONE) {
	       	sqlite3_finalize(compiledStatement);
		}
		//username
		if(sqlite3_prepare_v2(database, sqlStatement, -1, &compiledStatement, NULL) == SQLITE_OK) {
		    sqlite3_bind_text( compiledStatement, 1, [@"username" UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text( compiledStatement, 2, [login.username UTF8String], -1, SQLITE_TRANSIENT);	
		}
		if(sqlite3_step(compiledStatement) == SQLITE_DONE) {
	       	sqlite3_finalize(compiledStatement);
		}
		//password
		if(sqlite3_prepare_v2(database, sqlStatement, -1, &compiledStatement, NULL) == SQLITE_OK) {
		    sqlite3_bind_text( compiledStatement, 1, [@"password" UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text( compiledStatement, 2, [login.password UTF8String], -1, SQLITE_TRANSIENT);	
		}
		if(sqlite3_step(compiledStatement) == SQLITE_DONE) {
	       	sqlite3_finalize(compiledStatement);
		}
		//challenge
		if(sqlite3_prepare_v2(database, sqlStatement, -1, &compiledStatement, NULL) == SQLITE_OK) {
		    sqlite3_bind_text( compiledStatement, 1, [@"challenge" UTF8String], -1, SQLITE_TRANSIENT);
			sqlite3_bind_text( compiledStatement, 2, [login.challenge UTF8String], -1, SQLITE_TRANSIENT);	
		}
		if(sqlite3_step(compiledStatement) == SQLITE_DONE) {
	       	sqlite3_finalize(compiledStatement);
		}
	}
	sqlite3_close(database);
}

- (void)request:(TTURLRequest *)request didFailLoadWithError:(NSError *)error {
	[super didFailLoadWithError:nil];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark TTModel

/////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)isLoaded {
    return YES;
}

- (BOOL)isLoading {
	return YES;
}


@end
