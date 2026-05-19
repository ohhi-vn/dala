// DalaMotionManager.m - iOS CoreMotion wrapper implementation
#import "DalaMotionManager.h"
#import <CoreMotion/CoreMotion.h>

@interface DalaMotionManager ()
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, assign) DalaMotionDataCallback motionCallback;
@property (nonatomic, assign) BOOL running;
@end

@implementation DalaMotionManager

+ (instancetype)sharedManager {
    static DalaMotionManager *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[DalaMotionManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _motionManager = [[CMMotionManager alloc] init];
        _running = NO;
    }
    return self;
}

- (BOOL)isAccelerometerAvailable {
    return self.motionManager.isAccelerometerAvailable;
}

- (BOOL)isGyroAvailable {
    return self.motionManager.isGyroAvailable;
}

- (void)setMotionCallback:(DalaMotionDataCallback)callback {
    self.motionCallback = callback;
}

- (void)startMotionUpdates:(NSArray<NSString *> *)sensors intervalMs:(NSInteger)intervalMs {
    if (self.running) [self stopMotionUpdates];

    double interval = intervalMs / 1000.0;
    BOOL wantAccel = [sensors containsObject:@"accelerometer"];
    BOOL wantGyro = [sensors containsObject:@"gyro"];

    if (wantAccel && self.motionManager.isAccelerometerAvailable) {
        self.motionManager.accelerometerUpdateInterval = interval;
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [self.motionManager startAccelerometerUpdatesToQueue:queue
            withHandler:^(CMAccelerometerData *data, NSError *error) {
                if (error || !self.motionCallback) return;
                double ax = data.acceleration.x * 9.81;
                double ay = data.acceleration.y * 9.81;
                double az = data.acceleration.z * 9.81;
                double gx = 0, gy = 0, gz = 0;
                int64_t ts = (int64_t)([data.timestamp * 1000]);
                self.motionCallback(ax, ay, az, gx, gy, gz, ts);
            }];
    }

    if (wantGyro && self.motionManager.isGyroAvailable) {
        self.motionManager.gyroUpdateInterval = interval;
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [self.motionManager startGyroUpdatesToQueue:queue
            withHandler:^(CMGyroData *data, NSError *error) {
                if (error || !self.motionCallback) return;
                double gx = data.rotationRate.x;
                double gy = data.rotationRate.y;
                double gz = data.rotationRate.z;
                double ax = 0, ay = 0, az = 0;
                int64_t ts = (int64_t)([data.timestamp * 1000]);
                self.motionCallback(ax, ay, az, gx, gy, gz, ts);
            }];
    }

    self.running = YES;
}

- (void)stopMotionUpdates {
    [self.motionManager stopAccelerometerUpdates];
    [self.motionManager stopGyroUpdates];
    self.running = NO;
}

- (BOOL)isRunning {
    return self.running;
}

@end
