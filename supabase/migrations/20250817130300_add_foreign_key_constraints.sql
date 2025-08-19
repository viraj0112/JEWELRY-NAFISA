-- Add foreign key constraints after all tables are created

-- Add foreign key constraints to pins table
ALTER TABLE pins
  ADD CONSTRAINT fk_pins_owner_id
  FOREIGN KEY (owner_id)
  REFERENCES users(id)
  ON DELETE CASCADE;

-- Add foreign key constraints to boards table
ALTER TABLE boards
  ADD CONSTRAINT fk_boards_user_id
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE CASCADE;

-- Add foreign key constraints to user_likes table
ALTER TABLE user_likes
  ADD CONSTRAINT fk_user_likes_user_id
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE CASCADE,
  ADD CONSTRAINT fk_user_likes_pin_id
  FOREIGN KEY (pin_id)
  REFERENCES pins(id)
  ON DELETE CASCADE;

-- Add foreign key constraints to boards_pins table
ALTER TABLE boards_pins
  ADD CONSTRAINT fk_boards_pins_board_id
  FOREIGN KEY (board_id)
  REFERENCES boards(id)
  ON DELETE CASCADE,
  ADD CONSTRAINT fk_boards_pins_pin_id
  FOREIGN KEY (pin_id)
  REFERENCES pins(id)
  ON DELETE CASCADE;