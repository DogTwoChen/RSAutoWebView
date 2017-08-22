//
//  SonicCacheItem.h
//  sonic
//
//  Tencent is pleased to support the open source community by making VasSonic available.
//  Copyright (C) 2017 THL A29 Limited, a Tencent company. All rights reserved.
//  Licensed under the BSD 3-Clause License (the "License"); you may not use this file except
//  in compliance with the License. You may obtain a copy of the License at
//
//  https://opensource.org/licenses/BSD-3-Clause
//
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Memory cache item.
 */
@interface SonicCacheItem : NSObject

/** Html. */
@property (nonatomic,retain)NSData         *htmlData;

/** Config. */
@property (nonatomic,retain)NSDictionary   *config;

/** Session. */
@property (nonatomic,readonly)NSString     *sessionID;

/** Template string. */
@property (nonatomic,copy)  NSString       *templateString;

/** Generated by local dynamic data and server dynamic data. */
@property (nonatomic,retain)NSDictionary   *diffData;

/** Sonic devide HTML to tepmlate and dynamic data.  */
@property (nonatomic,retain)NSDictionary   *dynamicData;

/** Is there file cache exist. */
@property (nonatomic,readonly)BOOL         hasLocalCache;

/** Last refresh time.  */
@property (nonatomic,readonly)NSString     *lastRefreshTime;

/** Cache some header fields which will be used later. */
@property (nonatomic,readonly)NSDictionary *cacheResponseHeaders;

/** Initialize an item with session id. */
- (instancetype)initWithSessionID:(NSString *)aSessionID;

@end