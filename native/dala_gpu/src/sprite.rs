//! Sprite batching for efficient rendering.
//!
//! Collects multiple sprite draw commands and sorts them for minimal
/// state changes (texture switches, etc.).

/// A single sprite draw command.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SpriteCommand {
    /// Sprite ID in the texture atlas.
    pub sprite_id: u64,
    /// Destination X coordinate.
    pub x: u32,
    /// Destination Y coordinate.
    pub y: u32,
    /// Sort key for batching (lower = drawn first).
    pub order: u32,
}

/// A batch of sprite commands.
///
/// Collects commands and can be sorted by sprite ID to minimize texture
/// switches during rendering.
pub struct SpriteBatch {
    commands: Vec<SpriteCommand>,
}

impl SpriteBatch {
    /// Create a new empty sprite batch.
    pub fn new() -> Self {
        Self {
            commands: Vec::new(),
        }
    }

    /// Create a new sprite batch with the given capacity.
    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            commands: Vec::with_capacity(capacity),
        }
    }

    /// Add a sprite command to the batch.
    pub fn push(&mut self, sprite_id: u64, x: u32, y: u32) {
        self.commands.push(SpriteCommand {
            sprite_id,
            x,
            y,
            order: 0,
        });
    }

    /// Add a sprite command with a specific sort order.
    pub fn push_ordered(&mut self, sprite_id: u64, x: u32, y: u32, order: u32) {
        self.commands.push(SpriteCommand {
            sprite_id,
            x,
            y,
            order,
        });
    }

    /// Sort commands by sprite ID (for texture coherence) then by order.
    pub fn sort(&mut self) {
        self.commands.sort_by_key(|cmd| (cmd.sprite_id, cmd.order));
    }

    /// Get the commands as a slice.
    pub fn commands(&self) -> &[SpriteCommand] {
        &self.commands
    }

    /// Clear the batch.
    pub fn clear(&mut self) {
        self.commands.clear();
    }

    /// Number of commands in the batch.
    pub fn len(&self) -> usize {
        self.commands.len()
    }

    /// Whether the batch is empty.
    pub fn is_empty(&self) -> bool {
        self.commands.is_empty()
    }
}

impl Default for SpriteBatch {
    fn default() -> Self {
        Self::new()
    }
}

impl IntoIterator for SpriteBatch {
    type Item = SpriteCommand;
    type IntoIter = std::vec::IntoIter<SpriteCommand>;

    fn into_iter(self) -> Self::IntoIter {
        self.commands.into_iter()
    }
}

impl<'a> IntoIterator for &'a SpriteBatch {
    type Item = &'a SpriteCommand;
    type IntoIter = std::slice::Iter<'a, SpriteCommand>;

    fn into_iter(self) -> Self::IntoIter {
        self.commands.iter()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_push_and_sort() {
        let mut batch = SpriteBatch::new();
        batch.push(3, 10, 20);
        batch.push(1, 30, 40);
        batch.push(2, 50, 60);
        batch.sort();

        let ids: Vec<u64> = batch.commands().iter().map(|c| c.sprite_id).collect();
        assert_eq!(ids, vec![1, 2, 3]);
    }

    #[test]
    fn test_push_ordered() {
        let mut batch = SpriteBatch::new();
        batch.push_ordered(1, 10, 20, 5);
        batch.push_ordered(1, 30, 40, 1);
        batch.push_ordered(1, 50, 60, 3);
        batch.sort();

        let orders: Vec<u32> = batch.commands().iter().map(|c| c.order).collect();
        assert_eq!(orders, vec![1, 3, 5]);
    }

    #[test]
    fn test_clear() {
        let mut batch = SpriteBatch::new();
        batch.push(1, 0, 0);
        batch.push(2, 0, 0);
        assert_eq!(batch.len(), 2);
        batch.clear();
        assert!(batch.is_empty());
    }

    #[test]
    fn test_default() {
        let batch: SpriteBatch = Default::default();
        assert!(batch.is_empty());
    }
}
