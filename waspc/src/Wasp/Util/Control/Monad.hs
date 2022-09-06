module Wasp.Util.Control.Monad
  ( foldMapM',
    foldM1,
    untilM,
  )
where

import Control.Monad (foldM)
import Data.List (foldl')
import Data.List.NonEmpty (NonEmpty ((:|)))

-- | Analogous to "Data.Foldable.foldMap'", except that its result is encapsulated in a
-- monad.
--
-- TODO: write tests for this function
--
-- @
-- foldMapM f [x1, x2, ..., xn] ==
--   do
--     a1 <- f x1
--     a2 <- f x2
--     ...
--     an <- f xn
--     return $ mempty <> a1 <> a2 <> ... <> an
-- @
--
-- __Examples__
--
-- >>> import Data.Monoid
-- >>> getSum <$> foldMapM' (\n -> if n > 3 then Right n else Left n) (map Sum [4,7,5,6])
-- Right 22
foldMapM' :: (Foldable t, Monad m, Monoid s) => (a -> m s) -> t a -> m s
foldMapM' f = foldl' (\ms a -> ms >>= \s -> (s <>) <$> f a) $ pure mempty

-- | A variant of "Control.Monad.foldM" that has no base case and can only be
-- applied to a non empty list.
--
-- TODO: write tests for this function
--
-- __Examples__
--
-- >>> foldM1 (\l r -> Right $ l + r) $ 1 :| [2..4]
-- Right 10
foldM1 :: (Monad m) => (a -> a -> m a) -> NonEmpty a -> m a
foldM1 f (x :| xs) = foldM f x xs

-- | Analogue of 'until'. @'untilM' p f b@ yields the result of applying @f@
-- until @p@ is true.
untilM :: Monad m => (a -> Bool) -> (a -> m a) -> a -> m a
untilM predicate f base
  | predicate base = return base
  | otherwise = f base >>= untilM predicate f
