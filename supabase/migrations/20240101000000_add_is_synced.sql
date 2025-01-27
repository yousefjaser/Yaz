-- Add is_synced column to customers table
ALTER TABLE customers 
ADD COLUMN is_synced boolean DEFAULT true;

-- Add is_synced column to payments table
ALTER TABLE payments 
ADD COLUMN is_synced boolean DEFAULT true;

-- Update existing records
UPDATE customers SET is_synced = true WHERE is_synced IS NULL;
UPDATE payments SET is_synced = true WHERE is_synced IS NULL; 