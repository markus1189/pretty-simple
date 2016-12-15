{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}

{-|
Module      : Text.Pretty.Simple
Copyright   : (c) Dennis Gosnell, 2016
License     : BSD-style (see LICENSE file)
Maintainer  : cdep.illabout@gmail.com
Stability   : experimental
Portability : POSIX

-}
module Text.Pretty.Simple
  ( pShow
  , pPrint
  , pString
  -- * Examples
  -- $examples
  ) where

#if __GLASGOW_HASKELL__ < 710
-- We don't need this import for GHC 7.10 as it exports all required functions
-- from Prelude
import Control.Applicative
#endif

import Control.Monad.IO.Class (MonadIO, liftIO)

import Text.Pretty.Simple.Internal.Parser (expressionParse)
import Text.Pretty.Simple.Internal.Printer (expressionPrint)

pPrint :: (MonadIO m, Show a) => a -> m ()
pPrint = liftIO . putStrLn . pShow

pShow :: Show a => a -> String
pShow = pString . show

pString :: String -> String
pString string =
  either (const string) expressionPrint $ expressionParse string


-- $examples
-- Simple Haskell datatype:
--
-- >>> data Foo a = Foo a String deriving Show
--
-- >>> pPrint $ Foo 3 "hello"
-- Foo 3 "hello"
--
-- Lists:
--
-- >>> pPrint $ [1,2,3]
-- [ 1
-- , 2
-- , 3
-- ]
--
-- Slightly more complicated lists:
--
-- >>> pPrint $ [ Foo [ (), () ] "hello" ]
-- [ Foo
--    [ ()
--    , ()
--    ] "hello" ]
--
-- >>> pPrint $ [ Foo [ "bar", "baz" ] "hello", Foo [] "bye" ]
-- [ Foo
--    [ "bar"
--    , "baz"
--    ]"hello"
-- , Foo []"bye"
-- ]