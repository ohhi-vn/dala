// Edge case tests for binary protocol v3 decoder
// Run with: cargo test --test protocol_edge_tests

// Edge case tests for binary protocol v3 decoder
// Run with: cargo test --test protocol_edge_tests

// ── Test helpers ──────────────────────────────────────────────────────

fn make_tree() -> crate::tree::Tree {
    crate::tree::Tree::new()
}

// ── Full tree edge cases ──────────────────────────────────────────────

#[test]
fn test_full_tree_single_node_no_props() {
    let mut bytes = vec![];
    bytes.push(0xDA); // MAGIC_BYTE_0
    bytes.push(0xA1); // MAGIC_BYTE_1
    bytes.extend_from_slice(&3u16.to_le_bytes()); // version
    bytes.extend_from_slice(&0u16.to_le_bytes()); // flags
    bytes.extend_from_slice(&1u64.to_le_bytes()); // node_count

    // Root: id=1, type=Text, no props, no children
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
    bytes.push(0); // field_count=0
    bytes.extend_from_slice(&0u32.to_le_bytes()); // child_count=0

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);

    assert!(tree.root.is_some());
    assert_eq!(tree.nodes.len(), 1);
    let root = tree.nodes.get(&1).unwrap();
    assert_eq!(root.kind, crate::tree::NodeKind::Text);
    assert_eq!(root.parent, None);
    assert_eq!(root.children, vec![]);
}

#[test]
fn test_full_tree_three_level_nesting() {
    // root(Column) -> mid(Row) -> leaf(Text)
    let mut bytes = vec![];
    bytes.push(0xDA);
    bytes.push(0xA1);
    bytes.extend_from_slice(&3u16.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&3u64.to_le_bytes()); // node_count=3

    // Root: id=1, Column, 1 child
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.push(36); // NODE_COLUMN
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0); // no props
    bytes.extend_from_slice(&1u32.to_le_bytes()); // child_count=1
    bytes.extend_from_slice(&2u64.to_le_bytes()); // child_id=2

    // Mid: id=2, Row, 1 child
    bytes.extend_from_slice(&2u64.to_le_bytes());
    bytes.push(37); // NODE_ROW
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0);
    bytes.extend_from_slice(&1u32.to_le_bytes());
    bytes.extend_from_slice(&3u64.to_le_bytes()); // child_id=3

    // Leaf: id=3, Text, no children
    bytes.extend_from_slice(&3u64.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(1); // field_count=1
    bytes.push(1); // FIELD_TEXT
    let text = "Deep";
    bytes.extend_from_slice(&(text.len() as u16).to_le_bytes());
    bytes.extend_from_slice(text.as_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);

    assert_eq!(tree.nodes.len(), 3);
    assert_eq!(tree.root, Some(1));

    let root = tree.nodes.get(&1).unwrap();
    assert_eq!(root.kind, crate::tree::NodeKind::Column);
    assert_eq!(root.children, vec![2]);
    assert_eq!(root.parent, None);

    let mid = tree.nodes.get(&2).unwrap();
    assert_eq!(mid.kind, crate::tree::NodeKind::Row);
    assert_eq!(mid.children, vec![3]);
    assert_eq!(mid.parent, Some(1));

    let leaf = tree.nodes.get(&3).unwrap();
    assert_eq!(leaf.kind, crate::tree::NodeKind::Text);
    assert_eq!(leaf.parent, Some(2));
    assert_eq!(leaf.children, vec![]);
}

#[test]
fn test_full_tree_wide_with_many_children() {
    // root with 5 children
    let child_count = 5u32;
    let mut bytes = vec![];
    bytes.push(0xDA);
    bytes.push(0xA1);
    bytes.extend_from_slice(&3u16.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&(child_count as u64 + 1).to_le_bytes()); // node_count

    // Root
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.push(36); // NODE_COLUMN
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0); // no props
    bytes.extend_from_slice(&child_count.to_le_bytes());
    for i in 0..child_count {
        bytes.extend_from_slice(&(i as u64 + 2).to_le_bytes());
    }

    // Children
    for i in 0..child_count {
        bytes.extend_from_slice(&(i as u64 + 2).to_le_bytes());
        bytes.push(0); // NODE_TEXT
        bytes.extend_from_slice(&0u64.to_le_bytes());
        bytes.push(0); // no props
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children
    }

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);

    assert_eq!(tree.nodes.len(), 6);
    let root = tree.nodes.get(&1).unwrap();
    assert_eq!(root.children, vec![2, 3, 4, 5, 6]);
    for i in 2..=6 {
        let child = tree.nodes.get(&i).unwrap();
        assert_eq!(child.parent, Some(1));
    }
}

#[test]
fn test_full_tree_with_all_prop_types() {
    let mut bytes = vec![];
    bytes.push(0xDA);
    bytes.push(0xA1);
    bytes.extend_from_slice(&3u16.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&1u64.to_le_bytes());

    bytes.extend_from_slice(&1u64.to_le_bytes()); // id
    bytes.push(37); // NODE_ROW
    bytes.extend_from_slice(&0u64.to_le_bytes());

    // All 12 prop fields
    bytes.push(12); // field_count

    // 1: text
    bytes.push(1); // FIELD_TEXT
    let s = "hello";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // 2: title
    bytes.push(2);
    let s = "title";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // 3: color
    bytes.push(3);
    let s = "red";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // 4: background
    bytes.push(4);
    let s = "blue";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // 5: on_tap
    bytes.push(5);
    bytes.extend_from_slice(&42u64.to_le_bytes());

    // 6: width
    bytes.push(6);
    bytes.extend_from_slice(&100.0f32.to_le_bytes());

    // 7: height
    bytes.push(7);
    bytes.extend_from_slice(&50.0f32.to_le_bytes());

    // 8: padding
    bytes.push(8);
    bytes.extend_from_slice(&10.0f32.to_le_bytes());

    // 9: flex_grow
    bytes.push(9);
    bytes.extend_from_slice(&1.5f32.to_le_bytes());

    // 10: flex_direction (row=1)
    bytes.push(10);
    bytes.push(1);

    // 11: justify_content (center=1)
    bytes.push(11);
    bytes.push(1);

    // 12: align_items (stretch=3)
    bytes.push(12);
    bytes.push(3);

    bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);

    let root = tree.nodes.get(&1).unwrap();
    assert_eq!(root.props.text.as_deref(), Some("hello"));
    assert_eq!(root.props.title.as_deref(), Some("title"));
    assert_eq!(root.props.color.as_deref(), Some("red"));
    assert_eq!(root.props.background.as_deref(), Some("blue"));
    assert_eq!(root.props.on_tap, Some(42));
    assert_eq!(root.props.width, Some(100.0));
    assert_eq!(root.props.height, Some(50.0));
    assert_eq!(root.props.padding, Some(10.0));
    assert_eq!(root.props.flex_grow, Some(1.5));
}

#[test]
fn test_full_tree_truncated_header() {
    // Only 2 bytes — too short for even magic
    let bytes = vec![0xDA, 0xA1];
    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);
    assert!(tree.root.is_none());
}

#[test]
fn test_full_tree_truncated_after_version() {
    let bytes = vec![0xDA, 0xA1, 3, 0];
    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);
    assert!(tree.root.is_none());
}

#[test]
fn test_full_tree_wrong_magic() {
    let mut bytes = vec![];
    bytes.push(0xFF);
    bytes.push(0xFF);
    bytes.extend_from_slice(&3u16.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&1u64.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);
    assert!(tree.root.is_none());
}

#[test]
fn test_full_tree_wrong_version() {
    let mut bytes = vec![];
    bytes.push(0xDA);
    bytes.push(0xA1);
    bytes.extend_from_slice(&99u16.to_le_bytes()); // wrong version
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&1u64.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);
    assert!(tree.root.is_none());
}

// ── Patch frame edge cases ────────────────────────────────────────────

#[test]
fn test_patch_truncated_create_node() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0]; // header + patch_count=1
    bytes.push(0x01); // CREATE_NODE
    bytes.extend_from_slice(&1u64.to_le_bytes()); // id
                                                  // truncated — missing parent, index, type, etc.

    let mut tree = make_tree();
    let result = crate::protocol::decode_and_apply(&mut tree, &bytes);
    assert!(result.is_err());
}

#[test]
fn test_patch_truncated_remove() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0]; // patch_count=1
    bytes.push(0x02); // REMOVE
    bytes.extend_from_slice(&1u64.to_le_bytes()); // id — but header says 1 patch, this is fine

    let mut tree = make_tree();
    let result = crate::protocol::decode_and_apply(&mut tree, &bytes);
    assert!(result.is_ok()); // REMOVE of non-existent node is silently ignored
}

#[test]
fn test_patch_truncated_update() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0];
    bytes.push(0x03); // UPDATE
    bytes.extend_from_slice(&1u64.to_le_bytes()); // id
                                                  // missing props

    let mut tree = make_tree();
    let result = crate::protocol::decode_and_apply(&mut tree, &bytes);
    assert!(result.is_err());
}

#[test]
fn test_patch_truncated_patch_node() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0];
    bytes.push(0x04); // PATCH_NODE
    bytes.extend_from_slice(&1u64.to_le_bytes()); // id
                                                  // missing field_mask

    let mut tree = make_tree();
    let result = crate::protocol::decode_and_apply(&mut tree, &bytes);
    assert!(result.is_err());
}

#[test]
fn test_patch_truncated_event_payload() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0];
    bytes.push(0x08); // EVENT
    bytes.extend_from_slice(&1u64.to_le_bytes()); // target_id
    bytes.push(0); // event_type
    bytes.extend_from_slice(&1000u64.to_le_bytes()); // timestamp
    bytes.extend_from_slice(&100u16.to_le_bytes()); // payload_len=100
    bytes.extend_from_slice(&[0u8; 10]); // only 10 bytes, not 100

    let mut tree = make_tree();
    let result = crate::protocol::decode_and_apply(&mut tree, &bytes);
    assert!(result.is_err());
}

#[test]
fn test_patch_unknown_opcode() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0];
    bytes.push(0x99); // unknown opcode

    let mut tree = make_tree();
    let result = crate::protocol::decode_and_apply(&mut tree, &bytes);
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("Unknown v3 opcode"));
}

#[test]
fn test_patch_wrong_version() {
    let mut bytes = vec![0xDA, 0xA1, 99, 0, 0, 0]; // version=99

    let mut tree = make_tree();
    let result = crate::protocol::decode_and_apply(&mut tree, &bytes);
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("Unsupported protocol version"));
}

#[test]
fn test_patch_too_short_for_header() {
    let bytes = vec![0xDA, 0xA1, 3]; // only 3 bytes
    let mut tree = make_tree();
    let result = crate::protocol::decode_and_apply(&mut tree, &bytes);
    assert!(result.is_err());
}

#[test]
fn test_patch_empty_input() {
    let bytes = vec![];
    let mut tree = make_tree();
    let result = crate::protocol::decode_and_apply(&mut tree, &bytes);
    assert!(result.is_err());
}

#[test]
fn test_patch_invalid_magic() {
    let mut bytes = vec![0xFF, 0xFF, 3, 0, 0, 0];
    let mut tree = make_tree();
    let result = crate::protocol::decode_and_apply(&mut tree, &bytes);
    assert!(result.is_err());
    assert!(result.unwrap_err().contains("Invalid magic header"));
}

// ── Round-trip: encode then decode ────────────────────────────────────

#[test]
fn test_roundtrip_single_text_node() {
    // Build a full tree binary manually, decode it, verify structure
    let mut bytes = vec![];
    bytes.push(0xDA);
    bytes.push(0xA1);
    bytes.extend_from_slice(&3u16.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&1u64.to_le_bytes());

    bytes.extend_from_slice(&42u64.to_le_bytes()); // id=42
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0xDEADBEEFu64.to_le_bytes()); // layout_hash
    bytes.push(1); // field_count=1
    bytes.push(1); // FIELD_TEXT
    let text = "Round-trip test";
    bytes.extend_from_slice(&(text.len() as u16).to_le_bytes());
    bytes.extend_from_slice(text.as_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);

    let node = tree.nodes.get(&42).unwrap();
    assert_eq!(node.kind, crate::tree::NodeKind::Text);
    assert_eq!(node.props.text.as_deref(), Some("Round-trip test"));
    assert_eq!(node.layout_hash, 0xDEADBEEF);
}

#[test]
fn test_roundtrip_parent_child_with_props() {
    // Parent: Column with padding=16.0, child: Text with text="Hello"
    let mut bytes = vec![];
    bytes.push(0xDA);
    bytes.push(0xA1);
    bytes.extend_from_slice(&3u16.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&2u64.to_le_bytes());

    // Parent
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.push(36); // NODE_COLUMN
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(1); // field_count=1
    bytes.push(8); // FIELD_PADDING
    bytes.extend_from_slice(&16.0f32.to_le_bytes());
    bytes.extend_from_slice(&1u32.to_le_bytes()); // 1 child
    bytes.extend_from_slice(&2u64.to_le_bytes()); // child_id=2

    // Child
    bytes.extend_from_slice(&2u64.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(1); // field_count=1
    bytes.push(1); // FIELD_TEXT
    let text = "Hello";
    bytes.extend_from_slice(&(text.len() as u16).to_le_bytes());
    bytes.extend_from_slice(text.as_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);

    assert_eq!(tree.nodes.len(), 2);
    let parent = tree.nodes.get(&1).unwrap();
    assert_eq!(parent.kind, crate::tree::NodeKind::Column);
    assert_eq!(parent.props.padding, Some(16.0));
    assert_eq!(parent.children, vec![2]);

    let child = tree.nodes.get(&2).unwrap();
    assert_eq!(child.kind, crate::tree::NodeKind::Text);
    assert_eq!(child.props.text.as_deref(), Some("Hello"));
    assert_eq!(child.parent, Some(1));
}

// ── PATCH_NODE field mask edge cases ──────────────────────────────────

#[test]
fn test_patch_node_all_fields_mask() {
    // First create a node
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 2, 0]; // patch_count=2

    // CREATE_NODE
    bytes.push(0x01);
    bytes.extend_from_slice(&10u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0); // no props
    bytes.extend_from_slice(&0u32.to_le_bytes());

    // PATCH_NODE with all 12 known field bits set (0x0FFF)
    bytes.push(0x04);
    bytes.extend_from_slice(&10u64.to_le_bytes());
    bytes.extend_from_slice(&0x0FFFu16.to_le_bytes());

    // text (tag 1)
    let s = "all";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // title (tag 2)
    let s = "fields";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // color (tag 3)
    let s = "red";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // background (tag 4)
    let s = "blue";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // on_tap (tag 5)
    bytes.extend_from_slice(&99u64.to_le_bytes());

    // width (tag 6)
    bytes.extend_from_slice(&200.0f32.to_le_bytes());

    // height (tag 7)
    bytes.extend_from_slice(&100.0f32.to_le_bytes());

    // padding (tag 8)
    bytes.extend_from_slice(&5.0f32.to_le_bytes());

    // flex_grow (tag 9)
    bytes.extend_from_slice(&2.0f32.to_le_bytes());

    // flex_direction (tag 10) — row=1
    bytes.push(1);

    // justify_content (tag 11) — end=2
    bytes.push(2);

    // align_items (tag 12) — center=1
    bytes.push(1);

    let mut tree = make_tree();
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();

    let node = tree.nodes.get(&10).unwrap();
    assert_eq!(node.props.text.as_deref(), Some("all"));
    assert_eq!(node.props.title.as_deref(), Some("fields"));
    assert_eq!(node.props.color.as_deref(), Some("red"));
    assert_eq!(node.props.background.as_deref(), Some("blue"));
    assert_eq!(node.props.on_tap, Some(99));
    assert_eq!(node.props.width, Some(200.0));
    assert_eq!(node.props.height, Some(100.0));
    assert_eq!(node.props.padding, Some(5.0));
    assert_eq!(node.props.flex_grow, Some(2.0));
}

#[test]
fn test_patch_node_zero_mask_no_fields() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 2, 0];

    // CREATE_NODE
    bytes.push(0x01);
    bytes.extend_from_slice(&5u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0);
    bytes.extend_from_slice(&0u32.to_le_bytes());

    // PATCH_NODE with mask=0 — no field data follows
    bytes.push(0x04);
    bytes.extend_from_slice(&5u64.to_le_bytes());
    bytes.extend_from_slice(&0x0000u16.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();

    let node = tree.nodes.get(&5).unwrap();
    // Props should remain at defaults
    assert_eq!(node.props.text, None);
    assert_eq!(node.props.width, None);
}

// ── Multiple patches in sequence ──────────────────────────────────────

#[test]
fn test_multiple_creates_and_removes() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 4, 0]; // patch_count=4

    // Create node 1
    bytes.push(0x01);
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0);
    bytes.extend_from_slice(&0u32.to_le_bytes());

    // Create node 2
    bytes.push(0x01);
    bytes.extend_from_slice(&2u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0);
    bytes.extend_from_slice(&0u32.to_le_bytes());

    // Remove node 1
    bytes.push(0x02);
    bytes.extend_from_slice(&1u64.to_le_bytes());

    // Remove node 2
    bytes.push(0x02);
    bytes.extend_from_slice(&2u64.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();
    assert!(tree.nodes.get(&1).is_none());
    assert!(tree.nodes.get(&2).is_none());
}

#[test]
fn test_create_update_remove_sequence() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 3, 0]; // patch_count=3

    // Create
    bytes.push(0x01);
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(1); // field_count=1
    bytes.push(1); // FIELD_TEXT
    let s = "original";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());

    // Update
    bytes.push(0x03);
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.push(1); // field_count=1
    bytes.push(1); // FIELD_TEXT
    let s = "updated";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // Remove
    bytes.push(0x02);
    bytes.extend_from_slice(&1u64.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();
    assert!(tree.nodes.get(&1).is_none());
}

// ── String interning edge cases ───────────────────────────────────────

#[test]
fn test_interned_string_not_found() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0];

    // CREATE_NODE with interned text referencing unregistered string_id=999
    bytes.push(0x01);
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(1); // field_count=1
    bytes.push(13); // FIELD_TEXT_INTERNED
    bytes.extend_from_slice(&999u16.to_le_bytes()); // unregistered string_id
    bytes.extend_from_slice(&0u32.to_le_bytes());

    let mut tree = make_tree();
    // Should not panic — just log error and leave text as None
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();
    let node = tree.nodes.get(&1).unwrap();
    assert_eq!(node.props.text, None);
}

#[test]
fn test_multiple_register_string_same_id() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 3, 0];

    // REGISTER_STRING id=1 "first"
    bytes.push(0x05);
    bytes.extend_from_slice(&1u16.to_le_bytes());
    let s = "first";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // REGISTER_STRING id=1 "second" (overwrite)
    bytes.push(0x05);
    bytes.extend_from_slice(&1u16.to_le_bytes());
    let s = "second";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // CREATE_NODE using interned id=1
    bytes.push(0x01);
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(1);
    bytes.push(13); // FIELD_TEXT_INTERNED
    bytes.extend_from_slice(&1u16.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();
    let node = tree.nodes.get(&1).unwrap();
    // Should use the last registered value
    assert_eq!(node.props.text.as_deref(), Some("second"));
}

// ── Large payload edge cases ──────────────────────────────────────────

#[test]
fn test_large_payload_string() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0];

    bytes.push(0x01); // CREATE_NODE
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(1); // field_count=1
    bytes.push(1); // FIELD_TEXT

    let large_text = "X".repeat(10000);
    bytes.extend_from_slice(&(large_text.len() as u16).to_le_bytes());
    bytes.extend_from_slice(large_text.as_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();
    let node = tree.nodes.get(&1).unwrap();
    assert_eq!(node.props.text.as_deref(), Some(large_text.as_str()));
}

#[test]
fn test_set_text_large_string() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0];

    bytes.push(0x06); // SET_TEXT
    bytes.extend_from_slice(&42u64.to_le_bytes());

    let large_text = "Y".repeat(65535);
    bytes.extend_from_slice(&(large_text.len() as u16).to_le_bytes());
    bytes.extend_from_slice(large_text.as_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();
    // SET_TEXT on non-existent node should not panic
}

// ── Node type edge cases ──────────────────────────────────────────────

#[test]
fn test_all_node_types_decode() {
    // Test that every valid node type byte (0-46) decodes without panic
    for type_byte in 0u8..=46 {
        let mut bytes = vec![];
        bytes.push(0xDA);
        bytes.push(0xA1);
        bytes.extend_from_slice(&3u16.to_le_bytes());
        bytes.extend_from_slice(&0u16.to_le_bytes());
        bytes.extend_from_slice(&1u64.to_le_bytes());

        bytes.extend_from_slice(&1u64.to_le_bytes()); // id
        bytes.push(type_byte);
        bytes.extend_from_slice(&0u64.to_le_bytes()); // layout_hash
        bytes.push(0); // no props
        bytes.extend_from_slice(&0u32.to_le_bytes()); // no children

        let mut tree = make_tree();
        crate::protocol::decode_full_tree(&mut tree, &bytes);
        assert!(tree.root.is_some(), "Failed for type_byte={}", type_byte);
        assert!(
            tree.nodes.contains_key(&1),
            "Missing node for type_byte={}",
            type_byte
        );
    }
}

#[test]
fn test_unknown_node_type_returns_none() {
    let mut bytes = vec![];
    bytes.push(0xDA);
    bytes.push(0xA1);
    bytes.extend_from_slice(&3u16.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&1u64.to_le_bytes());

    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.push(200); // unknown type byte
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0);
    bytes.extend_from_slice(&0u32.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);
    assert!(tree.root.is_none());
}

// ── Props edge cases ──────────────────────────────────────────────────

#[test]
fn test_props_unknown_tag_skipped() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0];

    bytes.push(0x01); // CREATE_NODE
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(2); // field_count=2

    // Known field
    bytes.push(1); // FIELD_TEXT
    let s = "hello";
    bytes.extend_from_slice(&(s.len() as u16).to_le_bytes());
    bytes.extend_from_slice(s.as_bytes());

    // Unknown field tag — should not panic
    bytes.push(99); // unknown tag
    bytes.extend_from_slice(&[0u8; 4]); // some data

    bytes.extend_from_slice(&0u32.to_le_bytes());

    let mut tree = make_tree();
    // Should not panic — unknown tags are logged and skipped
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();
    let node = tree.nodes.get(&1).unwrap();
    assert_eq!(node.props.text.as_deref(), Some("hello"));
}

#[test]
fn test_props_zero_field_count() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 1, 0];

    bytes.push(0x01);
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0); // field_count=0
    bytes.extend_from_slice(&0u32.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();
    let node = tree.nodes.get(&1).unwrap();
    assert_eq!(node.props.text, None);
}

// ── Frame boundary edge cases ─────────────────────────────────────────

#[test]
fn test_frame_begin_end_no_patches() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 2, 0]; // patch_count=2 (FRAME_BEGIN + FRAME_END)

    bytes.push(0x00); // FRAME_BEGIN
    bytes.push(0xFF); // FRAME_END

    let mut tree = make_tree();
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();
}

#[test]
fn test_multiple_frame_begin_end_pairs() {
    let mut bytes = vec![0xDA, 0xA1, 3, 0, 6, 0]; // patch_count=6

    bytes.push(0x00); // FRAME_BEGIN
    bytes.push(0x01); // CREATE_NODE
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0); // NODE_TEXT
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0);
    bytes.extend_from_slice(&0u32.to_le_bytes());
    bytes.push(0xFF); // FRAME_END

    bytes.push(0x00); // FRAME_BEGIN
    bytes.push(0x02); // REMOVE
    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.push(0xFF); // FRAME_END

    let mut tree = make_tree();
    crate::protocol::decode_and_apply(&mut tree, &bytes).unwrap();
    assert!(tree.nodes.get(&1).is_none());
}

// ── Empty tree edge cases ─────────────────────────────────────────────

#[test]
fn test_full_tree_zero_node_count() {
    let mut bytes = vec![];
    bytes.push(0xDA);
    bytes.push(0xA1);
    bytes.extend_from_slice(&3u16.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&0u64.to_le_bytes()); // node_count=0

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);
    assert!(tree.root.is_none());
}

#[test]
fn test_full_tree_node_count_lies() {
    // Header says 5 nodes but only 1 is present
    let mut bytes = vec![];
    bytes.push(0xDA);
    bytes.push(0xA1);
    bytes.extend_from_slice(&3u16.to_le_bytes());
    bytes.extend_from_slice(&0u16.to_le_bytes());
    bytes.extend_from_slice(&5u64.to_le_bytes()); // lies! only 1 node

    bytes.extend_from_slice(&1u64.to_le_bytes());
    bytes.push(36); // NODE_COLUMN
    bytes.extend_from_slice(&0u64.to_le_bytes());
    bytes.push(0);
    bytes.extend_from_slice(&0u32.to_le_bytes());

    let mut tree = make_tree();
    crate::protocol::decode_full_tree(&mut tree, &bytes);
    // Should still decode the root successfully
    assert!(tree.root.is_some());
}
