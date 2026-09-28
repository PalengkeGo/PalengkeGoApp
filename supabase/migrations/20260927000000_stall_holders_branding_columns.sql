-- Add branding and description columns to stall_holders table
ALTER TABLE stall_holders ADD COLUMN IF NOT EXISTS banner_image_url TEXT;
ALTER TABLE stall_holders ADD COLUMN IF NOT EXISTS avatar_image_url TEXT;
ALTER TABLE stall_holders ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;
ALTER TABLE stall_holders ADD COLUMN IF NOT EXISTS description TEXT;
