-- Rename existing columns to match new naming convention (only if old names exist)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'description') THEN
    ALTER TABLE public.products RENAME COLUMN "description" TO "Description";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'price') THEN
    ALTER TABLE public.products RENAME COLUMN "price" TO "Price";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'image') THEN
    ALTER TABLE public.products RENAME COLUMN "image" TO "Image";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'Metal Purity / Carat') THEN
    ALTER TABLE public.products RENAME COLUMN "Metal Purity / Carat" TO "Metal Purity";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'Stone Weight (Carat / ct)') THEN
    ALTER TABLE public.products RENAME COLUMN "Stone Weight (Carat / ct)" TO "Stone Weight";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'Dimensions') THEN
    ALTER TABLE public.products RENAME COLUMN "Dimensions" TO "Dimension";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'scraped_url') THEN
    ALTER TABLE public.products RENAME COLUMN "scraped_url" TO "Scraped URL";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'Total Product Weight') THEN
    ALTER TABLE public.products RENAME COLUMN "Total Product Weight" TO "NET WEIGHT";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'Enamel Work / Embellishment') THEN
    ALTER TABLE public.products RENAME COLUMN "Enamel Work / Embellishment" TO "Enamel Work";
  END IF;
END $$;

-- Drop the old columns that are no longer needed (only if they exist)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'category') THEN
    ALTER TABLE public.products DROP COLUMN "category";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'Sub Category') THEN
    ALTER TABLE public.products DROP COLUMN "Sub Category";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'size') THEN
    ALTER TABLE public.products DROP COLUMN "size";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'Occasion') THEN
    ALTER TABLE public.products DROP COLUMN "Occasion";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'style') THEN
    ALTER TABLE public.products DROP COLUMN "style";
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'Product Code') THEN
    ALTER TABLE public.products DROP COLUMN "Product Code";
  END IF;
END $$;
