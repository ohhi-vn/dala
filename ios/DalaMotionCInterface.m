// DalaMotionCInterface.m - C interface for Rust to call Objective-C Motion code
#import "DalaMotionManager.h"

#ifdef __cplusplus
extern "C" {
#endif

static DalaMotionDataCallback g_motionCallback = NULL;

void DalaMotionSetCallback(DalaMotionDataCallback callback) {
    g_motionCallback = callback;
    [[DalaMotionManager sharedManager] setMotionCallback:callback];
}

int DalaMotionIsAvailable(void) {
    return ([[DalaMotionManager sharedManager] isAccelerometerAvailable] ||
            [[DalaMotionManager sharedManager] isGyroAvailable]) ? 1 : 0;
}

void DalaMotionStart(const char **sensors, int sensorCount, int intervalMs) {
    NSMutableArray *arr = [NSMutableArray array];
    for (int i = 0; i < sensorCount; i++) {
        [arr addObject:[NSString stringWithUTF8String:sensors[i]]];
    }
    [[DalaMotionManager sharedManager] startMotionUpdates:arr intervalMs:intervalMs];
}

void DalaMotionStop(void) {
    [[DalaMotionManager sharedManager] stopMotionUpdates];
}

#ifdef __cplusplus
}
#endif
