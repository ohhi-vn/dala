// DalaMotionManager.h - iOS CoreMotion wrapper for Dala
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (*DalaMotionDataCallback)(double ax, double ay, double az,
                                        double gx, double gy, double gz,
                                        int64_t timestamp_ms);

@interface DalaMotionManager : NSObject

+ (instancetype)sharedManager;

- (void)setMotionCallback:(DalaMotionDataCallback)callback;
- (BOOL)isAccelerometerAvailable;
- (BOOL)isGyroAvailable;
- (void)startMotionUpdates:(NSArray<NSString *> *)sensors intervalMs:(NSInteger)intervalMs;
- (void)stopMotionUpdates;
- (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END
