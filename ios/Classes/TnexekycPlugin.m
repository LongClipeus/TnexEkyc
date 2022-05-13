#import "TnexekycPlugin.h"
#if __has_include(<tnexekyc/tnexekyc-Swift.h>)
#import <tnexekyc/tnexekyc-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "tnexekyc-Swift.h"
#endif

@implementation TnexekycPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftTnexekycPlugin registerWithRegistrar:registrar];
}
@end
