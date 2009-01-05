{- |
Module      :  Control.Monad.Trans.Error
Copyright   :  (c) Michael Weber <michael.weber@post.rwth-aachen.de> 2001,
               (c) Jeff Newbern 2003-2006,
               (c) Andriy Palamarchuk 2006
License     :  BSD-style (see the file libraries/base/LICENSE)

Maintainer  :  libraries@haskell.org
Stability   :  experimental
Portability :  portable

[Computation type:] Computations which may fail or throw exceptions.

[Binding strategy:] Failure records information about the cause\/location
of the failure. Failure values bypass the bound function,
other values are used as inputs to the bound function.

[Useful for:] Building computations from sequences of functions that may fail
or using exception handling to structure error handling.

[Zero and plus:] Zero is represented by an empty error and the plus operation
executes its second argument if the first fails.

[Example type:] @'Data.Either' String a@

The Error monad (also called the Exception monad).
-}

{-
  Rendered by Michael Weber <mailto:michael.weber@post.rwth-aachen.de>,
  inspired by the Haskell Monad Template Library from
    Andy Gill (<http://www.cse.ogi.edu/~andy/>)
-}
module Control.Monad.Trans.Error (
    -- * The ErrorT monad transformer
    Error(..),
    ErrorList(..),
    ErrorT(..),
    mapErrorT,
    throwError,
    catchError,
    -- * Lifting other operations
    liftCallCC,
    liftListen,
    liftPass,
  ) where

import Control.Exception (IOException)
import Control.Monad
import Control.Monad.Fix
import Control.Monad.Trans

import Control.Monad.Instances ()
import System.IO

instance MonadPlus IO where
    mzero       = ioError (userError "mzero")
    m `mplus` n = m `catch` \_ -> n

-- | An exception to be thrown.
-- An instance must redefine at least one of 'noMsg', 'strMsg'.
class Error a where
    -- | Creates an exception without a message.
    -- Default implementation is @'strMsg' \"\"@.
    noMsg  :: a
    -- | Creates an exception with a message.
    -- Default implementation is 'noMsg'.
    strMsg :: String -> a

    noMsg    = strMsg ""
    strMsg _ = noMsg

-- | A string can be thrown as an error.
instance ErrorList a => Error [a] where
    strMsg = listMsg

instance Error IOException where
    strMsg = userError

-- | Workaround so that we can have a Haskell 98 instance @'Error' 'String'@.
class ErrorList a where
    listMsg :: String -> [a]

instance ErrorList Char where
    listMsg = id

-- ---------------------------------------------------------------------------
-- Our parameterizable error monad

instance (Error e) => Monad (Either e) where
    return        = Right
    Left  l >>= _ = Left l
    Right r >>= k = k r
    fail msg      = Left (strMsg msg)

instance (Error e) => MonadPlus (Either e) where
    mzero            = Left noMsg
    Left _ `mplus` n = n
    m      `mplus` _ = m

instance (Error e) => MonadFix (Either e) where
    mfix f = let
        a = f $ case a of
            Right r -> r
            _       -> error "empty mfix argument"
        in a

{- |
The error monad transformer. It can be used to add error handling to other
monads.

The @ErrorT@ Monad structure is parameterized over two things:

 * e - The error type.

 * m - The inner monad.

Here are some examples of use:

> -- wraps IO action that can throw an error e
> type ErrorWithIO e a = ErrorT e IO a
> ==> ErrorT (IO (Either e a))
>
> -- IO monad wrapped in StateT inside of ErrorT
> type ErrorAndStateWithIO e s a = ErrorT e (StateT s IO) a
> ==> ErrorT (StateT s IO (Either e a))
> ==> ErrorT (StateT (s -> IO (Either e a,s)))
-}

newtype ErrorT e m a = ErrorT { runErrorT :: m (Either e a) }

mapErrorT :: (m (Either e a) -> n (Either e' b))
          -> ErrorT e m a
          -> ErrorT e' n b
mapErrorT f m = ErrorT $ f (runErrorT m)

instance (Monad m) => Functor (ErrorT e m) where
    fmap f = ErrorT . liftM (fmap f) . runErrorT

instance (Monad m, Error e) => Monad (ErrorT e m) where
    return a = ErrorT $ return (Right a)
    m >>= k  = ErrorT $ do
        a <- runErrorT m
        case a of
            Left  l -> return (Left l)
            Right r -> runErrorT (k r)
    fail msg = ErrorT $ return (Left (strMsg msg))

instance (Monad m, Error e) => MonadPlus (ErrorT e m) where
    mzero       = ErrorT $ return (Left noMsg)
    m `mplus` n = ErrorT $ do
        a <- runErrorT m
        case a of
            Left  _ -> runErrorT n
            Right r -> return (Right r)

instance (MonadFix m, Error e) => MonadFix (ErrorT e m) where
    mfix f = ErrorT $ mfix $ \a -> runErrorT $ f $ case a of
        Right r -> r
        _       -> error "empty mfix argument"

instance (Error e) => MonadTrans (ErrorT e) where
    lift m = ErrorT $ do
        a <- m
        return (Right a)

instance (Error e, MonadIO m) => MonadIO (ErrorT e m) where
    liftIO = lift . liftIO

-- | Signal an error
throwError :: (Monad m, Error e) => e -> ErrorT e m a
throwError l = ErrorT $ return (Left l)

-- | Handle an error
catchError :: (Monad m, Error e) =>
    ErrorT e m a -> (e -> ErrorT e m a) -> ErrorT e m a
m `catchError` h = ErrorT $ do
    a <- runErrorT m
    case a of
        Left  l -> runErrorT (h l)
        Right r -> return (Right r)

-- | Lift a @callCC@ operation to the new monad.
liftCallCC :: (((Either e a -> m (Either e b)) -> m (Either e a)) ->
    m (Either e a)) -> ((a -> ErrorT e m b) -> ErrorT e m a) -> ErrorT e m a
liftCallCC callCC f = ErrorT $
    callCC $ \c ->
    runErrorT (f (\a -> ErrorT $ c (Right a)))

-- | Lift a @listen@ operation to the new monad.
liftListen :: Monad m =>
    (m (Either e a) -> m (Either e a,w)) -> ErrorT e m a -> ErrorT e m (a,w)
liftListen listen = mapErrorT $ \ m -> do
    (a, w) <- listen m
    return $! fmap (\ r -> (r, w)) a

-- | Lift a @pass@ operation to the new monad.
liftPass :: Monad m => (m (Either e a,w -> w) -> m (Either e a)) ->
    ErrorT e m (a,w -> w) -> ErrorT e m a
liftPass pass = mapErrorT $ \ m -> pass $ do
    a <- m
    return $! case a of
        Left  l      -> (Left  l, id)
        Right (r, f) -> (Right r, f)