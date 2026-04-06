#import <Foundation/Foundation.h>
#import "FMDaemon.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        FMDaemon *daemon = [FMDaemon sharedDaemon];
        [daemon start];
        dispatch_main();
    }
    return 0;
}
