#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <stdio.h>
#include <sys/socket.h>
#include <unistd.h>

NSMutableDictionary *MusicIDsMap;

@interface HijackURLProtocol : NSURLProtocol <NSURLConnectionDelegate>
@property(nonatomic, strong) NSURLConnection *connection;
@property(nonatomic, strong) NSMutableData *responseData;
@end

@implementation HijackURLProtocol{
  BOOL isStream;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([NSURLProtocol propertyForKey:@"Hijacked" inRequest:request]) {
        return NO;
    }else{
#ifdef DEBUG
      NSLog(@"canInitWithRequest: %@ %@", [request HTTPMethod], [[request URL] path]);
#endif
      if ([[[request URL] path] isEqualToString:@"/eapi/v3/song/detail"]) {
        return YES;
      }else if([[[request URL] path] isEqualToString:@"/eapi/v3/playlist/detail"]){
        return YES;
      }else if([[[request URL] path] containsString:@"/eapi/copyright/restrict"]){
        return YES;
      }else if([[[request URL] path] containsString:@"/eapi/v1/playlist/manipulate/tracks"]){
        return YES;
      }else if([[[request URL] path] containsString:@"/eapi/song/like"]){
        return YES;
      }else if([[[request URL] path] containsString:@"/eapi/song/enhance/player/url"]){
        return YES;
      }else if([[[request URL] path] containsString:@"/eapi/song/enhance/download/url"]){
        return YES;
      }else if([[[request URL] path] containsString:@"/eapi/cloudsearch/pc"]){
        return YES;
      }else if([[[request URL] path] containsString:@"/eapi/v1/album"]){
        return YES;
      }else if([[[request URL] path] containsString:@"/eapi/v1/artist"]){
        return YES;
      }else if([[[request URL] host] isEqualToString:@"p2.music.126.net"]){
        return YES;
      }
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    if([[[self.request URL] host] isEqualToString:@"p2.music.126.net"]){
        NSLog(@"Using stream mode");
        isStream = YES;
    }
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"Hijacked" inRequest:newRequest];
    [newRequest addValue:@"118.88.88.88" forHTTPHeaderField:@"X-Real-IP"];
    self.connection = [NSURLConnection connectionWithRequest:newRequest delegate:self];
}

- (void)stopLoading {
    [self.connection cancel];
    self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.responseData = [[NSMutableData alloc] init];
    NSURLResponse *res;
    if(isStream){
      NSHTTPURLResponse *httpres = (NSHTTPURLResponse *)response;
      NSMutableDictionary *httpResponseHeaderFields = [[httpres allHeaderFields] mutableCopy];
      httpResponseHeaderFields[@"Content-Type"] = @"audio/mpeg";
      res = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                   statusCode:200
                   HTTPVersion:@"1.1"
                   headerFields:httpResponseHeaderFields];
      NSLog(@"Fix mime-type to audio/mpeg, %@",res);
    }else{
      res = response;
#ifdef DEBUG
      NSLog(@"Response %ld", (long)[response statusCode]);
#endif
    }
    [self.client URLProtocol:self
          didReceiveResponse:res
          cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if(isStream){
      [self.client URLProtocol:self didLoadData:data];
    }else{
      [self.responseData appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {

#ifdef DEBUG
    NSString *respStr = [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
    NSLog(@"Response data: %@", respStr);
#endif

    if([[[self.request URL] path] containsString:@"/eapi/song/enhance/player/url"]){
        return [self getEnhancePlayURL];
    }else if([[[self.request URL] path] containsString:@"/eapi/song/enhance/download/url"]){
        return [self getDownloadURL];
    }else if(isStream){
        return [self.client URLProtocolDidFinishLoading:self];
    }
    id res = [NSJSONSerialization JSONObjectWithData:self.responseData options:NSJSONReadingMutableContainers error:nil];
    if(!res || ![res count]){
        NSLog(@"connectionDidFinishLoading: Cannot get json data");
        return [self returnOriginData];
    }

    int replaced = 0;

    // Privileges
    if(![self isEmpty:res[@"privileges"]]){
      int count = [res[@"privileges"] count];
      for (int i = 0; i < count; i++) {
          NSNumber *st = res[@"privileges"][i][@"st"];
          NSNumber *fee = res[@"privileges"][i][@"fee"];
          if(st.intValue < 0 || fee.intValue > 0){
              res[@"privileges"][i] = [self replacePrivilege:res[@"privileges"][i]];
              replaced++;
          }
      }
    }

    // Search Results
    if(![self isEmpty:res[@"result"]] && ![self isEmpty:res[@"result"][@"songs"]]){
        int scount = [res[@"result"][@"songs"] count];
        for (int i = 0; i < scount; i++) {
            id song = res[@"result"][@"songs"][i];
            song[@"st"] = @0;
            song[@"fee"] = @0;
            song[@"privilege"] = [self replacePrivilege:song[@"privilege"]];
            replaced++;
            MusicIDsMap[song[@"id"]] = song;
            res[@"result"][@"songs"][i] = song;
        }
    }


    // Songs
    if(![self isEmpty:res[@"songs"]]){
        int scount = [res[@"songs"] count];
        for (int i = 0; i < scount; i++) {
            id song = res[@"songs"][i];
            song[@"st"] = @0;
            song[@"fee"] = @0;
            if(![self isEmpty:song[@"privilege"]]){
              song[@"privilege"] = [self replacePrivilege:song[@"privilege"]];
              replaced++;
            }
            MusicIDsMap[song[@"id"]] = song;
            res[@"songs"][i] = song;
        }
    }

    // Hot Songs
    if(![self isEmpty:res[@"hotSongs"]]){
        int scount = [res[@"hotSongs"] count];
        for (int i = 0; i < scount; i++) {
            id song = res[@"hotSongs"][i];
            song[@"st"] = @0;
            song[@"fee"] = @0;
            if(![self isEmpty:song[@"privilege"]]){
              song[@"privilege"] = [self replacePrivilege:song[@"privilege"]];
              replaced++;
            }
            MusicIDsMap[song[@"id"]] = song;
            res[@"hotSongs"][i] = song;
        }
    }

    // Playlists
    if(![self isEmpty:res[@"playlist"]] && ![self isEmpty:res[@"playlist"][@"tracks"]]){
        int scount = [res[@"playlist"][@"tracks"] count];
        for (int i = 0; i < scount; i++) {
            res[@"playlist"][@"tracks"][i][@"st"] = @0;
            res[@"playlist"][@"tracks"][i][@"fee"] = @0;
            MusicIDsMap[res[@"playlist"][@"tracks"][i][@"id"]] = res[@"playlist"][@"tracks"][i];
        }
    }

    NSLog(@"蛤蛤！替换了 %d 首被下架的歌曲",replaced);
    NSData *d = [NSJSONSerialization dataWithJSONObject:res options:0 error:nil];
    [self.client URLProtocol:self didLoadData:d];
    [self.client URLProtocolDidFinishLoading:self];
}

- (NSDictionary *)replacePrivilege:(NSDictionary *)dict{
  NSMutableDictionary *res = [dict mutableCopy];
  res[@"st"] = @0;
  res[@"pl"] = res[@"maxbr"];
  res[@"dl"] = res[@"maxbr"];
  res[@"fl"] = res[@"maxbr"];
  res[@"sp"] = @7;
  res[@"cp"] = @1;
  res[@"subp"] = @1;
  res[@"fee"] = @0;
  return res;
}

- (void)returnOriginData{
    [self.client URLProtocol:self didLoadData:self.responseData];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

- (void)getEnhancePlayURL{
    id res = [NSJSONSerialization JSONObjectWithData:self.responseData options:NSJSONReadingMutableContainers error:nil];
    if(!res || ![res count]){
        NSLog(@"getEnhancePlayURL: Cannot get json data");
        return [self returnOriginData];
    }
    int count = [res[@"data"] count];
    int replaced = 0;
    for (int i = 0; i < count; i++) {
        NSString *url = res[@"data"][i][@"url"];
        if (!url || [url isEqual:[NSNull null]]){
            NSDictionary *dic = [self selectMediaProfile:res[@"data"][i][@"id"]];
            if (dic == nil) {
              continue;
            }
            res[@"data"][i][@"code"] = @200;
            res[@"data"][i][@"type"] = dic[@"type"];
            res[@"data"][i][@"url"] = dic[@"url"];
            res[@"data"][i][@"br"] = dic[@"br"];
            res[@"data"][i][@"size"] = dic[@"size"];
            res[@"data"][i][@"gain"] = dic[@"gain"];
            replaced++;
        }
    }
    NSLog(@"Excited! 拼接了 %d 个 URL",replaced);
    NSData *d = [NSJSONSerialization dataWithJSONObject:res options:0 error:nil];
#ifdef DEBUG
    NSLog(@"=> %@", [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]);
#endif
    [self.client URLProtocol:self didLoadData:d];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)getDownloadURL{
    id res = [NSJSONSerialization JSONObjectWithData:self.responseData options:NSJSONReadingMutableContainers error:nil];
    if(!res || ![res count]){
        NSLog(@"getEnhancePlayURL: Cannot get json data");
        return [self returnOriginData];
    }
    NSString *url = res[@"data"][@"url"];
    if (!url || [url isEqual:[NSNull null]]){
      NSDictionary *dic = [self selectMediaProfile:res[@"data"][@"id"]];
      if (dic) {
        res[@"data"][@"code"] = @200;
        res[@"data"][@"type"] = dic[@"type"];
        res[@"data"][@"url"] = dic[@"url"];
        res[@"data"][@"br"] = dic[@"br"];
        res[@"data"][@"size"] = dic[@"size"];
        res[@"data"][@"gain"] = dic[@"gain"];
      }
    }
    NSData *d = [NSJSONSerialization dataWithJSONObject:res options:0 error:nil];
#ifdef DEBUG
    NSLog(@"=> %@", [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]);
#endif
    [self.client URLProtocol:self didLoadData:d];
    [self.client URLProtocolDidFinishLoading:self];
}

- (NSDictionary *)selectMediaProfileFromServer:(NSNumber *)mid{
    NSString *requrl = [NSString stringWithFormat:@"http://music.163.com/api/song/detail/?id=%@&ids=[%@]",mid,mid];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:requrl]];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 5;
    [request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_4) AppleWebKit/601.5.17 (KHTML, like Gecko)" forHTTPHeaderField:@"User-Agent"];

    NSURLResponse * response = nil;
    NSError * error = nil;
    NSData * returnData = [NSURLConnection sendSynchronousRequest:request
                                                        returningResponse:&response
                                                                    error:&error];
    if(!returnData){
        return nil;
    }

    id res = [NSJSONSerialization JSONObjectWithData:returnData options:0 error:nil];
    if(!res || ![res count]){
        NSLog(@"selectFid: Cannot get json data");
        return nil;
    }
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    id dic = res[@"songs"][0];
    if(![self isValid:dic[@"hMusic"]]){
      [result setObject:
       [self urlFromFid:dic[@"hMusic"][@"dfsId"]] forKey:@"url"];
      [result setObject:dic[@"hMusic"][@"extension"] forKey:@"type"];
      [result setObject:dic[@"hMusic"][@"bitrate"] forKey:@"br"];
      [result setObject:dic[@"hMusic"][@"size"] forKey:@"size"];
      [result setObject:dic[@"hMusic"][@"volumeDelta"] forKey:@"gain"];
    }else if(![self isValid:dic[@"mMusic"]]){
      [result setObject:
       [self urlFromFid:dic[@"mMusic"][@"dfsId"]] forKey:@"url"];
      [result setObject:dic[@"mMusic"][@"extension"] forKey:@"type"];
      [result setObject:dic[@"mMusic"][@"bitrate"] forKey:@"br"];
      [result setObject:dic[@"mMusic"][@"size"] forKey:@"size"];
      [result setObject:dic[@"mMusic"][@"volumeDelta"] forKey:@"gain"];
    }else if(![self isValid:dic[@"bMusic"]]){
      [result setObject:
       [self urlFromFid:dic[@"bMusic"][@"dfsId"]] forKey:@"url"];
      [result setObject:dic[@"bMusic"][@"extension"] forKey:@"type"];
      [result setObject:dic[@"bMusic"][@"bitrate"] forKey:@"br"];
      [result setObject:dic[@"bMusic"][@"size"] forKey:@"size"];
      [result setObject:dic[@"bMusic"][@"volumeDelta"] forKey:@"gain"];
    }else if(![self isValid:dic[@"audition"]]){
      [result setObject:
       [self urlFromFid:dic[@"audition"][@"dfsId"]] forKey:@"url"];
      [result setObject:dic[@"audition"][@"extension"] forKey:@"type"];
      [result setObject:dic[@"audition"][@"bitrate"] forKey:@"br"];
      [result setObject:dic[@"audition"][@"size"] forKey:@"size"];
      [result setObject:dic[@"audition"][@"volumeDelta"] forKey:@"gain"];
    }
    if(!result[@"url"]){
      NSLog(@"Fid select failed");
      return nil;
    }
    return result;
}

- (NSDictionary *)selectMediaProfile:(NSNumber *)mid{
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  NSDictionary *dic = MusicIDsMap[mid];
  if (!dic || [dic isEqual:[NSNull null]] || ![dic count]){
     return [self selectMediaProfileFromServer:mid];
  }
  NSLog(@"Song data: %@", dic);
  [result setObject:@"mp3" forKey:@"type"];
  if (![self isValid:dic[@"h"]]) {
    [result setObject:
     [self urlFromFid:dic[@"h"][@"fid"]] forKey:@"url"];
    [result setObject:dic[@"h"][@"br"] forKey:@"br"];
    [result setObject:dic[@"h"][@"size"] forKey:@"size"];
    [result setObject:dic[@"h"][@"vd"] forKey:@"gain"];
  }else if(![self isValid:dic[@"m"]]){
    [result setObject:
     [self urlFromFid:dic[@"m"][@"fid"]] forKey:@"url"];
    [result setObject:dic[@"m"][@"br"] forKey:@"br"];
    [result setObject:dic[@"m"][@"size"] forKey:@"size"];
    [result setObject:dic[@"m"][@"vd"] forKey:@"gain"];
  }else if(![self isValid:dic[@"l"]]){
    [result setObject:
     [self urlFromFid:dic[@"l"][@"fid"]] forKey:@"url"];
    [result setObject:dic[@"l"][@"br"] forKey:@"br"];
    [result setObject:dic[@"l"][@"size"] forKey:@"size"];
    [result setObject:dic[@"l"][@"vd"] forKey:@"gain"];
  }else if(![self isValid:dic[@"a"]]){
    [result setObject:
     [self urlFromFid:dic[@"a"][@"fid"]] forKey:@"url"];
    [result setObject:dic[@"a"][@"br"] forKey:@"br"];
    [result setObject:dic[@"a"][@"size"] forKey:@"size"];
    [result setObject:dic[@"a"][@"vd"] forKey:@"gain"];
  }else{
     return [self selectMediaProfileFromServer:mid];
  }
  if(!result[@"url"]){
    NSLog(@"Fid select failed");
    return nil;
  }
  return result;
}

- (BOOL) isValid:(NSDictionary*)object{
if ([self isEmpty:object]) {
  if (object[@"fid"] && ![object[@"fid"] isEqualToNumber: @0]) {
    return YES;
  }
  if (object[@"dfsId"] && ![object[@"dfsId"] isEqualToNumber: @0]) {
    return YES;
  }
}
return NO;
}

- (NSString *)urlFromFid:(NSNumber *)fid{
    NSString *fidstr = [NSString stringWithFormat:@"%@",fid];
    const char *c = "3go8&$8*3*3h0k(2)2";
    const char *f = [fidstr UTF8String];
    int fidlen = strlen(f);
    char result[fidlen+1];
    for (int i = 0; i < fidlen; i++){
        result[i] = f[i] ^ c[i % 18];
    }
    result[fidlen] = '\0';

    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(result, fidlen, digest);
    NSData *hashData = [[NSData alloc] initWithBytes:digest length: sizeof digest];

    NSString *base64String = [hashData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
#ifndef OUTSIDE_CHINA
    NSString *finalURL = [NSString stringWithFormat:@"http://m%d.music.126.net/%@/%@.mp3",arc4random_uniform(2)+1,base64String,fid];
#else
    NSString *finalURL = [NSString stringWithFormat:@"http://p2.music.126.net/%@/%@.mp3",base64String,fid];
#endif
    NSLog(@"FinalURL: %@", finalURL);
    return finalURL;
}

- (BOOL)isEmpty:(id)obj{
    if(!obj || [obj isEqual:[NSNull null]] || ![obj count]){
        return YES;
    }
    return NO;
}

@end

BOOL isLoaded = NO;

__attribute__((constructor)) void DllMain()
{
  if (!isLoaded) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
      MusicIDsMap = [[NSMutableDictionary alloc] init];
      if ([NSURLProtocol registerClass:[HijackURLProtocol class]]) {
          NSLog(@"[NMUnlock] 插♂入成功! ");
      } else {
          NSLog(@"[NMUnlock] 我去竟然失败了");
      }
      isLoaded = YES;
    });
  }
}
