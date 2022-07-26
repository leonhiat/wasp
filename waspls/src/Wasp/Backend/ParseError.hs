{-# LANGUAGE DeriveGeneric #-}

module Wasp.Backend.ParseError
  ( -- * Parse error
    ParseError (..),

    -- * Display functions
    showError,
    showErrorMessage,
    errorRegion,

    -- * Source positions
    Region (..),
    SourcePos (..),
    offsetToSourcePos,
  )
where

import Control.DeepSeq (NFData)
import Data.List (intercalate)
import GHC.Generics (Generic)
import Wasp.Backend.Token (TokenKind)
import qualified Wasp.Backend.Token as T
import Wasp.Backend.TokenSet (TokenSet)
import qualified Wasp.Backend.TokenSet as TokenSet

data ParseError
  = UnexpectedToken !Region !TokenKind TokenSet
  | UnexpectedEOF !Int TokenSet
  deriving (Eq, Ord, Show, Generic)

instance NFData ParseError

data Region = Region !Int !Int deriving (Eq, Ord, Show, Generic)

instance NFData Region

data SourcePos = SourcePos !Int !Int deriving (Eq, Ord, Show, Generic)

instance NFData SourcePos

offsetToSourcePos :: String -> Int -> SourcePos
offsetToSourcePos source targetOffset = reach 0 (SourcePos 1 1) source
  where
    reach :: Int -> SourcePos -> String -> SourcePos
    reach o (SourcePos l c) remaining
      | o == targetOffset = SourcePos l c
      | [] <- remaining = SourcePos l c
      | ('\n' : remaining') <- remaining =
        let sp' = SourcePos (l + 1) 1
         in reach (o + 1) sp' remaining'
      | (_ : remaining') <- remaining =
        let sp' = SourcePos l (c + 1)
         in reach (o + 1) sp' remaining'

showError :: String -> ParseError -> String
showError source msg =
  let (Region so eo) = errorRegion msg
      start = offsetToSourcePos source so
      end = offsetToSourcePos source eo
   in "Parse error at " ++ showRegion start end ++ " (" ++ show so ++ ".." ++ show eo ++ ")\n  " ++ showErrorMessage msg

errorRegion :: ParseError -> Region
errorRegion (UnexpectedEOF o _) = Region o o
errorRegion (UnexpectedToken rgn _ _) = rgn

showErrorMessage :: ParseError -> String
showErrorMessage (UnexpectedEOF _ expecteds) =
  "Unexpected end of file, " ++ showExpected expecteds
showErrorMessage (UnexpectedToken _ actual expecteds) =
  "Unexpected token " ++ showTokenKind actual ++ ", " ++ showExpected expecteds

showExpected :: TokenSet -> String
showExpected expecteds = "expected one of " ++ showExpecteds expecteds

showExpecteds :: TokenSet -> String
showExpecteds expecteds =
  let kindStrs = map showTokenKind $ TokenSet.toList expecteds
      eofStrs = if TokenSet.eofMember expecteds then ["<eof>"] else []
   in intercalate "," (kindStrs ++ eofStrs)

showTokenKind :: TokenKind -> String
showTokenKind T.White = "<whitespace>"
showTokenKind T.Newline = "\\n"
showTokenKind T.Comment = "<comment>"
showTokenKind T.LParen = "'('"
showTokenKind T.RParen = "')'"
showTokenKind T.LSquare = "'['"
showTokenKind T.RSquare = "']'"
showTokenKind T.LCurly = "'{'"
showTokenKind T.RCurly = "'}'"
showTokenKind T.Comma = "','"
showTokenKind T.Colon = "':'"
showTokenKind T.KwImport = "'import'"
showTokenKind T.KwFrom = "'from'"
showTokenKind T.KwTrue = "'true'"
showTokenKind T.KwFalse = "'false'"
showTokenKind T.String = "<string>"
showTokenKind T.Int = "<number>"
showTokenKind T.Double = "<number>"
showTokenKind T.LQuote = "'{='"
showTokenKind T.RQuote = "'=}'"
showTokenKind T.Quoted = "<any>" -- Should be impossible, hard to prove though
showTokenKind T.Identifier = "<identifier>"
showTokenKind T.Error = "<error>"

showRegion :: SourcePos -> SourcePos -> String
showRegion start@(SourcePos sl sc) end@(SourcePos el ec)
  | start == end = show sl ++ ":" ++ show sc
  | sl == el = show sl ++ ":" ++ show sc ++ "-" ++ show ec
  | otherwise = show sl ++ ":" ++ show sc ++ "-" ++ show el ++ ":" ++ show ec
