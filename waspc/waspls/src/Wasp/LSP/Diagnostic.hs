module Wasp.LSP.Diagnostic
  ( WaspDiagnostic (..),
    MissingImportReason (..),
    waspDiagnosticToLspDiagnostic,
    clearMissingImportDiagnostics,
  )
where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Language.LSP.Types as LSP
import qualified StrongPath as SP
import qualified Wasp.Analyzer.AnalyzeError as W
import qualified Wasp.Analyzer.Parser as W
import qualified Wasp.Analyzer.Parser.ConcreteParser.ParseError as CPE
import Wasp.Analyzer.Parser.Ctx (getCtxRgn)
import Wasp.Analyzer.Parser.SourcePosition (SourcePosition (..), sourceOffsetToPosition)
import Wasp.Analyzer.Parser.SourceRegion (sourceSpanToRegion)
import Wasp.Analyzer.Parser.SourceSpan (SourceSpan (..))
import Wasp.LSP.Util (waspSourceRegionToLspRange)

data WaspDiagnostic
  = ParseDiagnostic !CPE.ParseError
  | AnalyzerDiagonstic !W.AnalyzeError
  | MissingImportDiagnostic !SourceSpan !MissingImportReason !(SP.Path' SP.Abs SP.File')
  deriving (Eq, Show)

data MissingImportReason = NoDefaultExport | NoNamedExport !String | NoFile
  deriving (Eq, Show)

showMissingImportReason :: MissingImportReason -> SP.Path' SP.Abs SP.File' -> Text
showMissingImportReason NoDefaultExport tsFile =
  "No default export in " <> Text.pack (SP.fromAbsFile tsFile)
showMissingImportReason (NoNamedExport name) tsFile =
  "`" <> Text.pack name <> "` is not exported from " <> Text.pack (SP.fromAbsFile tsFile)
showMissingImportReason NoFile tsFile =
  Text.pack (SP.fromAbsFile tsFile) <> " does not exist"

missingImportSeverity :: MissingImportReason -> LSP.DiagnosticSeverity
missingImportSeverity _ = LSP.DsError

waspDiagnosticToLspDiagnostic :: String -> WaspDiagnostic -> LSP.Diagnostic
waspDiagnosticToLspDiagnostic src (ParseDiagnostic err) = concreteParseErrorToDiagnostic src err
waspDiagnosticToLspDiagnostic _ (AnalyzerDiagonstic analyzeError) = waspErrorToDiagnostic analyzeError
waspDiagnosticToLspDiagnostic src (MissingImportDiagnostic sourceSpan reason tsFile) =
  let message = showMissingImportReason reason tsFile
      severity = missingImportSeverity reason
      region = sourceSpanToRegion src sourceSpan
      range = waspSourceRegionToLspRange region
   in LSP.Diagnostic
        { _range = range,
          _severity = Just severity,
          _code = Nothing,
          _source = Just "ts",
          _message = message,
          _tags = Nothing,
          _relatedInformation = Nothing
        }

concreteParseErrorToDiagnostic :: String -> CPE.ParseError -> LSP.Diagnostic
concreteParseErrorToDiagnostic src err =
  let message = Text.pack $ showConcreteParseError src err
      source = "parse"
      range = concreteErrorRange err
   in LSP.Diagnostic
        { _range = range,
          _severity = Just LSP.DsError,
          _code = Nothing,
          _source = Just source,
          _message = message,
          _tags = Nothing,
          _relatedInformation = Nothing
        }
  where
    concreteErrorRange e = case CPE.errorSpan e of
      SourceSpan startOffset endOffset ->
        let startPos = sourceOffsetToPosition src startOffset
            endPos = sourceOffsetToPosition src endOffset
         in LSP.Range (concretePosToLSPPos startPos) (concretePosToLSPPos endPos)
    concretePosToLSPPos (SourcePosition l c) =
      LSP.Position (fromIntegral l - 1) (fromIntegral c - 1)
    showConcreteParseError :: String -> CPE.ParseError -> String
    showConcreteParseError source e =
      let (msg, ctx) = CPE.getErrorMessageAndCtx source e
       in "Parse error at " ++ show (getCtxRgn ctx) ++ ":\n  " ++ msg

waspErrorToDiagnostic :: W.AnalyzeError -> LSP.Diagnostic
waspErrorToDiagnostic err =
  let message = waspErrorAsPrettyEditorMessage err
      source = waspErrorSource err
      range = waspErrorRange err
   in LSP.Diagnostic
        { _range = range,
          _severity = Just LSP.DsError,
          _code = Nothing,
          _source = Just source,
          _message = message,
          _tags = Nothing,
          _relatedInformation = Nothing
        }

-- | Convert a wasp error to a message to display to the developer.
--
-- TODO: Write a new conversion from error to text here that is better suited
-- for in-editor display
waspErrorAsPrettyEditorMessage :: W.AnalyzeError -> Text
waspErrorAsPrettyEditorMessage = Text.pack . fst . W.getErrorMessageAndCtx

waspErrorSource :: W.AnalyzeError -> Text
waspErrorSource (W.ParseError _) = "parse"
waspErrorSource (W.TypeError _) = "typecheck"
waspErrorSource (W.EvaluationError _) = "evaluate"

waspErrorRange :: W.AnalyzeError -> LSP.Range
waspErrorRange err =
  let (_, W.Ctx rgn) = W.getErrorMessageAndCtx err
   in waspSourceRegionToLspRange rgn

clearMissingImportDiagnostics :: [WaspDiagnostic] -> [WaspDiagnostic]
clearMissingImportDiagnostics = filter (not . isMissingImportDiagnostic)
  where
    isMissingImportDiagnostic (MissingImportDiagnostic _ _ _) = True
    isMissingImportDiagnostic _ = False
