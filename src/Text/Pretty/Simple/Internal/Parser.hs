{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}

{-|
Module      : Text.Pretty.Simple.Internal.Parser
Copyright   : (c) Dennis Gosnell, 2016
License     : BSD-style (see LICENSE file)
Maintainer  : cdep.illabout@gmail.com
Stability   : experimental
Portability : POSIX

-}
module Text.Pretty.Simple.Internal.Parser
  where

#if __GLASGOW_HASKELL__ < 710
-- We don't need this import for GHC 7.10 as it exports all required functions
-- from Prelude
import Control.Applicative
#endif

import Control.Applicative ((<|>))
import Data.Functor.Identity (Identity)
import Text.Parsec
       (Parsec, ParseError, lookAhead, many, noneOf, optionMaybe,
        parserFail, runParser, try)
import Text.Parsec.Language (haskellDef)
import qualified Text.Parsec.Token as Token

import Text.Pretty.Simple.Internal.Expr (CommaSeparated(..), Expr(..))

-- $setup
-- >>> import Data.Either (isLeft)
-- >>> :{
-- let test :: Parser a -> String -> Either ParseError a
--     test parser = runParser parser () "(no source)"
-- :}

type Parser = Parsec String ()

----------------------------
-- Lexer helper functions --
----------------------------

lexer :: Token.GenTokenParser String u Identity
lexer = Token.makeTokenParser haskellDef

stringLiteral :: Parser String
stringLiteral = Token.stringLiteral lexer

brackets :: Parser a -> Parser a
brackets = Token.brackets lexer

braces :: Parser a -> Parser a
braces = Token.braces lexer

parens :: Parser a -> Parser a
parens = Token.parens lexer

commaSep :: Parser a -> Parser [a]
commaSep = Token.commaSep lexer

lexeme :: Parser a -> Parser a
lexeme = Token.lexeme lexer

------------
-- Parser --
------------

parser :: Parser [Expr]
parser = expr

-- | This is definitely hacky.
expr :: Parser [Expr]
expr = many expr'

expr' :: Parser Expr
expr' = recursiveExpr <|> nonRecursiveExpr

bracketsExpr :: Parser Expr
bracketsExpr = Brackets <$> recursiveSurroundingExpr brackets

bracesExpr :: Parser Expr
bracesExpr = Braces <$> recursiveSurroundingExpr braces

parensExpr :: Parser Expr
parensExpr = Parens <$> recursiveSurroundingExpr parens

recursiveSurroundingExpr :: (forall a. Parser a -> Parser a)
                         -> Parser (CommaSeparated [Expr])
recursiveSurroundingExpr surround = do
  CommaSeparated <$> surround (commaSep expr)

recursiveExpr :: Parser Expr
recursiveExpr = do
  bracketsExpr <|> parensExpr <|> bracesExpr

-- | Parse a string literal.
--
-- >>> test stringLiteralExpr "\"hello\""
-- Right (StringLit "hello")
--
-- >>> isLeft $ test stringLiteralExpr " \"hello\""
-- True
stringLiteralExpr :: Parser Expr
stringLiteralExpr = StringLit <$> stringLiteral

nonRecursiveExpr :: Parser Expr
nonRecursiveExpr = do
  stringLiteralExpr <|> anyOtherText

-- | Parse anything that doesn't get parsed by the parsers above.
--
-- >>> test anyOtherText " Foo "
-- Right (Other " Foo ")
--
-- Parse empty strings.
--
-- >>> test anyOtherText " "
-- Right (Other " ")
--
-- Stop parsing if we hit @\[@, @\]@, @\(@, @\)@, @\{@, @\}@, @\"@, or @,@.
--
-- >>> test anyOtherText "hello["
-- Right (Other "hello")
--
-- Don\'t parse the empty string.
--
-- >>> isLeft $ test anyOtherText ""
-- True
-- >>> isLeft $ test anyOtherText ","
-- True
anyOtherText :: Parser Expr
anyOtherText = do
  res <- many (Text.Parsec.noneOf "[](){},\"")
  case res of
    "" ->
      parserFail
        "Trying to apply anyOtherText to an empty string.  This doesn't work."
    _ -> pure $ Other res

testString1, testString2 :: String
testString1 = "Just [TextInput {textInputClass = Just (Class {unClass = \"class\"}), textInputId = Just (Id {unId = \"id\"}), textInputName = Just (Name {unName = \"name\"}), textInputValue = Just (Value {unValue = \"value\"}), textInputPlaceholder = Just (Placeholder {unPlaceholder = \"placeholder\"})}, TextInput {textInputClass = Just (Class {unClass = \"class\"}), textInputId = Just (Id {unId = \"id\"}), textInputName = Just (Name {unName = \"name\"}), textInputValue = Just (Value {unValue = \"value\"}), textInputPlaceholder = Just (Placeholder {unPlaceholder = \"placeholder\"})}]"
testString2 = "some stuff (hello [\"dia\\x40iahello\", why wh, bye] ) (bye)"

expressionParse :: String -> Either ParseError [Expr]
expressionParse = runParser parser () "(no source)"