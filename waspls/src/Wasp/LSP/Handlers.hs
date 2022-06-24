module Wasp.LSP.Handlers
  ( initializedHandler,
    didOpenHandler,
    didChangeHandler,
    didSaveHandler,
  )
where

import Control.Lens ((+~), (^.))
import Control.Monad.Trans (lift)
import Control.Monad.Trans.Except (throwE)
import Data.Function ((&))
import Data.Text (Text)
import qualified Data.Text as T
import Language.LSP.Server (Handlers, LspT)
import qualified Language.LSP.Server as LSP
import qualified Language.LSP.Types as LSP
import qualified Language.LSP.Types.Lens as LSP
import Language.LSP.VFS (virtualFileText)
import qualified Wasp.Analyzer
import qualified Wasp.Analyzer.AnalyzeError as WE
import Wasp.Analyzer.Parser (Ctx (Ctx))
import Wasp.Analyzer.Parser.SourceRegion (getRgnEnd, getRgnStart)
import Wasp.LSP.Core (ServerConfig, ServerError (ServerError), ServerM, Severity (..))

-- LSP notification and request handlers

-- | "Initialized" notification is sent when the client is started. We don't
-- have anything we need to do at initialization, but this is required to be
-- implemented.
--
-- The client starts the LSP at its own discretion, but commonly this is done
-- either when:
--
-- - A file of the associated language is opened (in this case `.wasp`)
-- - A workspace is opened that has a project structure associated with the
--   language (in this case, a `main.wasp` file in the root folder of the
--   workspace)
initializedHandler :: Handlers ServerM
initializedHandler =
  LSP.notificationHandler LSP.SInitialized $ const (return ())

-- | "TextDocumentDidOpen" is sent by the client when a new document is opened.
-- `diagnoseWaspFile` is run to analyze the newly opened document.
didOpenHandler :: Handlers ServerM
didOpenHandler =
  LSP.notificationHandler LSP.STextDocumentDidOpen $ diagnoseWaspFile . extractUri

-- | "TextDocumentDidChange" is sent by the client when a document is changed
-- (i.e. when the user types/deletes text). `diagnoseWaspFile` is run to
-- analyze the changed document.
didChangeHandler :: Handlers ServerM
didChangeHandler =
  LSP.notificationHandler LSP.STextDocumentDidChange $ diagnoseWaspFile . extractUri

-- | "TextDocumentDidSave" is sent by the client when a document is saved.
-- `diagnoseWaspFile` is run to analyze the new contents of the document.
didSaveHandler :: Handlers ServerM
didSaveHandler =
  LSP.notificationHandler LSP.STextDocumentDidSave $ diagnoseWaspFile . extractUri

-- | Does not directly handle a notification or event, but should be run when
-- text document content changes.
--
-- It analyzes the document contents and sends any error messages back to the
-- LSP client. In the future, it will also store information about the analyzed
-- file in "Wasp.LSP.State.State".
diagnoseWaspFile :: LSP.Uri -> ServerM ()
diagnoseWaspFile uri = do
  src <- readVFSFile uri
  let appSpecOrError = Wasp.Analyzer.analyze $ T.unpack src
  diagnostics <- case appSpecOrError of
    -- Valid wasp file, send no diagnostics
    Right _ -> return $ LSP.List []
    -- Report the error (for now, just one error per analyze is possible)
    Left err ->
      return $
        LSP.List
          [ waspErrorToLspDiagnostic err
          ]
  liftLSP $
    LSP.sendNotification LSP.STextDocumentPublishDiagnostics $
      LSP.PublishDiagnosticsParams uri Nothing diagnostics
  where
    waspErrorToLspDiagnostic :: WE.AnalyzeError -> LSP.Diagnostic
    waspErrorToLspDiagnostic err =
      let errSrc = case err of
            WE.ParseError _ -> "parse"
            WE.TypeError _ -> "typecheck"
            WE.EvaluationError _ -> "evaluate"
          (errMsg, errCtx) = WE.getErrorMessageAndCtx err
       in LSP.Diagnostic
            { _range = waspCtxToLspRange errCtx,
              _severity = Nothing,
              _code = Nothing,
              _source = Just errSrc,
              _message = T.pack errMsg,
              _tags = Nothing,
              _relatedInformation = Nothing
            }

    waspCtxToLspRange :: Ctx -> LSP.Range
    waspCtxToLspRange (Ctx region) =
      LSP.Range
        { _start = waspSourcePositionToLspPosition (getRgnStart region),
          -- Increment end character by 1: Wasp uses an inclusive convention for
          -- the end position, but LSP considers end position to not be part of
          -- the range.
          _end = waspSourcePositionToLspPosition (getRgnEnd region) & LSP.character +~ (1 :: LSP.UInt)
        }

    waspSourcePositionToLspPosition (WE.SourcePosition l c) =
      LSP.Position (fromIntegral $ l - 1) (fromIntegral $ c - 1)

-- | Run a LSP function in the "ServerM" monad.
liftLSP :: LspT ServerConfig IO a -> ServerM a
liftLSP m = lift (lift m)

-- | Read the contents of a "Uri" in the virtual file system maintained by the
-- LSP library.
readVFSFile :: LSP.Uri -> ServerM Text
readVFSFile uri = do
  mVirtualFile <- liftLSP $ LSP.getVirtualFile $ LSP.toNormalizedUri uri
  case mVirtualFile of
    Just virtualFile -> return $ virtualFileText virtualFile
    Nothing -> throwE $ ServerError Error $ "Could not find " <> T.pack (show uri) <> " in VFS."

-- | Get the "Uri" from an object that has a "TextDocument".
extractUri :: (LSP.HasParams a b, LSP.HasTextDocument b c, LSP.HasUri c LSP.Uri) => a -> LSP.Uri
extractUri = (^. (LSP.params . LSP.textDocument . LSP.uri))
