// Binary protocol v3 for Dala patch transmission
//
// ── Version 3 (current) ──────────────────────────────────────────────
// Header: [0xDA][0xA1][u16 version=3][u16 patch_count]
//
// Opcodes:
//   0x00 = FRAME_BEGIN   (batching marker)
//   0x01 = CREATE_NODE   [u64 id][u64 parent][u32 index][u8 type][u64 layout_hash][PROPS][u32 children_count][child_ids...]
//   0x02 = REMOVE        [u64 id]
//   0x03 = UPDATE        [u64 id][PROPS]
//   0x04 = PATCH_NODE    [u64 id][u16 field_mask][changed fields only]
//   0x05 = REGISTER_STRING [u16 string_id][u16 len][bytes...]
//   0x06 = SET_TEXT      [u64 id][u16 len][bytes...]
//   0x07 = SET_STYLE     [u64 id][PROPS]
//   0x08 = EVENT         [u64 target_id][u8 event_type][u64 timestamp][u16 payload_len][payload_bytes]
//   0xFF = FRAME_END     (batching marker)
//
// PROPS format (v3):
//   [u8 field_count]
//     repeat:
//       [u8 tag][value...]
//   Interned string fields:
//     13 = text interned    [u16 string_id]
//     14 = title interned   [u16 string_id]
//     15 = color interned   [u16 string_id]
//     16 = background interned [u16 string_id]
//
// Field mask for PATCH_NODE (16-bit bitmask):
//   bit 0  = field 1  (text)
//   bit 1  = field 2  (title)
//   bit 2  = field 3  (color)
//   bit 3  = field 4  (background)
//   bit 4  = field 5  (on_tap)
//   bit 5  = field 6  (width)
//   bit 6  = field 7  (height)
//   bit 7  = field 8  (padding)
//   bit 8  = field 9  (flex_grow)
//   bit 9  = field 10 (flex_direction)
//   bit 10 = field 11 (justify_content)
//   bit 11 = field 12 (align_items)
//
// Event types:
//   0 = CLICK
//   1 = SCROLL
//   2 = DRAG
//   3 = TEXT_INPUT
//   4 = FOCUS
//   5 = KEYBOARD

use std::collections::HashMap;

// ── Constants ─────────────────────────────────────────────────────────

// Protocol version
pub const VERSION: u16 = 3;

// Magic bytes for v3 header
pub const MAGIC_BYTE_0: u8 = 0xDA;
pub const MAGIC_BYTE_1: u8 = 0xA1;

// Opcodes (v3)
pub const OP_FRAME_BEGIN: u8 = 0x00;
pub const OP_CREATE_NODE: u8 = 0x01;
pub const OP_REMOVE: u8 = 0x02;
pub const OP_UPDATE: u8 = 0x03;
pub const OP_PATCH_NODE: u8 = 0x04;
pub const OP_REGISTER_STRING: u8 = 0x05;
pub const OP_SET_TEXT: u8 = 0x06;
pub const OP_SET_STYLE: u8 = 0x07;
pub const OP_EVENT: u8 = 0x08;
pub const OP_FRAME_END: u8 = 0xFF;

// Node type tags (u8)
pub const NODE_COLUMN: u8 = 0;
pub const NODE_ROW: u8 = 1;
pub const NODE_TEXT: u8 = 2;
pub const NODE_BUTTON: u8 = 3;
pub const NODE_IMAGE: u8 = 4;
pub const NODE_SCROLL: u8 = 5;
pub const NODE_WEBVIEW: u8 = 6;

// Prop field tags (u8)
pub const FIELD_TEXT: u8 = 1;
pub const FIELD_TITLE: u8 = 2;
pub const FIELD_COLOR: u8 = 3;
pub const FIELD_BACKGROUND: u8 = 4;
pub const FIELD_ON_TAP: u8 = 5;
pub const FIELD_WIDTH: u8 = 6;
pub const FIELD_HEIGHT: u8 = 7;
pub const FIELD_PADDING: u8 = 8;
pub const FIELD_FLEX_GROW: u8 = 9;
pub const FIELD_FLEX_DIRECTION: u8 = 10;
pub const FIELD_JUSTIFY_CONTENT: u8 = 11;
pub const FIELD_ALIGN_ITEMS: u8 = 12;

// Interned string field tags (v3)
pub const FIELD_TEXT_INTERNED: u8 = 13;
pub const FIELD_TITLE_INTERNED: u8 = 14;
pub const FIELD_COLOR_INTERNED: u8 = 15;
pub const FIELD_BACKGROUND_INTERNED: u8 = 16;

// Event types (v3)
#[allow(dead_code)]
pub const EVENT_CLICK: u8 = 0;
#[allow(dead_code)]
pub const EVENT_SCROLL: u8 = 1;
#[allow(dead_code)]
pub const EVENT_DRAG: u8 = 2;
#[allow(dead_code)]
pub const EVENT_TEXT_INPUT: u8 = 3;
#[allow(dead_code)]
pub const EVENT_FOCUS: u8 = 4;
#[allow(dead_code)]
pub const EVENT_KEYBOARD: u8 = 5;

// Flex direction values
#[allow(dead_code)]
pub const FLEX_COLUMN: u8 = 0;
pub const FLEX_ROW: u8 = 1;

// Justify content values
#[allow(dead_code)]
pub const JUSTIFY_START: u8 = 0;
pub const JUSTIFY_CENTER: u8 = 1;
pub const JUSTIFY_END: u8 = 2;
pub const JUSTIFY_SPACE_BETWEEN: u8 = 3;

// Align items values
#[allow(dead_code)]
pub const ALIGN_START: u8 = 0;
pub const ALIGN_CENTER: u8 = 1;
pub const ALIGN_END: u8 = 2;
pub const ALIGN_STRETCH: u8 = 3;

// ── String Interning Table ────────────────────────────────────────────

/// A string interning table that persists across decode calls.
/// Maps string_id (u16) → String for efficient repeated string references.
#[derive(Debug, Clone, Default)]
pub struct StringTable {
    strings: HashMap<u16, String>,
}

impl StringTable {
    pub fn new() -> Self {
        StringTable {
            strings: HashMap::new(),
        }
    }

    pub fn register(&mut self, id: u16, s: String) {
        self.strings.insert(id, s);
    }

    pub fn get(&self, id: u16) -> Option<&String> {
        self.strings.get(&id)
    }

    #[allow(dead_code)]
    pub fn clear(&mut self) {
        self.strings.clear();
    }
}

// ── Read helpers (little-endian) ──────────────────────────────────────

#[allow(dead_code)]
pub fn read_u8(bytes: &[u8], i: &mut usize) -> u8 {
    let val = bytes[*i];
    *i += 1;
    val
}

pub fn read_u16(bytes: &[u8], i: &mut usize) -> u16 {
    let mut arr = [0u8; 2];
    arr.copy_from_slice(&bytes[*i..*i + 2]);
    *i += 2;
    u16::from_le_bytes(arr)
}

pub fn read_u32(bytes: &[u8], i: &mut usize) -> u32 {
    let mut arr = [0u8; 4];
    arr.copy_from_slice(&bytes[*i..*i + 4]);
    *i += 4;
    u32::from_le_bytes(arr)
}

pub fn read_u64(bytes: &[u8], i: &mut usize) -> u64 {
    let mut arr = [0u8; 8];
    arr.copy_from_slice(&bytes[*i..*i + 8]);
    *i += 8;
    u64::from_le_bytes(arr)
}

pub fn read_f32(bytes: &[u8], i: &mut usize) -> f32 {
    let mut arr = [0u8; 4];
    arr.copy_from_slice(&bytes[*i..*i + 4]);
    *i += 4;
    f32::from_le_bytes(arr)
}

/// Read an inline string: [u16 len][bytes...]
pub fn read_string_inline(bytes: &[u8], i: &mut usize) -> String {
    let len = read_u16(bytes, i) as usize;
    let s = String::from_utf8_lossy(&bytes[*i..*i + len]).into_owned();
    *i += len;
    s
}

/// Read a LEB128 varint (unsigned) from the byte stream.
#[allow(dead_code)]
pub fn read_varint(bytes: &[u8], i: &mut usize) -> u64 {
    let mut result: u64 = 0;
    let mut shift: u32 = 0;
    loop {
        if *i >= bytes.len() {
            break;
        }
        let byte = bytes[*i];
        *i += 1;
        result |= ((byte & 0x7F) as u64) << shift;
        if byte & 0x80 == 0 {
            break;
        }
        shift += 7;
        if shift >= 64 {
            break;
        }
    }
    result
}

// ── Decode ────────────────────────────────────────────────────────────

/// Decode props for v3 protocol, supporting interned string fields.
fn decode_props_v3(bytes: &[u8], i: &mut usize, string_table: &StringTable) -> super::tree::Props {
    let field_count = bytes[*i];
    *i += 1;

    let mut props = super::tree::Props::default();

    for _ in 0..field_count {
        let tag = bytes[*i];
        *i += 1;

        match tag {
            FIELD_TEXT => {
                props.text = Some(read_string_inline(bytes, i));
            }
            FIELD_TITLE => {
                props.title = Some(read_string_inline(bytes, i));
            }
            FIELD_COLOR => {
                props.color = Some(read_string_inline(bytes, i));
            }
            FIELD_BACKGROUND => {
                props.background = Some(read_string_inline(bytes, i));
            }
            FIELD_TEXT_INTERNED => {
                let string_id = read_u16(bytes, i);
                if let Some(s) = string_table.get(string_id) {
                    props.text = Some(s.clone());
                } else {
                    eprintln!("[Dala] Unknown interned string id: {}", string_id);
                }
            }
            FIELD_TITLE_INTERNED => {
                let string_id = read_u16(bytes, i);
                if let Some(s) = string_table.get(string_id) {
                    props.title = Some(s.clone());
                } else {
                    eprintln!("[Dala] Unknown interned string id: {}", string_id);
                }
            }
            FIELD_COLOR_INTERNED => {
                let string_id = read_u16(bytes, i);
                if let Some(s) = string_table.get(string_id) {
                    props.color = Some(s.clone());
                } else {
                    eprintln!("[Dala] Unknown interned string id: {}", string_id);
                }
            }
            FIELD_BACKGROUND_INTERNED => {
                let string_id = read_u16(bytes, i);
                if let Some(s) = string_table.get(string_id) {
                    props.background = Some(s.clone());
                } else {
                    eprintln!("[Dala] Unknown interned string id: {}", string_id);
                }
            }
            FIELD_ON_TAP => {
                props.on_tap = Some(read_u64(bytes, i));
            }
            FIELD_WIDTH => {
                props.width = Some(read_f32(bytes, i));
            }
            FIELD_HEIGHT => {
                props.height = Some(read_f32(bytes, i));
            }
            FIELD_PADDING => {
                props.padding = Some(read_f32(bytes, i));
            }
            FIELD_FLEX_GROW => {
                props.flex_grow = Some(read_f32(bytes, i));
            }
            FIELD_FLEX_DIRECTION => {
                props.flex_direction = match bytes[*i] {
                    FLEX_ROW => super::tree::FlexDirection::Row,
                    _ => super::tree::FlexDirection::Column,
                };
                *i += 1;
            }
            FIELD_JUSTIFY_CONTENT => {
                props.justify_content = match bytes[*i] {
                    JUSTIFY_CENTER => super::tree::JustifyContent::Center,
                    JUSTIFY_END => super::tree::JustifyContent::End,
                    JUSTIFY_SPACE_BETWEEN => super::tree::JustifyContent::SpaceBetween,
                    _ => super::tree::JustifyContent::Start,
                };
                *i += 1;
            }
            FIELD_ALIGN_ITEMS => {
                props.align_items = match bytes[*i] {
                    ALIGN_CENTER => super::tree::AlignItems::Center,
                    ALIGN_END => super::tree::AlignItems::End,
                    ALIGN_STRETCH => super::tree::AlignItems::Stretch,
                    _ => super::tree::AlignItems::Start,
                };
                *i += 1;
            }
            _ => {
                eprintln!("[Dala] Unknown prop field tag: {}", tag);
            }
        }
    }

    props
}

/// Decode a binary frame and apply patches to the tree (v3 protocol only).
/// Expects the magic header [0xDA][0xA1] and version 3.
pub fn decode_and_apply(tree: &mut super::tree::Tree, bytes: &[u8]) -> Result<(), String> {
    if bytes.len() < 6 {
        return Err(format!(
            "Input too short for v3 header: {} bytes",
            bytes.len()
        ));
    }

    // Validate magic header
    if bytes[0] != MAGIC_BYTE_0 || bytes[1] != MAGIC_BYTE_1 {
        return Err("Invalid magic header: expected [0xDA][0xA1]".to_string());
    }

    let mut i = 2;
    let version = read_u16(bytes, &mut i);
    if version != VERSION {
        return Err(format!(
            "Unsupported protocol version: {} (expected {})",
            version, VERSION
        ));
    }

    let patch_count = read_u16(bytes, &mut i) as usize;

    // String interning table for this decode session
    let mut string_table = StringTable::new();

    for n in 0..patch_count {
        if i >= bytes.len() {
            return Err(format!("Unexpected end of input at patch {}", n));
        }

        let opcode = bytes[i];
        i += 1;

        match opcode {
            OP_FRAME_BEGIN => {
                // Frame begin is a no-op marker; just continue
            }
            OP_FRAME_END => {
                // Frame end is a no-op marker; just continue
            }
            OP_CREATE_NODE => {
                if i + 20 > bytes.len() {
                    return Err(format!("CREATE_NODE patch {} truncated", n));
                }
                let id = read_u64(bytes, &mut i);
                let parent = read_u64(bytes, &mut i);
                let index = read_u32(bytes, &mut i) as usize;
                let node = decode_node_from_insert_v3(bytes, &mut i, id, &string_table);
                tree.apply_patch(super::tree::Patch::Insert {
                    parent,
                    index,
                    node,
                });
            }
            OP_REMOVE => {
                if i + 8 > bytes.len() {
                    return Err(format!("REMOVE patch {} truncated", n));
                }
                let id = read_u64(bytes, &mut i);
                tree.apply_patch(super::tree::Patch::Remove { id });
            }
            OP_UPDATE => {
                if i + 8 > bytes.len() {
                    return Err(format!("UPDATE patch {} truncated", n));
                }
                let id = read_u64(bytes, &mut i);
                let props = decode_props_v3(bytes, &mut i, &string_table);
                tree.apply_patch(super::tree::Patch::UpdateProps { id, props });
            }
            OP_PATCH_NODE => {
                if i + 10 > bytes.len() {
                    return Err(format!("PATCH_NODE patch {} truncated", n));
                }
                let id = read_u64(bytes, &mut i);
                let field_mask = read_u16(bytes, &mut i);
                let props = decode_field_mask_props(bytes, &mut i, field_mask, &string_table);

                // Merge with existing props
                if let Some(node) = tree.nodes.get(&id) {
                    let mut merged = node.props.clone();
                    if props.text.is_some() {
                        merged.text = props.text;
                    }
                    if props.title.is_some() {
                        merged.title = props.title;
                    }
                    if props.color.is_some() {
                        merged.color = props.color;
                    }
                    if props.background.is_some() {
                        merged.background = props.background;
                    }
                    if props.on_tap.is_some() {
                        merged.on_tap = props.on_tap;
                    }
                    if props.width.is_some() {
                        merged.width = props.width;
                    }
                    if props.height.is_some() {
                        merged.height = props.height;
                    }
                    if props.padding.is_some() {
                        merged.padding = props.padding;
                    }
                    if props.flex_grow.is_some() {
                        merged.flex_grow = props.flex_grow;
                    }
                    // For enum fields, always apply from the patch
                    merged.flex_direction = props.flex_direction;
                    merged.justify_content = props.justify_content;
                    merged.align_items = props.align_items;
                    tree.apply_patch(super::tree::Patch::UpdateProps { id, props: merged });
                } else {
                    eprintln!("[Dala] PATCH_NODE: node {} not found", id);
                }
            }
            OP_REGISTER_STRING => {
                if i + 4 > bytes.len() {
                    return Err(format!("REGISTER_STRING patch {} truncated", n));
                }
                let string_id = read_u16(bytes, &mut i);
                let s = read_string_inline(bytes, &mut i);
                string_table.register(string_id, s);
            }
            OP_SET_TEXT => {
                if i + 10 > bytes.len() {
                    return Err(format!("SET_TEXT patch {} truncated", n));
                }
                let id = read_u64(bytes, &mut i);
                let text = read_string_inline(bytes, &mut i);

                if let Some(node) = tree.nodes.get(&id) {
                    let mut props = node.props.clone();
                    props.text = Some(text);
                    tree.apply_patch(super::tree::Patch::UpdateProps { id, props });
                } else {
                    eprintln!("[Dala] SET_TEXT: node {} not found", id);
                }
            }
            OP_SET_STYLE => {
                if i + 8 > bytes.len() {
                    return Err(format!("SET_STYLE patch {} truncated", n));
                }
                let id = read_u64(bytes, &mut i);
                let new_props = decode_props_v3(bytes, &mut i, &string_table);

                if let Some(node) = tree.nodes.get(&id) {
                    let mut merged = node.props.clone();
                    // Only override fields that were explicitly set in the style update
                    if new_props.text.is_some() {
                        merged.text = new_props.text;
                    }
                    if new_props.title.is_some() {
                        merged.title = new_props.title;
                    }
                    if new_props.color.is_some() {
                        merged.color = new_props.color;
                    }
                    if new_props.background.is_some() {
                        merged.background = new_props.background;
                    }
                    if new_props.on_tap.is_some() {
                        merged.on_tap = new_props.on_tap;
                    }
                    if new_props.width.is_some() {
                        merged.width = new_props.width;
                    }
                    if new_props.height.is_some() {
                        merged.height = new_props.height;
                    }
                    if new_props.padding.is_some() {
                        merged.padding = new_props.padding;
                    }
                    if new_props.flex_grow.is_some() {
                        merged.flex_grow = new_props.flex_grow;
                    }
                    merged.flex_direction = new_props.flex_direction;
                    merged.justify_content = new_props.justify_content;
                    merged.align_items = new_props.align_items;
                    tree.apply_patch(super::tree::Patch::UpdateProps { id, props: merged });
                } else {
                    eprintln!("[Dala] SET_STYLE: node {} not found", id);
                }
            }
            OP_EVENT => {
                if i + 19 > bytes.len() {
                    return Err(format!("EVENT patch {} truncated", n));
                }
                let _target_id = read_u64(bytes, &mut i);
                let _event_type = read_u8(bytes, &mut i);
                let _timestamp = read_u64(bytes, &mut i);
                let payload_len = read_u16(bytes, &mut i) as usize;
                if i + payload_len > bytes.len() {
                    return Err(format!("EVENT patch {} payload truncated", n));
                }
                // Skip payload bytes — events are consumed but not applied to the tree
                i += payload_len;
            }
            _ => {
                return Err(format!(
                    "Unknown v3 opcode: 0x{:02x} at patch {}",
                    opcode, n
                ));
            }
        }
    }

    Ok(())
}

/// Decode field-masked props for PATCH_NODE opcode.
/// The field_mask is a 16-bit bitmask where bit N corresponds to field tag (N+1).
/// Only fields whose bits are set are present in the data.
fn decode_field_mask_props(
    bytes: &[u8],
    i: &mut usize,
    field_mask: u16,
    string_table: &StringTable,
) -> super::tree::Props {
    let mut props = super::tree::Props::default();

    // bit 0 = field 1 (text)
    if field_mask & (1 << 0) != 0 {
        // Check if next byte is an interned string tag
        if *i < bytes.len() && bytes[*i] == FIELD_TEXT_INTERNED {
            *i += 1;
            let string_id = read_u16(bytes, i);
            if let Some(s) = string_table.get(string_id) {
                props.text = Some(s.clone());
            }
        } else {
            props.text = Some(read_string_inline(bytes, i));
        }
    }
    // bit 1 = field 2 (title)
    if field_mask & (1 << 1) != 0 {
        if *i < bytes.len() && bytes[*i] == FIELD_TITLE_INTERNED {
            *i += 1;
            let string_id = read_u16(bytes, i);
            if let Some(s) = string_table.get(string_id) {
                props.title = Some(s.clone());
            }
        } else {
            props.title = Some(read_string_inline(bytes, i));
        }
    }
    // bit 2 = field 3 (color)
    if field_mask & (1 << 2) != 0 {
        if *i < bytes.len() && bytes[*i] == FIELD_COLOR_INTERNED {
            *i += 1;
            let string_id = read_u16(bytes, i);
            if let Some(s) = string_table.get(string_id) {
                props.color = Some(s.clone());
            }
        } else {
            props.color = Some(read_string_inline(bytes, i));
        }
    }
    // bit 3 = field 4 (background)
    if field_mask & (1 << 3) != 0 {
        if *i < bytes.len() && bytes[*i] == FIELD_BACKGROUND_INTERNED {
            *i += 1;
            let string_id = read_u16(bytes, i);
            if let Some(s) = string_table.get(string_id) {
                props.background = Some(s.clone());
            }
        } else {
            props.background = Some(read_string_inline(bytes, i));
        }
    }
    // bit 4 = field 5 (on_tap)
    if field_mask & (1 << 4) != 0 {
        props.on_tap = Some(read_u64(bytes, i));
    }
    // bit 5 = field 6 (width)
    if field_mask & (1 << 5) != 0 {
        props.width = Some(read_f32(bytes, i));
    }
    // bit 6 = field 7 (height)
    if field_mask & (1 << 6) != 0 {
        props.height = Some(read_f32(bytes, i));
    }
    // bit 7 = field 8 (padding)
    if field_mask & (1 << 7) != 0 {
        props.padding = Some(read_f32(bytes, i));
    }
    // bit 8 = field 9 (flex_grow)
    if field_mask & (1 << 8) != 0 {
        props.flex_grow = Some(read_f32(bytes, i));
    }
    // bit 9 = field 10 (flex_direction)
    if field_mask & (1 << 9) != 0 {
        props.flex_direction = match bytes[*i] {
            FLEX_ROW => super::tree::FlexDirection::Row,
            _ => super::tree::FlexDirection::Column,
        };
        *i += 1;
    }
    // bit 10 = field 11 (justify_content)
    if field_mask & (1 << 10) != 0 {
        props.justify_content = match bytes[*i] {
            JUSTIFY_CENTER => super::tree::JustifyContent::Center,
            JUSTIFY_END => super::tree::JustifyContent::End,
            JUSTIFY_SPACE_BETWEEN => super::tree::JustifyContent::SpaceBetween,
            _ => super::tree::JustifyContent::Start,
        };
        *i += 1;
    }
    // bit 11 = field 12 (align_items)
    if field_mask & (1 << 11) != 0 {
        props.align_items = match bytes[*i] {
            ALIGN_CENTER => super::tree::AlignItems::Center,
            ALIGN_END => super::tree::AlignItems::End,
            ALIGN_STRETCH => super::tree::AlignItems::Stretch,
            _ => super::tree::AlignItems::Start,
        };
        *i += 1;
    }

    props
}

/// Decode node fields for CREATE_NODE (v3): the id is already read from the wire,
/// so we read [type:u8][u64 layout_hash][PROPS][u32 children_count][child_ids...]
fn decode_node_from_insert_v3(
    bytes: &[u8],
    i: &mut usize,
    id: u64,
    string_table: &StringTable,
) -> super::tree::Node {
    let kind = match bytes[*i] {
        NODE_COLUMN => super::tree::NodeKind::Column,
        NODE_ROW => super::tree::NodeKind::Row,
        NODE_TEXT => super::tree::NodeKind::Text,
        NODE_BUTTON => super::tree::NodeKind::Button,
        NODE_IMAGE => super::tree::NodeKind::Image,
        NODE_SCROLL => super::tree::NodeKind::Scroll,
        NODE_WEBVIEW => super::tree::NodeKind::WebView,
        _ => {
            eprintln!("[Dala] Unknown node type: {}", bytes[*i]);
            super::tree::NodeKind::Column
        }
    };
    *i += 1;

    // Read layout_hash
    let layout_hash = read_u64(bytes, i);

    let props = decode_props_v3(bytes, i, string_table);

    let children_count = read_u32(bytes, i) as usize;
    let mut children = Vec::with_capacity(children_count);
    for _ in 0..children_count {
        children.push(read_u64(bytes, i));
    }

    super::tree::Node {
        id,
        kind,
        props,
        parent: None,
        children,
        layout: super::tree::Layout::default(),
        dirty_layout: true,
        dirty_paint: true,
        layout_hash,
    }
}

/// Decode a full tree binary (v3) and replace the retained tree.
/// Expects the magic header [0xDA][0xA1] and version 3.
/// Format: [0xDA][0xA1][u16 version=3][u16 flags][u64 node_count] + node data
pub fn decode_full_tree(tree: &mut super::tree::Tree, bytes: &[u8]) {
    if bytes.len() < 16 {
        eprintln!("[Dala] Full tree binary too short: {} bytes", bytes.len());
        return;
    }

    // Validate magic header
    if bytes[0] != MAGIC_BYTE_0 || bytes[1] != MAGIC_BYTE_1 {
        eprintln!("[Dala] Invalid magic header in full tree binary");
        return;
    }

    let mut i = 2;
    let version = read_u16(bytes, &mut i);
    if version != VERSION {
        eprintln!(
            "[Dala] Expected full tree version {}, got {}",
            VERSION, version
        );
        return;
    }

    let _flags = read_u16(bytes, &mut i);
    let _node_count = read_u64(bytes, &mut i);

    // Clear the existing tree and rebuild from the binary
    tree.clear();

    // String table for full tree
    let string_table = StringTable::new();

    // Decode nodes recursively
    if i < bytes.len() {
        match decode_tree_node_v3(bytes, &mut i, &string_table) {
            Some(node) => {
                tree.set_root(node);
            }
            None => {
                eprintln!("[Dala] Failed to decode root node from full tree binary");
            }
        }
    }
}

/// Decode a single tree node and its children from the full tree binary (v3).
/// v3 node format: [u64 id][u8 type][u64 layout_hash][PROPS][u32 children_count][child_ids...]
fn decode_tree_node_v3(
    bytes: &[u8],
    i: &mut usize,
    string_table: &StringTable,
) -> Option<super::tree::Node> {
    if *i + 17 > bytes.len() {
        return None;
    }

    let id = read_u64(bytes, i);
    let kind_byte = bytes[*i];
    *i += 1;

    let kind = match kind_byte {
        NODE_COLUMN => super::tree::NodeKind::Column,
        NODE_ROW => super::tree::NodeKind::Row,
        NODE_TEXT => super::tree::NodeKind::Text,
        NODE_BUTTON => super::tree::NodeKind::Button,
        NODE_IMAGE => super::tree::NodeKind::Image,
        NODE_SCROLL => super::tree::NodeKind::Scroll,
        NODE_WEBVIEW => super::tree::NodeKind::WebView,
        _ => {
            eprintln!("[Dala] Unknown node kind: 0x{:02x}", kind_byte);
            return None;
        }
    };

    // Read layout_hash
    let layout_hash = read_u64(bytes, i);

    let props = decode_props_v3(bytes, i, string_table);

    if *i + 4 > bytes.len() {
        return None;
    }
    let child_count = read_u32(bytes, i) as usize;

    let mut child_ids = Vec::with_capacity(child_count);
    for _ in 0..child_count {
        if *i + 8 > bytes.len() {
            return None;
        }
        child_ids.push(read_u64(bytes, i));
    }

    // Decode child nodes recursively
    for _ in 0..child_count {
        match decode_tree_node_v3(bytes, i, string_table) {
            Some(_child) => {
                // Child is added to the tree via set_root recursion
            }
            None => return None,
        }
    }

    Some(super::tree::Node {
        id,
        kind,
        props,
        parent: None,
        children: child_ids,
        layout: super::tree::Layout::default(),
        dirty_layout: true,
        dirty_paint: true,
        layout_hash,
    })
}

// ── Tests ──────────────────────────────────────────────────────────────
#[cfg(test)]
mod tests {
    use super::*;
    use crate::tree::{Node, NodeKind, Props, Tree};

    // Helper to create a simple tree for testing
    fn make_tree() -> Tree {
        Tree::new()
    }

    // ═══════════════════════════════════════════════════════════════════
    // Original v1 tests (backward compatibility)
    // ═══════════════════════════════════════════════════════════════════

    #[test]
    fn test_read_u8() {
        let bytes = vec![0xAB];
        let mut i = 0;
        assert_eq!(read_u8(&bytes, &mut i), 0xAB);
        assert_eq!(i, 1);
    }

    #[test]
    fn test_read_u16_le() {
        let bytes = vec![0x34, 0x12]; // 0x1234 in little-endian
        let mut i = 0;
        assert_eq!(read_u16(&bytes, &mut i), 0x1234);
        assert_eq!(i, 2);
    }

    #[test]
    fn test_read_u32_le() {
        let bytes = vec![0x78, 0x56, 0x34, 0x12]; // 0x12345678
        let mut i = 0;
        assert_eq!(read_u32(&bytes, &mut i), 0x12345678);
        assert_eq!(i, 4);
    }

    #[test]
    fn test_read_u64_le() {
        let bytes = vec![0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01];
        let mut i = 0;
        assert_eq!(read_u64(&bytes, &mut i), 0x0123456789ABCDEF);
        assert_eq!(i, 8);
    }

    #[test]
    fn test_read_f32_le() {
        let bytes = 123.45f32.to_le_bytes();
        let mut i = 0;
        let val = read_f32(&bytes, &mut i);
        assert!((val - 123.45).abs() < 0.01);
        assert_eq!(i, 4);
    }

    #[test]
    fn test_read_string_inline() {
        let mut bytes = vec![];
        let s = "Hello";
        bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
        bytes.extend_from_slice(s.as_bytes());

        let mut i = 0;
        let result = read_string_inline(&bytes, &mut i);
        assert_eq!(result, "Hello");
        assert_eq!(i, 7); // 2 (len) + 5 (string)
    }
    // ═══════════════════════════════════════════════════════════════════
    // v3 protocol tests
    // ═══════════════════════════════════════════════════════════════════

    /// Helper to build a v3 header: [0xDA][0xA1][u16 version=3][u16 patch_count]
    fn v3_header(patch_count: u16) -> Vec<u8> {
        let mut bytes = vec![];
        bytes.push(MAGIC_BYTE_0);
        bytes.push(MAGIC_BYTE_1);
        bytes.extend_from_slice(&VERSION.to_le_bytes());
        bytes.extend_from_slice(&patch_count.to_le_bytes());
        bytes
    }

    #[test]
    fn test_v3_header_detection() {
        // v3 header should be detected correctly
        let bytes = v3_header(0);
        assert_eq!(bytes[0], MAGIC_BYTE_0);
        assert_eq!(bytes[1], MAGIC_BYTE_1);
        let mut i = 2;
        let version = read_u16(&bytes, &mut i);
        assert_eq!(version, VERSION);
    }

    #[test]
    fn test_v3_create_node() {
        let mut bytes = v3_header(1);

        // CREATE_NODE: id=1, parent=0, index=0, type=TEXT, layout_hash=0x1234567890ABCDEF
        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&1u64.to_le_bytes()); // id
        bytes.extend_from_slice(&0u64.to_le_bytes()); // parent
        bytes.extend_from_slice(&0u32.to_le_bytes()); // index
        bytes.push(NODE_TEXT); // type
        bytes.extend_from_slice(&0x1234567890ABCDEFu64.to_le_bytes()); // layout_hash

        // Props: 1 field
        bytes.push(1); // field_count=1
        bytes.push(FIELD_TEXT);
        let text = "Hello v3";
        bytes.extend_from_slice(&(text.len() as u16).to_le_bytes());
        bytes.extend_from_slice(text.as_bytes());

        // Children: count=0
        bytes.extend_from_slice(&0u32.to_le_bytes());

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();

        // Verify the node was inserted
        let node = tree.nodes.get(&1).unwrap();
        assert_eq!(node.id, 1);
        assert_eq!(node.kind, NodeKind::Text);
        assert_eq!(node.props.text.as_deref(), Some("Hello v3"));
        assert_eq!(node.layout_hash, 0x1234567890ABCDEF);
    }

    #[test]
    fn test_v3_frame_batching() {
        let mut bytes = v3_header(4);

        // FRAME_BEGIN
        bytes.push(OP_FRAME_BEGIN);

        // CREATE_NODE inside frame
        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&1u64.to_le_bytes()); // id
        bytes.extend_from_slice(&0u64.to_le_bytes()); // parent
        bytes.extend_from_slice(&0u32.to_le_bytes()); // index
        bytes.push(NODE_TEXT); // type
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(0); // no props
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        // REMOVE inside frame
        bytes.push(OP_REMOVE);
        bytes.extend_from_slice(&2u64.to_le_bytes());

        // FRAME_END
        bytes.push(OP_FRAME_END);

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();
    }

    #[test]
    fn test_v3_patch_node_field_mask() {
        // First, insert a node
        let mut bytes = v3_header(2);

        // CREATE_NODE: id=10, parent=0, index=0
        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&10u64.to_le_bytes()); // id
        bytes.extend_from_slice(&0u64.to_le_bytes()); // parent
        bytes.extend_from_slice(&0u32.to_le_bytes()); // index
        bytes.push(NODE_TEXT); // type
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(2); // field_count=2
        bytes.push(FIELD_TEXT);
        let text = "Original";
        bytes.extend_from_slice(&(text.len() as u16).to_le_bytes());
        bytes.extend_from_slice(text.as_bytes());
        bytes.push(FIELD_COLOR);
        let color = "red";
        bytes.extend_from_slice(&(color.len() as u16).to_le_bytes());
        bytes.extend_from_slice(color.as_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        // PATCH_NODE: id=10, field_mask=0x0001 (bit 0 = text field)
        bytes.push(OP_PATCH_NODE);
        bytes.extend_from_slice(&10u64.to_le_bytes()); // id
        bytes.extend_from_slice(&0x0001u16.to_le_bytes()); // field_mask: only text
                                                           // Only the text field is present
        let new_text = "Updated";
        bytes.extend_from_slice(&(new_text.len() as u16).to_le_bytes());
        bytes.extend_from_slice(new_text.as_bytes());

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();

        // Verify the node was patched
        let node = tree.nodes.get(&10).unwrap();
        assert_eq!(node.props.text.as_deref(), Some("Updated"));
        // Color should remain unchanged
        assert_eq!(node.props.color.as_deref(), Some("red"));
    }

    #[test]
    fn test_v3_patch_node_multiple_fields() {
        // Insert a node first
        let mut bytes = v3_header(2);

        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&20u64.to_le_bytes());
        bytes.extend_from_slice(&0u64.to_le_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes());
        bytes.push(NODE_ROW);
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(0); // no props
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        // PATCH_NODE: update width (bit 5) and height (bit 6) and padding (bit 7)
        // field_mask = (1 << 5) | (1 << 6) | (1 << 7) = 0x00E0
        bytes.push(OP_PATCH_NODE);
        bytes.extend_from_slice(&20u64.to_le_bytes());
        bytes.extend_from_slice(&0x00E0u16.to_le_bytes()); // field_mask
        bytes.extend_from_slice(&100.0f32.to_le_bytes()); // width
        bytes.extend_from_slice(&50.0f32.to_le_bytes()); // height
        bytes.extend_from_slice(&10.0f32.to_le_bytes()); // padding

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();

        let node = tree.nodes.get(&20).unwrap();
        assert_eq!(node.props.width, Some(100.0));
        assert_eq!(node.props.height, Some(50.0));
        assert_eq!(node.props.padding, Some(10.0));
    }

    #[test]
    fn test_v3_string_interning() {
        let mut bytes = v3_header(3);

        // REGISTER_STRING: string_id=1, "Hello World"
        bytes.push(OP_REGISTER_STRING);
        bytes.extend_from_slice(&1u16.to_le_bytes()); // string_id
        let s1 = "Hello World";
        bytes.extend_from_slice(&(s1.len() as u16).to_le_bytes());
        bytes.extend_from_slice(s1.as_bytes());

        // REGISTER_STRING: string_id=2, "primary"
        bytes.push(OP_REGISTER_STRING);
        bytes.extend_from_slice(&2u16.to_le_bytes()); // string_id
        let s2 = "primary";
        bytes.extend_from_slice(&(s2.len() as u16).to_le_bytes());
        bytes.extend_from_slice(s2.as_bytes());

        // CREATE_NODE using interned strings
        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&100u64.to_le_bytes()); // id
        bytes.extend_from_slice(&0u64.to_le_bytes()); // parent
        bytes.extend_from_slice(&0u32.to_le_bytes()); // index
        bytes.push(NODE_TEXT); // type
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(2); // field_count=2
        bytes.push(FIELD_TEXT_INTERNED);
        bytes.extend_from_slice(&1u16.to_le_bytes()); // string_id=1
        bytes.push(FIELD_COLOR_INTERNED);
        bytes.extend_from_slice(&2u16.to_le_bytes()); // string_id=2
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();

        let node = tree.nodes.get(&100).unwrap();
        assert_eq!(node.props.text.as_deref(), Some("Hello World"));
        assert_eq!(node.props.color.as_deref(), Some("primary"));
    }

    #[test]
    fn test_v3_set_text_opcode() {
        // First insert a node
        let mut bytes = v3_header(2);

        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&50u64.to_le_bytes()); // id
        bytes.extend_from_slice(&0u64.to_le_bytes()); // parent
        bytes.extend_from_slice(&0u32.to_le_bytes()); // index
        bytes.push(NODE_TEXT); // type
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(1); // field_count=1
        bytes.push(FIELD_TEXT);
        let old_text = "Old text";
        bytes.extend_from_slice(&(old_text.len() as u16).to_le_bytes());
        bytes.extend_from_slice(old_text.as_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        // SET_TEXT: fast path for text-only update
        bytes.push(OP_SET_TEXT);
        bytes.extend_from_slice(&50u64.to_le_bytes()); // id
        let new_text = "New text";
        bytes.extend_from_slice(&(new_text.len() as u16).to_le_bytes());
        bytes.extend_from_slice(new_text.as_bytes());

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();

        let node = tree.nodes.get(&50).unwrap();
        assert_eq!(node.props.text.as_deref(), Some("New text"));
    }

    #[test]
    fn test_v3_set_style_opcode() {
        // First insert a node
        let mut bytes = v3_header(2);

        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&60u64.to_le_bytes()); // id
        bytes.extend_from_slice(&0u64.to_le_bytes()); // parent
        bytes.extend_from_slice(&0u32.to_le_bytes()); // index
        bytes.push(NODE_TEXT); // type
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(1); // field_count=1
        bytes.push(FIELD_TEXT);
        let text = "Styled text";
        bytes.extend_from_slice(&(text.len() as u16).to_le_bytes());
        bytes.extend_from_slice(text.as_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        // SET_STYLE: update only style props
        bytes.push(OP_SET_STYLE);
        bytes.extend_from_slice(&60u64.to_le_bytes()); // id
        bytes.push(3); // field_count=3
        bytes.push(FIELD_WIDTH);
        bytes.extend_from_slice(&200.0f32.to_le_bytes());
        bytes.push(FIELD_HEIGHT);
        bytes.extend_from_slice(&100.0f32.to_le_bytes());
        bytes.push(FIELD_PADDING);
        bytes.extend_from_slice(&8.0f32.to_le_bytes());

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();

        let node = tree.nodes.get(&60).unwrap();
        assert_eq!(node.props.text.as_deref(), Some("Styled text")); // preserved
        assert_eq!(node.props.width, Some(200.0)); // updated
        assert_eq!(node.props.height, Some(100.0)); // updated
        assert_eq!(node.props.padding, Some(8.0)); // updated
    }

    #[test]
    fn test_v3_event_opcode() {
        let mut bytes = v3_header(1);

        // EVENT: target_id=42, event_type=CLICK(0), timestamp=1000000, payload="click_data"
        bytes.push(OP_EVENT);
        bytes.extend_from_slice(&42u64.to_le_bytes()); // target_id
        bytes.push(EVENT_CLICK); // event_type
        bytes.extend_from_slice(&1000000u64.to_le_bytes()); // timestamp
        let payload = b"click_data";
        bytes.extend_from_slice(&(payload.len() as u16).to_le_bytes());
        bytes.extend_from_slice(payload);

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();
        // Event is consumed but not applied to the tree — just verify no error
    }

    #[test]
    fn test_v3_event_all_types() {
        let event_types = [
            EVENT_CLICK,
            EVENT_SCROLL,
            EVENT_DRAG,
            EVENT_TEXT_INPUT,
            EVENT_FOCUS,
            EVENT_KEYBOARD,
        ];

        for (idx, event_type) in event_types.iter().enumerate() {
            let mut bytes = v3_header(1);
            bytes.push(OP_EVENT);
            bytes.extend_from_slice(&(idx as u64).to_le_bytes()); // target_id
            bytes.push(*event_type);
            bytes.extend_from_slice(&1000u64.to_le_bytes()); // timestamp
            bytes.extend_from_slice(&0u16.to_le_bytes()); // payload_len=0

            let mut tree = make_tree();
            decode_and_apply(&mut tree, &bytes).unwrap();
        }
    }

    #[test]
    fn test_v3_mixed_opcodes() {
        let mut bytes = v3_header(6);

        // 1. REGISTER_STRING
        bytes.push(OP_REGISTER_STRING);
        bytes.extend_from_slice(&1u16.to_le_bytes()); // string_id
        let s = "interned_text";
        bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
        bytes.extend_from_slice(s.as_bytes());

        // 2. FRAME_BEGIN
        bytes.push(OP_FRAME_BEGIN);

        // 3. CREATE_NODE
        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&1u64.to_le_bytes()); // id
        bytes.extend_from_slice(&0u64.to_le_bytes()); // parent
        bytes.extend_from_slice(&0u32.to_le_bytes()); // index
        bytes.push(NODE_COLUMN); // type
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(1); // field_count=1
        bytes.push(FIELD_TEXT_INTERNED);
        bytes.extend_from_slice(&1u16.to_le_bytes()); // string_id=1
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        // 4. SET_TEXT
        bytes.push(OP_SET_TEXT);
        bytes.extend_from_slice(&1u64.to_le_bytes()); // id
        let new_text = "direct text";
        bytes.extend_from_slice(&(new_text.len() as u16).to_le_bytes());
        bytes.extend_from_slice(new_text.as_bytes());

        // 5. EVENT
        bytes.push(OP_EVENT);
        bytes.extend_from_slice(&1u64.to_le_bytes()); // target_id
        bytes.push(EVENT_CLICK); // event_type
        bytes.extend_from_slice(&9999u64.to_le_bytes()); // timestamp
        bytes.extend_from_slice(&0u16.to_le_bytes()); // payload_len=0

        // 6. FRAME_END
        bytes.push(OP_FRAME_END);

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();

        let node = tree.nodes.get(&1).unwrap();
        assert_eq!(node.props.text.as_deref(), Some("direct text"));
    }

    #[test]
    fn test_read_varint() {
        // Single byte: 0x00 = 0
        let bytes = vec![0x00];
        let mut i = 0;
        assert_eq!(read_varint(&bytes, &mut i), 0);
        assert_eq!(i, 1);

        // Single byte: 0x7F = 127
        let bytes = vec![0x7F];
        let mut i = 0;
        assert_eq!(read_varint(&bytes, &mut i), 127);
        assert_eq!(i, 1);

        // Two bytes: 0x80 0x01 = 128
        let bytes = vec![0x80, 0x01];
        let mut i = 0;
        assert_eq!(read_varint(&bytes, &mut i), 128);
        assert_eq!(i, 2);

        // Two bytes: 0xFF 0x01 = 255
        let bytes = vec![0xFF, 0x01];
        let mut i = 0;
        assert_eq!(read_varint(&bytes, &mut i), 255);
        assert_eq!(i, 2);

        // Larger: 300 = 0xAC 0x02
        let bytes = vec![0xAC, 0x02];
        let mut i = 0;
        assert_eq!(read_varint(&bytes, &mut i), 300);
        assert_eq!(i, 2);

        // u64 max value: 0xFFFFFFFFFFFFFFFF
        let bytes = vec![0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01];
        let mut i = 0;
        assert_eq!(read_varint(&bytes, &mut i), u64::MAX);
        assert_eq!(i, 10);
    }

    #[test]
    fn test_v3_layout_hash_in_create_node() {
        let mut bytes = v3_header(1);

        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&200u64.to_le_bytes()); // id
        bytes.extend_from_slice(&0u64.to_le_bytes()); // parent
        bytes.extend_from_slice(&0u32.to_le_bytes()); // index
        bytes.push(NODE_ROW); // type
        bytes.extend_from_slice(&0xDEADBEEFCAFEBABEu64.to_le_bytes()); // layout_hash
        bytes.push(0); // no props
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();

        let node = tree.nodes.get(&200).unwrap();
        assert_eq!(node.layout_hash, 0xDEADBEEFCAFEBABE);
    }

    #[test]
    fn test_v3_patch_node_with_interned_strings() {
        let mut bytes = v3_header(3);

        // REGISTER_STRING: string_id=10, "blue"
        bytes.push(OP_REGISTER_STRING);
        bytes.extend_from_slice(&10u16.to_le_bytes());
        let s = "blue";
        bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
        bytes.extend_from_slice(s.as_bytes());

        // CREATE_NODE
        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&300u64.to_le_bytes());
        bytes.extend_from_slice(&0u64.to_le_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes());
        bytes.push(NODE_TEXT);
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(1); // field_count=1
        bytes.push(FIELD_TEXT);
        let text = "original";
        bytes.extend_from_slice(&(text.len() as u16).to_le_bytes());
        bytes.extend_from_slice(text.as_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        // PATCH_NODE with interned background string
        // field_mask: bit 0 (text) | bit 3 (background) = 0x0009
        bytes.push(OP_PATCH_NODE);
        bytes.extend_from_slice(&300u64.to_le_bytes());
        bytes.extend_from_slice(&0x0009u16.to_le_bytes()); // field_mask
                                                           // text field (bit 0)
        let new_text = "patched";
        bytes.extend_from_slice(&(new_text.len() as u16).to_le_bytes());
        bytes.extend_from_slice(new_text.as_bytes());
        // background field (bit 3) — interned
        bytes.push(FIELD_BACKGROUND_INTERNED);
        bytes.extend_from_slice(&10u16.to_le_bytes()); // string_id=10

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();

        let node = tree.nodes.get(&300).unwrap();
        assert_eq!(node.props.text.as_deref(), Some("patched"));
        assert_eq!(node.props.background.as_deref(), Some("blue"));
    }

    #[test]
    fn test_v3_invalid_magic_header() {
        let mut bytes = vec![];
        bytes.push(0xDA);
        bytes.push(0xA1);
        bytes.extend_from_slice(&3u16.to_le_bytes()); // version=3
        bytes.extend_from_slice(&0u16.to_le_bytes()); // patch_count=0

        // This should work — valid v3 header
        let mut tree = make_tree();
        assert!(decode_and_apply(&mut tree, &bytes).is_ok());

        // Invalid magic
        let mut bad_bytes = vec![];
        bad_bytes.push(0xFF);
        bad_bytes.push(0xFF);
        bad_bytes.extend_from_slice(&3u16.to_le_bytes());
        bad_bytes.extend_from_slice(&0u16.to_le_bytes());

        // This should fail — not a valid v1 or v3 header
        // (version 0xFFFF is unknown)
        assert!(decode_and_apply(&mut tree, &bad_bytes).is_err());
    }

    #[test]
    fn test_v3_empty_patch_list() {
        let bytes = v3_header(0);
        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();
    }

    #[test]
    fn test_v3_remove_opcode() {
        // First insert, then remove
        let mut bytes = v3_header(2);

        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&500u64.to_le_bytes());
        bytes.extend_from_slice(&0u64.to_le_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes());
        bytes.push(NODE_TEXT);
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(0); // no props
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        bytes.push(OP_REMOVE);
        bytes.extend_from_slice(&500u64.to_le_bytes());

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();
        assert!(tree.nodes.get(&500).is_none());
    }

    #[test]
    fn test_v3_update_opcode() {
        let mut bytes = v3_header(2);

        // CREATE_NODE
        bytes.push(OP_CREATE_NODE);
        bytes.extend_from_slice(&600u64.to_le_bytes());
        bytes.extend_from_slice(&0u64.to_le_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes());
        bytes.push(NODE_TEXT);
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(0); // no props
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        // UPDATE with new props
        bytes.push(OP_UPDATE);
        bytes.extend_from_slice(&600u64.to_le_bytes());
        bytes.push(2); // field_count=2
        bytes.push(FIELD_TEXT);
        let text = "Updated via v3";
        bytes.extend_from_slice(&(text.len() as u16).to_le_bytes());
        bytes.extend_from_slice(text.as_bytes());
        bytes.push(FIELD_WIDTH);
        bytes.extend_from_slice(&300.0f32.to_le_bytes());

        let mut tree = make_tree();
        decode_and_apply(&mut tree, &bytes).unwrap();

        let node = tree.nodes.get(&600).unwrap();
        assert_eq!(node.props.text.as_deref(), Some("Updated via v3"));
        assert_eq!(node.props.width, Some(300.0));
    }

    #[test]
    fn test_string_table() {
        let mut table = StringTable::new();

        table.register(1, "hello".to_string());
        table.register(2, "world".to_string());

        assert_eq!(table.get(1).unwrap(), "hello");
        assert_eq!(table.get(2).unwrap(), "world");
        assert!(table.get(3).is_none());

        table.clear();
        assert!(table.get(1).is_none());
    }

    #[test]
    fn test_v3_full_tree() {
        // Build a v3 full tree binary
        let mut bytes = vec![];
        bytes.push(MAGIC_BYTE_0);
        bytes.push(MAGIC_BYTE_1);
        bytes.extend_from_slice(&VERSION.to_le_bytes());
        bytes.extend_from_slice(&0u16.to_le_bytes()); // flags
        bytes.extend_from_slice(&1u64.to_le_bytes()); // node_count

        // Root node: id=1, type=Column, layout_hash=0
        bytes.extend_from_slice(&1u64.to_le_bytes()); // id
        bytes.push(NODE_COLUMN); // type
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
                                                      // Props: 1 field
        bytes.push(1);
        bytes.push(FIELD_PADDING);
        bytes.extend_from_slice(&10.0f32.to_le_bytes());
        // Children count: 0
        bytes.extend_from_slice(&0u32.to_le_bytes());

        let mut tree = make_tree();
        decode_full_tree(&mut tree, &bytes);

        assert!(tree.root.is_some());
        let root = tree.nodes.get(&1).unwrap();
        assert_eq!(root.kind, NodeKind::Column);
        assert_eq!(root.props.padding, Some(10.0));
    }

    #[test]
    fn test_layout_hash_computation() {
        // Create a node and verify layout_hash is computed
        let node = Node {
            id: 1,
            kind: NodeKind::Column,
            props: Props {
                width: Some(100.0),
                height: Some(50.0),
                padding: Some(10.0),
                flex_grow: Some(1.0),
                ..Props::default()
            },
            parent: None,
            children: vec![2, 3],
            layout: crate::tree::Layout::default(),
            dirty_layout: true,
            dirty_paint: true,
            layout_hash: 0,
        };

        let hash = node.compute_layout_hash();
        assert_ne!(hash, 0); // Should be non-zero for a node with props

        // Same props should produce same hash
        let node2 = Node {
            id: 999, // different id shouldn't matter
            kind: NodeKind::Column,
            props: Props {
                width: Some(100.0),
                height: Some(50.0),
                padding: Some(10.0),
                flex_grow: Some(1.0),
                ..Props::default()
            },
            parent: None,
            children: vec![2, 3],
            layout: crate::tree::Layout::default(),
            dirty_layout: true,
            dirty_paint: true,
            layout_hash: 0,
        };
        assert_eq!(hash, node2.compute_layout_hash());

        // Different props should produce different hash
        let node3 = Node {
            id: 1,
            kind: NodeKind::Row, // different kind
            props: Props {
                width: Some(100.0),
                height: Some(50.0),
                padding: Some(10.0),
                flex_grow: Some(1.0),
                ..Props::default()
            },
            parent: None,
            children: vec![2, 3],
            layout: crate::tree::Layout::default(),
            dirty_layout: true,
            dirty_paint: true,
            layout_hash: 0,
        };
        assert_ne!(hash, node3.compute_layout_hash());
    }
}
