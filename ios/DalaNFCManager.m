// DalaNFCManager.m - iOS CoreNFC wrapper implementation
#import "DalaNFCManager.h"
#import <CoreNFC/CoreNFC.h>

@interface DalaNFCManager () <NFCNDEFReaderSessionDelegate>
@property (nonatomic, assign) DalaNFCCallback nfcCallback;
@property (nonatomic, strong, nullable) NFCNDEFReaderSession *session;
@end

@implementation DalaNFCManager

+ (instancetype)sharedManager {
    static DalaNFCManager *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[DalaNFCManager alloc] init];
    });
    return instance;
}

- (void)setNFCCallback:(DalaNFCCallback)callback {
    self.nfcCallback = callback;
}

- (BOOL)isAvailable {
    return NFCNDEFReaderSession.readingAvailable;
}

- (void)beginScanWithMessage:(NSString *)message {
    if (!NFCNDEFReaderSession.readingAvailable) {
        if (self.nfcCallback) {
            self.nfcCallback("", "", "NFC not available on this device");
        }
        return;
    }
    self.session = [[NFCNDEFReaderSession alloc] initWithDelegate:self
                                                             queue:NULL
                          invalidateAfterFirstRead:NO];
    if (message) {
        self.session.alertMessage = message;
    }
    [self.session beginSession];
}

- (void)cancelScan {
    [self.session invalidateSession];
    self.session = nil;
}

#pragma mark - NFCNDEFReaderSessionDelegate

- (void)readerSession:(NFCNDEFReaderSession *)session didDetectNDEFs:(NSArray<NFCNDEFMessage *> *)messages {
    if (!self.nfcCallback) return;
    for (NFCNDEFMessage *message in messages) {
        for (NFCNDEFPayload *record in message.records) {
            NSString *type = [[NSString alloc] initWithData:record.type encoding:NSUTF8StringEncoding] ?: @"";
            NSString *payload = [[NSString alloc] initWithData:record.payload encoding:NSUTF8StringEncoding] ?: @"";
            const char *tech = [type UTF8String];
            const char *data = [payload UTF8String];
            self.nfcCallback(tech, data, NULL);
        }
    }
}

- (void)readerSession:(NFCNDEFReaderSession *)session didInvalidateWithError:(NSError *)error {
    self.session = nil;
    if (self.nfcCallback) {
        const char *errStr = [error.localizedDescription UTF8String];
        self.nfcCallback("", "", errStr);
    }
}

@end
