{-# LANGUAGE CPP #-}
#if __GLASGOW_HASKELL__ >= 702 && __GLASGOW_HASKELL__ <= 902
{-# LANGUAGE Safe #-}
#else  
{-# LANGUAGE Trustworthy #-}
#endif
#if __GLASGOW_HASKELL__ >= 706
{-# LANGUAGE PolyKinds #-}
#endif
#if __GLASGOW_HASKELL__ >= 710
{-# LANGUAGE AutoDeriveTypeable #-}
#endif
#if MIN_VERSION_base(4,16,0)
{-# LANGUAGE TypeOperators, QuantifiedConstraints, ExplicitNamespaces #-}
#endif
-----------------------------------------------------------------------------
-- |
-- Module      :  Control.Applicative.Backwards
-- Copyright   :  (c) Russell O'Connor 2009
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  R.Paterson@city.ac.uk
-- Stability   :  experimental
-- Portability :  portable
--
-- Making functors with an 'Applicative' instance that performs actions
-- in the reverse order.
-----------------------------------------------------------------------------

module Control.Applicative.Backwards (
    Backwards(..),
  ) where

import Data.Functor.Classes
#if MIN_VERSION_base(4,12,0)
import Data.Functor.Contravariant
#endif

import Prelude hiding (foldr, foldr1, foldl, foldl1, null, length)
import Control.Applicative
import Data.Foldable
import Data.Traversable
#if MIN_VERSION_base(4,16,0)
import GHC.Types (type (@), Total)
#endif

-- | The same functor, but with an 'Applicative' instance that performs
-- actions in the reverse order.
newtype
#if MIN_VERSION_base(4,16,0)
  f @ a =>
#endif
  Backwards f a = Backwards { forwards :: f a }

instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Eq1 f) => Eq1 (Backwards f) where
    liftEq eq (Backwards x) (Backwards y) = liftEq eq x y
    {-# INLINE liftEq #-}

instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Ord1 f) => Ord1 (Backwards f) where
    liftCompare comp (Backwards x) (Backwards y) = liftCompare comp x y
    {-# INLINE liftCompare #-}

instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Read1 f) => Read1 (Backwards f) where
    liftReadsPrec rp rl = readsData $
        readsUnaryWith (liftReadsPrec rp rl) "Backwards" Backwards

instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Show1 f) => Show1 (Backwards f) where
    liftShowsPrec sp sl d (Backwards x) =
        showsUnaryWith (liftShowsPrec sp sl) "Backwards" d x

instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Eq1 f, Eq a) => Eq (Backwards f a) where (==) = eq1
instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Ord1 f, Ord a) => Ord (Backwards f a) where compare = compare1
instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Read1 f, Read a) => Read (Backwards f a) where readsPrec = readsPrec1
instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Show1 f, Show a) => Show (Backwards f a) where showsPrec = showsPrec1

-- | Derived instance.
instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Functor f) => Functor (Backwards f) where
    fmap f (Backwards a) = Backwards (fmap f a)
    {-# INLINE fmap #-}

-- | Apply @f@-actions in the reverse order.
instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Applicative f) => Applicative (Backwards f) where
    pure a = Backwards (pure a)
    {-# INLINE pure #-}
    Backwards f <*> Backwards a = Backwards (a <**> f)
    {-# INLINE (<*>) #-}

-- | Try alternatives in the same order as @f@.
instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Alternative f) => Alternative (Backwards f) where
    empty = Backwards empty
    {-# INLINE empty #-}
    Backwards x <|> Backwards y = Backwards (x <|> y)
    {-# INLINE (<|>) #-}

-- | Derived instance.
instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Foldable f) => Foldable (Backwards f) where
    foldMap f (Backwards t) = foldMap f t
    {-# INLINE foldMap #-}
    foldr f z (Backwards t) = foldr f z t
    {-# INLINE foldr #-}
    foldl f z (Backwards t) = foldl f z t
    {-# INLINE foldl #-}
    foldr1 f (Backwards t) = foldr1 f t
    {-# INLINE foldr1 #-}
    foldl1 f (Backwards t) = foldl1 f t
    {-# INLINE foldl1 #-}
#if MIN_VERSION_base(4,8,0)
    null (Backwards t) = null t
    length (Backwards t) = length t
#endif

-- | Derived instance.
instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Traversable f) => Traversable (Backwards f) where
    traverse f (Backwards t) = fmap Backwards (traverse f t)
    {-# INLINE traverse #-}
    sequenceA (Backwards t) = fmap Backwards (sequenceA t)
    {-# INLINE sequenceA #-}

#if MIN_VERSION_base(4,12,0)
-- | Derived instance.
instance (
#if MIN_VERSION_base(4,16,0)
  Total f,
#endif
  Contravariant f) => Contravariant (Backwards f) where
    contramap f = Backwards . contramap f . forwards
    {-# INLINE contramap #-}
#endif
