{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
module Data.Swagger.Declare where

import Control.Monad
import Control.Monad.Trans
import Data.Functor.Identity
import Data.Monoid

newtype DeclareT d m a = DeclareT { runDeclareT :: d -> m (d, a) }
  deriving (Functor)

instance (Monad m, Monoid d) => Applicative (DeclareT d m) where
  pure x = DeclareT (\_ -> pure (mempty, x))
  DeclareT df <*> DeclareT dx = DeclareT $ \d -> do
    (d',  f) <- df d
    (d'', x) <- dx (d <> d')
    return (d' <> d'', f x)

instance (Monad m, Monoid d) => Monad (DeclareT d m) where
  return x = DeclareT (\_ -> pure (mempty, x))
  DeclareT dx >>= f = DeclareT $ \d -> do
    (d',  x) <- dx d
    (d'', y) <- runDeclareT (f x) (d <> d')
    return (d' <> d'', y)

instance Monoid d => MonadTrans (DeclareT d) where
  lift m = DeclareT (\_ -> (,) mempty <$> m)

class Monad m => MonadDeclare d m | m -> d where
  declare :: d -> m ()
  look :: m d

instance (Monad m, Monoid d) => MonadDeclare d (DeclareT d m) where
  declare d = DeclareT (\_ -> return (d, ()))
  look = DeclareT (\d -> return (mempty, d))

looks :: MonadDeclare d m => (d -> a) -> m a
looks f = f <$> look

evalDeclareT :: Monad m => DeclareT d m a -> d -> m a
evalDeclareT (DeclareT f) d = snd `liftM` f d

execDeclareT :: Monad m => DeclareT d m a -> d -> m d
execDeclareT (DeclareT f) d = fst `liftM` f d

type Declare d = DeclareT d Identity

runDeclare :: Declare d a -> d -> (d, a)
runDeclare m = runIdentity . runDeclareT m

evalDeclare :: Declare d a -> d -> a
evalDeclare m = runIdentity . evalDeclareT m

execDeclare :: Declare d a -> d -> d
execDeclare m = runIdentity . execDeclareT m

