// DalaNFCManager.h - iOS CoreNFC wrapper for Dala
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (*DalaNFCCallback)(const char *tech, const char *payload, const char *error);

@interface DalaNFCManager : NSObject

+ (instancetype)sharedManager;

- (void)setNFCCallback:(DalaNFCCallback)callback;
- (BOOL)isAvailable;
- (void)beginScanWithMessage:(NSString *)message;
- (void)cancelScan;

@end

NS_ASSUME_NONNULL_END
