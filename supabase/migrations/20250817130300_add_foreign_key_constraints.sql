-- The name 'fk_board' comes directly from the error message you received.
ALTER TABLE public.boards_pins
  DROP CONSTRAINT IF EXISTS fk_board;

-- Also drop the other existing constraints on the table to recreate them cleanly.
ALTER TABLE public.boards_pins
  DROP CONSTRAINT IF EXISTS fk_boards_pins_board_id;

ALTER TABLE public.boards_pins
  DROP CONSTRAINT IF EXISTS fk_boards_pins_pin_id;

-- Re-add the foreign key for board_id with ON DELETE CASCADE enabled.
-- This ensures that deleting a board will also delete its entries in this table.
ALTER TABLE public.boards_pins
  ADD CONSTRAINT fk_boards_pins_board_id FOREIGN KEY (board_id) REFERENCES public.boards(id) ON DELETE CASCADE;

-- Re-add the foreign key for pin_id with ON DELETE CASCADE enabled for consistency.
ALTER TABLE public.boards_pins
  ADD CONSTRAINT fk_boards_pins_pin_id FOREIGN KEY (pin_id) REFERENCES public.pins(id) ON DELETE CASCADE;