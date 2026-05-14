// DalaNode.m — Dala UI tree node implementation.

#import "DalaNode.h"
#import <math.h>

@implementation DalaNode

- (instancetype)init {
    if ((self = [super init])) {
        _textSize      = 14.0;
        _padding       = 0.0;
        _paddingTop    = -1.0;
        _paddingRight  = -1.0;
        _paddingBottom = -1.0;
        _paddingLeft   = -1.0;
        _fontWeight    = @"regular";
        _textAlign     = @"left";
        _italic        = NO;
        _lineHeight    = 0.0;
        _letterSpacing = 0.0;
        _thickness     = 1.0;
        _fixedSize     = 0.0;
        _value         = NAN;   // NaN = indeterminate (progress) or not-yet-set (slider)
        _minValue      = 0.0;
        _maxValue      = 1.0;
        _checked       = NO;
        _axis            = @"vertical";
        _showIndicator   = YES;
        _keyboardTypeStr = @"default";
        _returnKeyStr    = @"done";
        _contentModeStr  = @"fit";
        _fixedWidth      = 0.0;
        _fixedHeight     = 0.0;
        _fillWidth       = NO;
        _cornerRadius    = 0.0;
        _gap             = 0.0;
        _disabled        = NO;
        _videoAutoplay = NO;
        _videoLoop     = NO;
        _videoControls = YES;
        _children      = [NSMutableArray array];
        _nodeId        = [[NSUUID UUID] UUIDString];  // Unique ID for SwiftUI ForEach
    }
    return self;
}

+ (nullable instancetype)fromDictionary:(nonnull NSDictionary*)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    DalaNode *node = [[DalaNode alloc] init];

    // Generate unique ID (can be overridden by props if needed for debugging)
    node.nodeId = [[NSUUID UUID] UUIDString];

    // Node type
    NSString *typeStr = dict[@"type"];
    if ([typeStr isKindOfClass:[NSString class]]) {
        node.nodeType = [self nodeTypeFromString:typeStr];
    }

    // Props dictionary
    NSDictionary *props = dict[@"props"];
    if ([props isKindOfClass:[NSDictionary class]]) {
        [self applyProps:props toNode:node];
    }

    // Children
    NSArray *children = dict[@"children"];
    if ([children isKindOfClass:[NSArray class]]) {
        for (id childDict in children) {
            if ([childDict isKindOfClass:[NSDictionary class]]) {
                DalaNode *child = [DalaNode fromDictionary:childDict];
                if (child) {
                    [node.children addObject:child];
                }
            }
        }
    }

    return node;
}

+ (DalaNodeType)nodeTypeFromString:(NSString *)str {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"column":        @(DalaNodeTypeColumn),
            @"row":           @(DalaNodeTypeRow),
            @"label":         @(DalaNodeTypeLabel),
            @"text":          @(DalaNodeTypeLabel),
            @"button":        @(DalaNodeTypeButton),
            @"scroll":        @(DalaNodeTypeScroll),
            @"box":           @(DalaNodeTypeBox),
            @"divider":       @(DalaNodeTypeDivider),
            @"spacer":        @(DalaNodeTypeSpacer),
            @"progress":      @(DalaNodeTypeProgress),
            @"progress_bar":  @(DalaNodeTypeProgress),
            @"text_field":    @(DalaNodeTypeTextField),
            @"toggle":        @(DalaNodeTypeToggle),
            @"switch":        @(DalaNodeTypeToggle),
            @"slider":        @(DalaNodeTypeSlider),
            @"image":         @(DalaNodeTypeImage),
            @"lazy_list":     @(DalaNodeTypeLazyList),
            @"list":          @(DalaNodeTypeLazyList),
            @"tab_bar":       @(DalaNodeTypeTabBar),
            @"video":         @(DalaNodeTypeVideo),
            @"camera_preview": @(DalaNodeTypeCameraPreview),
            @"web_view":      @(DalaNodeTypeWebView),
            @"webview":       @(DalaNodeTypeWebView),
            @"native_view":   @(DalaNodeTypeNativeView),
            @"icon":          @(DalaNodeTypeIcon),
            @"modal":         @(DalaNodeTypeModal),
            @"pressable":     @(DalaNodeTypePressable),
            @"safe_area":     @(DalaNodeTypeSafeArea),
            @"card":          @(DalaNodeTypeCard),
            @"badge":         @(DalaNodeTypeBadge),
            @"chip":          @(DalaNodeTypeChip),
            @"snackbar":      @(DalaNodeTypeSnackbar),
            @"fab":           @(DalaNodeTypeFab),
            @"icon_button":   @(DalaNodeTypeIconButton),
            @"segmented_button": @(DalaNodeTypeSegmentedButton),
            @"app_bar":       @(DalaNodeTypeAppBar),
            @"nav_bar":       @(DalaNodeTypeNavBar),
            @"nav_drawer":    @(DalaNodeTypeNavDrawer),
            @"nav_rail":      @(DalaNodeTypeNavRail),
            @"menu":          @(DalaNodeTypeMenu),
            @"date_picker":   @(DalaNodeTypeDatePicker),
            @"time_picker":   @(DalaNodeTypeTimePicker),
            @"search_bar":    @(DalaNodeTypeSearchBar),
            @"carousel":      @(DalaNodeTypeCarousel),
            @"bottom_sheet":  @(DalaNodeTypeBottomSheet),
            @"tooltip":       @(DalaNodeTypeTooltip),
            @"checkbox":      @(DalaNodeTypeCheckbox),
            @"radio":         @(DalaNodeTypeRadio),
            @"activity_indicator": @(DalaNodeTypeActivityIndicator),
            @"refresh_control": @(DalaNodeTypeRefreshControl),
            @"status_bar":    @(DalaNodeTypeStatusBar),
        };
    });
    NSNumber *typeNum = map[str];
return typeNum ? (DalaNodeType)typeNum.integerValue : DalaNodeTypeColumn;
}

+ (void)applyProps:(NSDictionary *)props toNode:(DalaNode *)node {
    // Text
    id text = props[@"text"];
    if ([text isKindOfClass:[NSString class]]) node.text = text;

    // Colors (hex strings like "#FF0000")
    id bgColor = props[@"background_color"];
    if ([bgColor isKindOfClass:[NSString class]]) node.backgroundColor = [self colorFromHex:bgColor];

    // Also accept "background" as an alias for background_color
    id bgAlias = props[@"background"];
    if ([bgAlias isKindOfClass:[NSString class]] && !bgColor) node.backgroundColor = [self colorFromHex:bgAlias];

    id textColor = props[@"text_color"];
    if ([textColor isKindOfClass:[NSString class]]) node.textColor = [self colorFromHex:textColor];

    // Padding
    id padding = props[@"padding"];
    if ([padding isKindOfClass:[NSNumber class]]) node.padding = [padding doubleValue];

    id paddingTop = props[@"padding_top"];
    if ([paddingTop isKindOfClass:[NSNumber class]]) node.paddingTop = [paddingTop doubleValue];

    id paddingRight = props[@"padding_right"];
    if ([paddingRight isKindOfClass:[NSNumber class]]) node.paddingRight = [paddingRight doubleValue];

    id paddingBottom = props[@"padding_bottom"];
    if ([paddingBottom isKindOfClass:[NSNumber class]]) node.paddingBottom = [paddingBottom doubleValue];

    id paddingLeft = props[@"padding_left"];
    if ([paddingLeft isKindOfClass:[NSNumber class]]) node.paddingLeft = [paddingLeft doubleValue];

    // Text size
    id textSize = props[@"text_size"];
    if ([textSize isKindOfClass:[NSNumber class]]) node.textSize = [textSize doubleValue];

    // Font weight
    id fontWeight = props[@"font_weight"];
    if ([fontWeight isKindOfClass:[NSString class]]) node.fontWeight = fontWeight;

    // Font family
    id fontFamily = props[@"font_family"];
    if ([fontFamily isKindOfClass:[NSString class]]) node.fontFamily = fontFamily;

    // Text align
    id textAlign = props[@"text_align"];
    if ([textAlign isKindOfClass:[NSString class]]) node.textAlign = textAlign;

    // Italic
    id italic = props[@"italic"];
    if ([italic isKindOfClass:[NSNumber class]]) node.italic = [italic boolValue];

    // Line height
    id lineHeight = props[@"line_height"];
    if ([lineHeight isKindOfClass:[NSNumber class]]) node.lineHeight = [lineHeight doubleValue];

    // Letter spacing
    id letterSpacing = props[@"letter_spacing"];
    if ([letterSpacing isKindOfClass:[NSNumber class]]) node.letterSpacing = [letterSpacing doubleValue];

    // Corner radius
    id cornerRadius = props[@"corner_radius"];
    if ([cornerRadius isKindOfClass:[NSNumber class]]) node.cornerRadius = [cornerRadius doubleValue];

    // Fill width
    id fillWidth = props[@"fill_width"];
    if ([fillWidth isKindOfClass:[NSNumber class]]) node.fillWidth = [fillWidth boolValue];

    // Gap (spacing between children in column/row)
    id gap = props[@"gap"];
    if ([gap isKindOfClass:[NSNumber class]]) node.gap = [gap doubleValue];

    // Disabled
    id disabled = props[@"disabled"];
    if ([disabled isKindOfClass:[NSNumber class]]) node.disabled = [disabled boolValue];

    // Border
    id borderColor = props[@"border_color"];
    if ([borderColor isKindOfClass:[NSString class]]) node.borderColor = [self colorFromHex:borderColor];

    id borderWidth = props[@"border_width"];
    if ([borderWidth isKindOfClass:[NSNumber class]]) node.borderWidth = [borderWidth doubleValue];

    // Accessibility ID
    id accessibilityId = props[@"accessibility_id"];
    if ([accessibilityId isKindOfClass:[NSString class]]) node.accessibilityId = accessibilityId;

    // Flex layout (column/row)
    id justifyContent = props[@"justify_content"];
    if ([justifyContent isKindOfClass:[NSNumber class]]) node.justifyContent = [justifyContent unsignedCharValue];

    id alignItems = props[@"align_items"];
    if ([alignItems isKindOfClass:[NSNumber class]]) node.alignItems = [alignItems unsignedCharValue];

    // ── Component-specific props ─────────────────────────────────────────

    // Divider
    id thickness = props[@"thickness"];
    if ([thickness isKindOfClass:[NSNumber class]]) node.thickness = [thickness doubleValue];

    id color = props[@"color"];
    if ([color isKindOfClass:[NSString class]]) node.color = [self colorFromHex:color];

    // Spacer
    id fixedSize = props[@"fixed_size"];
    if ([fixedSize isKindOfClass:[NSNumber class]]) node.fixedSize = [fixedSize doubleValue];

    // Scroll axis
    id axis = props[@"axis"];
    if ([axis isKindOfClass:[NSString class]]) node.axis = axis;

    id horizontal = props[@"horizontal"];
    if ([horizontal isKindOfClass:[NSNumber class]] && [horizontal boolValue]) node.axis = @"horizontal";

    id showIndicator = props[@"show_indicator"];
    if ([showIndicator isKindOfClass:[NSNumber class]]) node.showIndicator = [showIndicator boolValue];

    // Progress / Slider value
    id value = props[@"value"];
    if ([value isKindOfClass:[NSNumber class]]) node.value = [value doubleValue];

    id progress = props[@"progress"];
    if ([progress isKindOfClass:[NSNumber class]]) node.value = [progress doubleValue];

    id minValue = props[@"min_value"];
    if ([minValue isKindOfClass:[NSNumber class]]) node.minValue = [minValue doubleValue];

    id maxValue = props[@"max_value"];
    if ([maxValue isKindOfClass:[NSNumber class]]) node.maxValue = [maxValue doubleValue];

    // Toggle / Switch
    id checked = props[@"checked"];
    if ([checked isKindOfClass:[NSNumber class]]) node.checked = [checked boolValue];

    // Text field
    id placeholder = props[@"placeholder"];
    if ([placeholder isKindOfClass:[NSString class]]) node.placeholder = placeholder;

    id keyboardType = props[@"keyboard_type"];
    if ([keyboardType isKindOfClass:[NSString class]]) node.keyboardTypeStr = keyboardType;

    id returnKey = props[@"return_key"];
    if ([returnKey isKindOfClass:[NSString class]]) node.returnKeyStr = returnKey;

    // Image
    id src = props[@"src"];
    if ([src isKindOfClass:[NSString class]]) node.src = src;

    id contentMode = props[@"resize_mode"];
    if ([contentMode isKindOfClass:[NSString class]]) {
        if ([contentMode isEqualToString:@"fill"]) {
            node.contentModeStr = @"fill";
        } else if ([contentMode isEqualToString:@"stretch"]) {
            node.contentModeStr = @"stretch";
        } else {
            node.contentModeStr = @"fit";
        }
    }

    id fixedWidth = props[@"width"];
    if ([fixedWidth isKindOfClass:[NSNumber class]]) node.fixedWidth = [fixedWidth doubleValue];

    id fixedHeight = props[@"height"];
    if ([fixedHeight isKindOfClass:[NSNumber class]]) node.fixedHeight = [fixedHeight doubleValue];

    id placeholderColor = props[@"placeholder_color"];
    if ([placeholderColor isKindOfClass:[NSString class]]) node.placeholderColor = [self colorFromHex:placeholderColor];

    // Icon
    id iconName = props[@"name"];
    if ([iconName isKindOfClass:[NSString class]]) node.iconName = iconName;

    // Tab bar
    id tabDefs = props[@"tabs"];
    if ([tabDefs isKindOfClass:[NSArray class]]) node.tabDefs = tabDefs;

    id activeTab = props[@"active_tab"];
    if ([activeTab isKindOfClass:[NSString class]]) node.activeTab = activeTab;

    // Video
    id autoplay = props[@"autoplay"];
    if ([autoplay isKindOfClass:[NSNumber class]]) node.videoAutoplay = [autoplay boolValue];

    id loop = props[@"loop"];
    if ([loop isKindOfClass:[NSNumber class]]) node.videoLoop = [loop boolValue];

    id controls = props[@"controls"];
    if ([controls isKindOfClass:[NSNumber class]]) node.videoControls = [controls boolValue];

    // Camera preview
    id facing = props[@"facing"];
    if ([facing isKindOfClass:[NSString class]]) node.cameraFacing = facing;

    // WebView
    id webViewUrl = props[@"url"];
    if ([webViewUrl isKindOfClass:[NSString class]]) node.webViewUrl = webViewUrl;

    id webViewAllow = props[@"allow"];
    if ([webViewAllow isKindOfClass:[NSString class]]) node.webViewAllow = webViewAllow;

    id webViewShowUrl = props[@"show_url"];
    if ([webViewShowUrl isKindOfClass:[NSNumber class]]) node.webViewShowUrl = [webViewShowUrl boolValue];

    id webViewTitle = props[@"title"];
    if ([webViewTitle isKindOfClass:[NSString class]]) node.webViewTitle = webViewTitle;

    // Native view
    id nativeViewModule = props[@"module"];
    if ([nativeViewModule isKindOfClass:[NSString class]]) node.nativeViewModule = nativeViewModule;

    id nativeViewId = props[@"id"];
    if ([nativeViewId isKindOfClass:[NSString class]]) node.nativeViewId = nativeViewId;

    id nativeViewHandle = props[@"component_handle"];
    if ([nativeViewHandle isKindOfClass:[NSNumber class]]) node.nativeViewHandle = [nativeViewHandle intValue];

    node.nativeViewProps = props;
}

/// Create a DalaNode tree from binary protocol v3 data.
+ (nullable instancetype)fromBinary:(const UInt8 *)bytes length:(NSUInteger)length {
    if (length < 16) return nil;

    // Validate magic header
    if (bytes[0] != 0xDA || bytes[1] != 0xA1) return nil;

    NSUInteger i = 2;
    uint16_t version = (uint16_t)(bytes[i] | (bytes[i+1] << 8));
    i += 2;
    if (version != 3) return nil;

    // Skip flags (u16) and node_count (u64)
    i += 2 + 8;

    return [self decodeTreeNodeV3 bytes:bytes length:length index:&i];
}

+ (nullable instancetype)decodeTreeNodeV3:(const UInt8 *)bytes length:(NSUInteger)length index:(NSUInteger *)i {
    if (*i + 17 > length) return nil;

    DalaNode *node = [[DalaNode alloc] init];

    // Node ID (u64)
    // Skip ID for now - just advance
    *i += 8;

    // Node type (u8)
    uint8_t typeByte = bytes[*i];
    *i += 1;
    node.nodeType = [self nodeTypeFromByte:typeByte];

    // Layout hash (u64) - skip
    *i += 8;

    // Props
    if (*i >= length) return nil;
    uint8_t fieldCount = bytes[*i];
    *i += 1;
    for (uint8_t f = 0; f < fieldCount && *i < length; f++) {
        uint8_t tag = bytes[*i];
        *i += 1;
        [self decodeField:tag bytes:bytes length:length index:i toNode:node];
    }

    // Children
    if (*i + 4 > length) return nil;
    uint32_t childCount = (uint32_t)(bytes[*i] | (bytes[*i+1] << 8) | (bytes[*i+2] << 16) | (bytes[*i+3] << 24));
    *i += 4;

    // Skip child IDs (u64 each)
    if (*i + childCount * 8 > length) return nil;
    *i += childCount * 8;

    // Decode child nodes recursively
    for (uint32_t c = 0; c < childCount; c++) {
        DalaNode *child = [self decodeTreeNodeV3:bytes length:length index:i];
        if (child) {
            [node.children addObject:child];
        }
    }

    return node;
}

+ (DalaNodeType)nodeTypeFromByte:(uint8_t)byte {
    switch (byte) {
        case 0:  return DalaNodeTypeColumn;
        case 1:  return DalaNodeTypeRow;
        case 2:  return DalaNodeTypeLabel;
        case 3:  return DalaNodeTypeButton;
        case 4:  return DalaNodeTypeImage;
        case 5:  return DalaNodeTypeScroll;
        case 6:  return DalaNodeTypeWebView;
        case 7:  return DalaNodeTypeBox;
        case 8:  return DalaNodeTypeDivider;
        case 9:  return DalaNodeTypeSpacer;
        case 10: return DalaNodeTypeProgress;
        case 11: return DalaNodeTypeTextField;
        case 12: return DalaNodeTypeToggle;
        case 13: return DalaNodeTypeSlider;
        case 14: return DalaNodeTypeLazyList;
        case 15: return DalaNodeTypeTabBar;
        case 16: return DalaNodeTypeVideo;
        case 17: return DalaNodeTypeCameraPreview;
        case 18: return DalaNodeTypeNativeView;
        case 19: return DalaNodeTypeIcon;
        case 20: return DalaNodeTypeModal;
        case 21: return DalaNodeTypePressable;
        case 22: return DalaNodeTypeSafeArea;
        case 23: return DalaNodeTypeCard;
        case 24: return DalaNodeTypeBadge;
        case 25: return DalaNodeTypeChip;
        case 26: return DalaNodeTypeSnackbar;
        case 27: return DalaNodeTypeFab;
        case 28: return DalaNodeTypeIconButton;
        case 29: return DalaNodeTypeSegmentedButton;
        case 30: return DalaNodeTypeAppBar;
        case 31: return DalaNodeTypeNavBar;
        case 32: return DalaNodeTypeNavDrawer;
        case 33: return DalaNodeTypeNavRail;
        case 34: return DalaNodeTypeMenu;
        case 35: return DalaNodeTypeDatePicker;
        case 36: return DalaNodeTypeTimePicker;
        case 37: return DalaNodeTypeSearchBar;
        case 38: return DalaNodeTypeCarousel;
        case 39: return DalaNodeTypeBottomSheet;
        case 40: return DalaNodeTypeTooltip;
        case 41: return DalaNodeTypeCheckbox;
        case 42: return DalaNodeTypeRadio;
        case 43: return DalaNodeTypeActivityIndicator;
        case 44: return DalaNodeTypeRefreshControl;
        case 45: return DalaNodeTypeStatusBar;
        default: return DalaNodeTypeColumn;
    }
}

+ (void)decodeField:(uint8_t)tag bytes:(const UInt8 *)bytes length:(NSUInteger)length index:(NSUInteger *)i toNode:(DalaNode *)node {
    switch (tag) {
        case 1: { // text
            if (*i + 2 > length) return;
            uint16_t len = (uint16_t)(bytes[*i] | (bytes[*i+1] << 8));
            *i += 2;
            if (*i + len > length) return;
            node.text = [[NSString alloc] initWithBytes:bytes + *i length:len encoding:NSUTF8StringEncoding];
            *i += len;
            break;
        }
        case 2: { // title
            if (*i + 2 > length) return;
            uint16_t len = (uint16_t)(bytes[*i] | (bytes[*i+1] << 8));
            *i += 2;
            if (*i + len > length) return;
            node.text = [[NSString alloc] initWithBytes:bytes + *i length:len encoding:NSUTF8StringEncoding];
            *i += len;
            break;
        }
        case 3: { // color
            if (*i + 2 > length) return;
            uint16_t len = (uint16_t)(bytes[*i] | (bytes[*i+1] << 8));
            *i += 2;
            if (*i + len > length) return;
            NSString *hex = [[NSString alloc] initWithBytes:bytes + *i length:len encoding:NSUTF8StringEncoding];
            node.textColor = [self colorFromHex:hex];
            *i += len;
            break;
        }
        case 4: { // background
            if (*i + 2 > length) return;
            uint16_t len = (uint16_t)(bytes[*i] | (bytes[*i+1] << 8));
            *i += 2;
            if (*i + len > length) return;
            NSString *hex = [[NSString alloc] initWithBytes:bytes + *i length:len encoding:NSUTF8StringEncoding];
            node.backgroundColor = [self colorFromHex:hex];
            *i += len;
            break;
        }
        case 6: { // width
            if (*i + 4 > length) return;
            float val;
            memcpy(&val, bytes + *i, 4);
            node.fixedWidth = val;
            *i += 4;
            break;
        }
        case 7: { // height
            if (*i + 4 > length) return;
            float val;
            memcpy(&val, bytes + *i, 4);
            node.fixedHeight = val;
            *i += 4;
            break;
        }
        case 8: { // padding
            if (*i + 4 > length) return;
            float val;
            memcpy(&val, bytes + *i, 4);
            node.padding = val;
            *i += 4;
            break;
        }
        case 9: { // flex_grow
            if (*i + 4 > length) return;
            // skip — not used on native side yet
            *i += 4;
            break;
        }
        case 10: { // flex_direction
            if (*i + 1 > length) return;
            // skip — node type already determines direction
            *i += 1;
            break;
        }
        case 11: { // justify_content
            if (*i + 1 > length) return;
            node.justifyContent = bytes[*i];
            *i += 1;
            break;
        }
        case 12: { // align_items
            if (*i + 1 > length) return;
            node.alignItems = bytes[*i];
            *i += 1;
            break;
        }
        case 13: { // thickness
            if (*i + 4 > length) return;
            float val;
            memcpy(&val, bytes + *i, 4);
            node.thickness = val;
            *i += 4;
            break;
        }
        case 14: { // fixed_size
            if (*i + 4 > length) return;
            float val;
            memcpy(&val, bytes + *i, 4);
            node.fixedSize = val;
            *i += 4;
            break;
        }
        default:
            break;
    }
}

+ (UIColor *)colorFromHex:(NSString *)hex {
    if (![hex hasPrefix:@"#"]) return nil;
    NSString *clean = [hex substringFromIndex:1];

    // Validate hex string length (expect 6 characters: RRGGBB)
    if (clean.length != 6) {
        NSLog(@"[Dala] Invalid hex color: %@ (expected 6 chars, got %lu)", hex, (unsigned long)clean.length);
        return nil;
    }

    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:clean];
    [scanner scanHexInt:&rgb];
    return [UIColor colorWithRed:((rgb>>16)&0xFF)/255.0 green:((rgb>>8)&0xFF)/255.0 blue:(rgb&0xFF)/255.0 alpha:1.0];
}

@end
