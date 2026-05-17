//! Texture atlas for sprite packing.
//!
//! Packs multiple sprite images into a single RGBA texture, allowing efficient
//! batched rendering.

use std::collections::HashMap;

/// A region within the texture atlas.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AtlasRegion {
    /// X coordinate of the top-left corner in the atlas.
    pub x: u32,
    /// Y coordinate of the top-left corner in the atlas.
    pub y: u32,
    /// Width of the region.
    pub w: u32,
    /// Height of the region.
    pub h: u32,
}

/// A texture atlas that packs sprites into a single RGBA image.
///
/// Uses a simple shelf-packing algorithm: sprites are placed left-to-right
/// on horizontal shelves. When a sprite doesn't fit on the current shelf,
/// a new shelf is started.
pub struct TextureAtlas {
    width: u32,
    height: u32,
    pixels: Vec<u8>,
    regions: HashMap<u64, AtlasRegion>,
    /// Current shelf Y position.
    shelf_y: u32,
    /// Current X position on the current shelf.
    shelf_x: u32,
    /// Height of the current shelf (tallest sprite on it).
    shelf_height: u32,
}

impl TextureAtlas {
    /// Create a new texture atlas with the given dimensions.
    pub fn new(width: u32, height: u32) -> Self {
        Self {
            width,
            height,
            pixels: vec![0u8; (width * height * 4) as usize],
            regions: HashMap::new(),
            shelf_y: 0,
            shelf_x: 0,
            shelf_height: 0,
        }
    }

    /// Pack a sprite into the atlas.
    ///
    /// `data` must be `w * h * 4` bytes (RGBA8888).
    /// Returns `Some(AtlasRegion)` on success, or `None` if the sprite doesn't fit.
    pub fn pack(&mut self, id: u64, data: &[u8], w: u32, h: u32) -> Option<AtlasRegion> {
        if w == 0 || h == 0 {
            return None;
        }

        // Check if the sprite fits on the current shelf.
        let fits_current_shelf = self.shelf_x + w <= self.width && self.shelf_y + h <= self.height;

        let (x, y) = if fits_current_shelf {
            let x = self.shelf_x;
            let y = self.shelf_y;
            self.shelf_x += w;
            self.shelf_height = self.shelf_height.max(h);
            (x, y)
        } else {
            // Start a new shelf.
            let new_shelf_y = self.shelf_y + self.shelf_height;
            if new_shelf_y + h > self.height || w > self.width {
                return None; // Doesn't fit.
            }
            self.shelf_y = new_shelf_y;
            self.shelf_x = w;
            self.shelf_height = h;
            (0, new_shelf_y)
        };

        // Copy pixel data into the atlas.
        for row in 0..h {
            let src_offset = (row * w * 4) as usize;
            let dst_offset = ((y + row) * self.width * 4 + x * 4) as usize;
            let row_bytes = (w * 4) as usize;
            self.pixels[dst_offset..dst_offset + row_bytes]
                .copy_from_slice(&data[src_offset..src_offset + row_bytes]);
        }

        let region = AtlasRegion { x, y, w, h };
        self.regions.insert(id, region);
        Some(region)
    }

    /// Look up the atlas region for a sprite ID.
    pub fn region(&self, id: u64) -> Option<&AtlasRegion> {
        self.regions.get(&id)
    }

    /// Get a reference to the atlas pixel data.
    pub fn pixels(&self) -> &[u8] {
        &self.pixels
    }

    /// Get the atlas width.
    pub fn width(&self) -> u32 {
        self.width
    }

    /// Get the atlas height.
    pub fn height(&self) -> u32 {
        self.height
    }

    /// Remove a sprite from the atlas.
    ///
    /// Note: this does not reclaim space. For a production atlas, you'd want
    /// defragmentation or a more sophisticated allocator.
    pub fn remove(&mut self, id: u64) -> Option<AtlasRegion> {
        self.regions.remove(&id)
    }

    /// Clear all sprites from the atlas.
    pub fn clear(&mut self) {
        self.pixels.fill(0);
        self.regions.clear();
        self.shelf_y = 0;
        self.shelf_x = 0;
        self.shelf_height = 0;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pack_single_sprite() {
        let mut atlas = TextureAtlas::new(256, 256);
        let data = vec![255u8; 32 * 32 * 4];
        let region = atlas.pack(1, &data, 32, 32).unwrap();
        assert_eq!(region.x, 0);
        assert_eq!(region.y, 0);
        assert_eq!(region.w, 32);
        assert_eq!(region.h, 32);
    }

    #[test]
    fn test_pack_multiple_sprites() {
        let mut atlas = TextureAtlas::new(256, 256);
        let data1 = vec![255u8; 32 * 32 * 4];
        let data2 = vec![128u8; 64 * 64 * 4];

        let r1 = atlas.pack(1, &data1, 32, 32).unwrap();
        let r2 = atlas.pack(2, &data2, 64, 64).unwrap();

        assert_eq!(r1.x, 0);
        assert_eq!(r2.x, 32); // Placed after sprite 1 on the same shelf.
        assert_eq!(r2.y, 0);
    }

    #[test]
    fn test_pack_overflow_new_shelf() {
        let mut atlas = TextureAtlas::new(64, 128);
        let data = vec![255u8; 64 * 64 * 4];

        let r1 = atlas.pack(1, &data, 64, 64).unwrap();
        let r2 = atlas.pack(2, &data, 64, 64).unwrap();

        assert_eq!(r1.y, 0);
        assert_eq!(r2.y, 64); // New shelf.
    }

    #[test]
    fn test_pack_too_large() {
        let mut atlas = TextureAtlas::new(32, 32);
        let data = vec![255u8; 64 * 64 * 4];
        assert!(atlas.pack(1, &data, 64, 64).is_none());
    }

    #[test]
    fn test_region_lookup() {
        let mut atlas = TextureAtlas::new(256, 256);
        let data = vec![255u8; 16 * 16 * 4];
        atlas.pack(42, &data, 16, 16);

        let region = atlas.region(42).unwrap();
        assert_eq!(region.w, 16);
        assert_eq!(region.h, 16);

        assert!(atlas.region(99).is_none());
    }

    #[test]
    fn test_clear() {
        let mut atlas = TextureAtlas::new(256, 256);
        let data = vec![255u8; 16 * 16 * 4];
        atlas.pack(1, &data, 16, 16);
        atlas.clear();
        assert!(atlas.region(1).is_none());
        assert!(atlas.pixels().iter().all(|&p| p == 0));
    }
}
