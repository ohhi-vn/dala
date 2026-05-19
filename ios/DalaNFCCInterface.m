// DalaNFCCInterface.m - C interface for Rust to call Objective-C NFC code
#import "DalaNFCManager.h"

#ifdef __cplusplus
extern "C" {
#endif

static DalaNFCCallback g_nfcCallback = NULL;

void DalaNFCSetCallback(DalaNFCCallback callback) {
    g_nfcCallback = callback;
    [[DalaNFCManager sharedManager] setNFCCallback:callback];
}

int DalaNFCAvailable(void) {
    return [[DalaNFCManager sharedManager] isAvailable] ? 1 : 0;
}

void DalaNFCBeginScan(const char *message) {
    NSString *msg = message ? [NSString stringWithUTF8String:message] : @"Hold near an NFC tag";
    [[DalaNFCManager sharedManager] beginScanWithMessage:msg];
}

void DalaNFCCancelScan(void) {
    [[DalaNFCManager sharedManager] cancelScan];
}

#ifdef __cplusplus
}
#endif
