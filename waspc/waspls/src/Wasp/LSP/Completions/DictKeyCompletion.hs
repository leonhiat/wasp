module Wasp.LSP.Completions.DictKeyCompletion
  ( getCompletions,
  )
where

import Control.Lens ((?~), (^.))
import Control.Monad.Log.Class (MonadLog (logM))
import Data.Bifunctor (Bifunctor (second))
import qualified Data.HashMap.Strict as M
import qualified Data.Text as Text
import qualified Language.LSP.Types as LSP
import qualified Language.LSP.Types.Lens as LSP
import qualified Wasp.Analyzer.Parser.CST as S
import Wasp.Analyzer.Parser.CST.Traverse (Traversal)
import qualified Wasp.Analyzer.Parser.CST.Traverse as T
import Wasp.Analyzer.Type (Type)
import qualified Wasp.Analyzer.Type as Type
import Wasp.LSP.Completions.Common (CompletionProvider, makeBasicCompletionItem)
import qualified Wasp.LSP.Completions.Common as Ctx
import Wasp.LSP.Syntax (hasLeft, parentIs)
import Wasp.LSP.TypeInference (inferTypeAtLocation)
import Wasp.LSP.Util (allP, anyP)

-- | If the location is at a place where a dictionary key is expected, find
-- the list of keys that are allowed in the dictionary around the location and
-- return them as completion items.
--
-- The allowed keys are found by determining the expected type for the
-- dictionary and getting the keys from that, assuming it is a 'Type.DictType'.
-- No completions are made if there is no expected type or if the expected type
-- is not a 'Type.DictType'.
--
-- See 'Wasp.LSP.TypeHint' for how the expected type for the dictionary is
-- determined.
getCompletions :: (MonadLog m) => CompletionProvider m
getCompletions context location =
  if not $ isDictKeyExpectedAtLocation location
    then do
      logM "[DictKeyCompletion] not at dict key"
      return []
    else do
      logM "[DictKeyCompletion] at dict key"
      getCompletionsAtDictKey
  where
    getCompletionsAtDictKey = case inferTypeAtLocation (context ^. Ctx.src) location of
      Nothing -> do
        logM "[DictKeyCompletion] no type hint, can not suggest keys"
        return []
      Just (Type.DictType fieldMap) -> do
        logM "[DictKeyCompletion] found dict type hint"
        return $ map completionItemFromDictField $ listDictFields fieldMap
      Just _ -> do
        logM "[DictKeyCompletion] found non-dict type hint, no keys to suggest"
        return []

    completionItemFromDictField (key, keyType) =
      -- The user sees "key", but when they accept the completion "key: " is
      -- inserted, via the @insertText@ field.
      makeBasicCompletionItem (Text.pack key)
        T.& (LSP.kind ?~ LSP.CiField)
        T.& (LSP.detail ?~ Text.pack (":: " ++ show keyType))
        T.& (LSP.insertText ?~ Text.pack (key ++ ": "))

isDictKeyExpectedAtLocation :: Traversal -> Bool
isDictKeyExpectedAtLocation =
  anyP
    [ parentIs S.Dict,
      allP [parentIs S.DictEntry, not . hasLeft S.DictKey]
    ]

-- | List the (key, valuetype) pairs for a type. Returns an empty list for
-- everything except a 'Type.DictType'.
listDictFields :: M.HashMap String Type.DictEntryType -> [(String, Type)]
listDictFields fieldMap = map (second Type.dictEntryType) $ M.toList fieldMap
