module Wasp.LSP.Syntax
  ( -- * Syntax

    -- | Module with utilities for working with/looking for patterns in CSTs
    lspPositionToOffset,
    lspRangeToSpan,
    locationAtOffset,
    parentIs,
    hasLeft,
    isAtExprPlace,
    lexemeAt,
    findChild,
    findAncestor,
    -- | Printing
    showNeighborhood,
  )
where

import Data.List (find, intercalate)
import qualified Language.LSP.Types as J
import qualified Wasp.Analyzer.Parser.CST as S
import Wasp.Analyzer.Parser.CST.Traverse
import Wasp.Analyzer.Parser.SourceSpan (SourceSpan (SourceSpan))
import Wasp.LSP.Util (allP, anyP)

-- | @lspPositionToOffset srcString position@ converts @position@ into a 0-based
-- offset from the start of @srcString@.
--
-- @position@ is a line/column offset into @srcString@.
lspPositionToOffset :: String -> J.Position -> Int
lspPositionToOffset srcString (J.Position l c) =
  let linesBefore = take (fromIntegral l) (lines srcString)
   in -- We add 1 to the length of each line to make sure to count the newline
      sum (map ((+ 1) . length) linesBefore) + fromIntegral c

-- | @lspRangeToSpan srcString range@ converts the @range@ into a 'SourceSpan'.
--
-- The start and end positions in @range@ are line/column offsets into @srcString@,
-- and the returned 'SourceSpan' contains a start and end 0-based offset from the
-- start of @srcString@.
lspRangeToSpan :: String -> J.Range -> SourceSpan
lspRangeToSpan srcString (J.Range start end) =
  let startOffset = lspPositionToOffset srcString start
      endOffset = lspPositionToOffset srcString end
   in SourceSpan startOffset endOffset

-- | Move to the node containing the offset.
--
-- If the offset falls on the border between two nodes, it tries to first choose
-- the leftmost non-trivia token, and then the leftmost token.
locationAtOffset :: Int -> Traversal -> Traversal
locationAtOffset targetOffset start = go $ bottom start
  where
    go :: Traversal -> Traversal
    go at
      | offsetAt at == targetOffset = at
      | offsetAfter at > targetOffset = at
      | offsetAfter at == targetOffset =
          if not $ S.syntaxKindIsTrivia $ kindAt at
            then at
            else case at & next of
              Just at' | not (S.syntaxKindIsTrivia (kindAt at')) -> at'
              _ -> at
      -- If @at & next@ fails, the input doesn't contain the offset, so just
      -- return the last node instead.
      | otherwise = maybe at go $ at & next

parentIs :: S.SyntaxKind -> Traversal -> Bool
parentIs k t = Just k == parentKind t

hasLeft :: S.SyntaxKind -> Traversal -> Bool
hasLeft k t = k `elem` map kindAt (leftSiblings t)

-- | Check whether a position in a CST is somewhere an expression belongs. These
-- locations (as of now) are:
--
-- - Parent is DictEntry, has a DictKey left siblings
-- - Parent is Decl, has DeclType and DeclName left siblings
-- - Parent is a List
-- - Parent is a Tuple
isAtExprPlace :: Traversal -> Bool
isAtExprPlace =
  anyP
    [ allP [parentIs S.DictEntry, hasLeft S.DictKey],
      allP [parentIs S.Decl, hasLeft S.DeclType, hasLeft S.DeclName],
      parentIs S.List,
      parentIs S.Tuple
    ]

-- | Show the nodes around the current position
--
-- Used for debug purposes
showNeighborhood :: Traversal -> String
showNeighborhood t =
  let parentStr = case t & up of
        Nothing -> "<ROOT>"
        Just parent -> showNode "" parent
      leftSiblingLines = map (showNode "  ") $ leftSiblings t
      currentStr = showNode "  " t ++ " <--"
      rightSiblingLines = map (showNode "  ") $ rightSiblings t
   in intercalate "\n" $ parentStr : leftSiblingLines ++ [currentStr] ++ rightSiblingLines
  where
    showNode indent node =
      indent
        ++ show (kindAt node)
        ++ "@"
        ++ show (offsetAt node)
        ++ ".."
        ++ show (offsetAfter node)

-- | Search for a child node with the matching "SyntaxKind".
findChild :: S.SyntaxKind -> Traversal -> Maybe Traversal
findChild skind t = find ((== skind) . kindAt) $ children t

findAncestor :: S.SyntaxKind -> Traversal -> Maybe Traversal
findAncestor skind t =
  if kindAt t == skind
    then Just t
    else findAncestor skind =<< up t

-- | @lexeme src traversal@
lexemeAt :: String -> Traversal -> String
lexemeAt src t = take (widthAt t) $ drop (offsetAt t) src
