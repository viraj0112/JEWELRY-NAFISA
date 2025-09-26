-- Create tables for the jewelry app

-- Enable the pgcrypto extension for generating UUIDs
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create the public users table
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  full_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create the pins table
CREATE TABLE IF NOT EXISTS pins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  image_url TEXT NOT NULL,
  like_count INTEGER DEFAULT 0,
  share_slug TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create the boards table
CREATE TABLE IF NOT EXISTS boards (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create the user_likes table
CREATE TABLE IF NOT EXISTS user_likes (
  user_id UUID NOT NULL,
  pin_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (user_id, pin_id)
);

-- Create the boards_pins table (many-to-many relationship)
CREATE TABLE IF NOT EXISTS boards_pins (
  board_id INTEGER NOT NULL,
  pin_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (board_id, pin_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_pins_owner_id ON pins(owner_id);
CREATE INDEX IF NOT EXISTS idx_pins_share_slug ON pins(share_slug);
CREATE INDEX IF NOT EXISTS idx_boards_user_id ON boards(user_id);
CREATE INDEX IF NOT EXISTS idx_user_likes_pin_id ON user_likes(pin_id);
CREATE INDEX IF NOT EXISTS idx_boards_pins_pin_id ON boards_pins(pin_id);
CREATE INDEX IF NOT EXISTS idx_boards_pins_board_id ON boards_pins(board_id);