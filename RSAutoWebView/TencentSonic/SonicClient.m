#import "SonicClient.h"
#import "SonicCache.h"
#import "SonicUitil.h"

@interface SonicClient ()

@property (nonatomic,retain)NSRecursiveLock *lock;
@property (nonatomic,retain)NSMutableDictionary *tasks;
@property (nonatomic,retain)NSMutableDictionary *ipDomains;
@property (nonatomic,copy)NSString *userAgent;

@end

@implementation SonicClient

+ (SonicClient *)sharedClient
{
    static SonicClient *_client = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _client = [[self alloc]init];
    });
    return _client;
}

- (instancetype)init
{
    if (self = [super init]) {
        [self setupClient];
    }
    return self;
}

- (void)setGlobalUserAgent:(NSString *)aUserAgent
{
    if (aUserAgent.length == 0) {
        return;
    }
    if (_userAgent) {
        _userAgent = nil;
    }
    _userAgent = [aUserAgent copy];
}

- (void)setCurrentUserUniqIdentifier:(NSString *)userIdentifier
{
    if (userIdentifier.length == 0 || [_currentUserUniq isEqualToString:userIdentifier]) {
        return;
    }
    if (_currentUserUniq) {
        _currentUserUniq = nil;
    }
    _currentUserUniq = [userIdentifier copy];
    
    //create root cache path by user id
    [[SonicCache shareCache] setupCacheDirectory];
}

- (NSString *)sonicDefaultUserAgent
{
    return SonicDefaultUserAgent;
}

- (void)addDomain:(NSString *)domain withIpAddress:(NSString *)ipAddress
{
    if (domain.length == 0 || ipAddress.length == 0) {
        return;
    }
    [self.ipDomains setObject:ipAddress forKey:domain];
}

- (void)setupClient
{
    self.lock = [NSRecursiveLock new];
    self.tasks = [NSMutableDictionary dictionary];
    self.ipDomains = [NSMutableDictionary dictionary];
}

- (void)clearAllCache
{
    [[SonicCache shareCache] clearAllCache];
}

- (BOOL)isFirstLoad:(NSString *)url
{
    return [[SonicCache shareCache] isFirstLoad:sonicSessionID(url)];
}

- (NSString *)localRefreshTimeByUrl:(NSString *)url
{
    return [[SonicCache shareCache] localRefreshTimeBySessionID:sonicSessionID(url)];
}

- (void)removeCacheByUrl:(NSString *)url
{
    SonicSession *existSession = [self sessionById:sonicSessionID(url)];
    if (!existSession) {
        [[SonicCache shareCache] removeCacheBySessionID:sonicSessionID(url)];
    }
}

- (void)registProtocolCallBack:(SonicURLProtocolCallBack)callBack withSessionID:(NSString *)sessionID
{
    SonicSession *existSession = [self sessionById:sessionID];
    if (existSession) {
        dispatchToSonicSessionQueue(^{
            existSession.protocolCallBack = callBack;
        });
    }
}

- (void)registerURLProtocolCallBackWithSessionID:(NSString *)sessionID completion:(SonicURLProtocolCallBack)protocolCallBack
{
    dispatchToMain(^{
        SonicSession *session = [self sessionById:sessionID];
        if (session) {
            [session preloadRequestActionsWithProtocolCallBack:protocolCallBack];
        }
    });
}

- (void)sonicUpdateDiffDataByWebDelegate:(id<SonicSessionDelegate>)aWebDelegate completion:(SonicWebviewCallBack)resultBlock
{
    if (!resultBlock) {
        return;
    }
    
    SonicSession *session = [self sessionWithWebDelegate:aWebDelegate];
    [session getResultWithCallBack:^(NSDictionary *result) {
        if (resultBlock) {
            resultBlock(result);
        }
    }];
}

#pragma mark - Safe Session Manager

static bool ValidateSessionDelegate(id<SonicSessionDelegate> aWebDelegate)
{
    return aWebDelegate && [aWebDelegate conformsToProtocol:@protocol(SonicSessionDelegate)];
}

- (void)createSessionWithUrl:(NSString *)url withWebDelegate:(id<SonicSessionDelegate>)aWebDelegate
{
    if ([[SonicCache shareCache] isServerDisableSonic:sonicSessionID(url)]) {
        return;
    }
    
    [self.lock lock];
    SonicSession *existSession = self.tasks[sonicSessionID(url)];
    if (existSession && existSession.delegate != nil) {
        //session can only owned by one delegate
        [self.lock unlock];
        return;
    }
    
    if (!existSession) {
        
        existSession = [[SonicSession alloc] initWithUrl:url withWebDelegate:aWebDelegate];
        
        NSURL *cUrl = [NSURL URLWithString:url];
        existSession.serverIP = [self.ipDomains objectForKey:cUrl.host];
        
        __weak typeof(self) weakSelf = self;
        __weak typeof(existSession)weakSession = existSession;
        [existSession setCompletionCallback:^(NSString *sessionID){
            [weakSession cancel];
            [weakSelf.tasks removeObjectForKey:sessionID];
        }];
        
        [self.tasks setObject:existSession forKey:existSession.sessionID];
        [existSession start];

    }else{
        
        if (existSession.delegate == nil) {
            existSession.delegate = aWebDelegate;
        }
    }
    
    [self.lock unlock];
}


- (SonicSession *)sessionWithWebDelegate:(id<SonicSessionDelegate>)aWebDelegate
{
    if (!ValidateSessionDelegate(aWebDelegate)) {
        return nil;
    }
    
    SonicSession *findSession = nil;
    
    [self.lock lock];
    for (SonicSession *session in self.tasks.allValues) {
        if (session.delegate == aWebDelegate) {
            findSession = session;
            break;
        }
    }
    [self.lock unlock];
    
    return findSession;
}

- (SonicSession *)sessionById:(NSString *)sessionId
{
    SonicSession *session = nil;
    [self.lock lock];
    session = self.tasks[sessionId];
    [self.lock unlock];
    return session;
}

- (void)removeSessionWithWebDelegate:(id<SonicSessionDelegate>)aWebDelegate
{
    if (!ValidateSessionDelegate(aWebDelegate)) {
        return;
    }
    
    [self.lock lock];
    SonicSession *findSession = nil;
    for (SonicSession *session in self.tasks.allValues) {
        if (session.delegate == aWebDelegate) {
            findSession = session;
            break;
        }
    }
    
    if (findSession) {
        [findSession cancel];
        [self.tasks removeObjectForKey:findSession.sessionID];
    }
    [self.lock unlock];
    
}

@end
