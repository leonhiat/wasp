module Wasp.Wasp.JsImport
  ( JsImport (..),
  )
where

import Data.Aeson (ToJSON (..), object, (.=))
import StrongPath (File', Path, Posix, Rel)
import qualified StrongPath as SP
import Wasp.AppSpec.ExternalCode (SourceExternalCodeDir)

-- | Represents javascript import -> "import <what> from <from>".
data JsImport = JsImport
  { _defaultImport :: !(Maybe String),
    _namedImports :: ![String],
    _from :: Path Posix (Rel SourceExternalCodeDir) File'
  }
  deriving (Show, Eq)

instance ToJSON JsImport where
  toJSON jsImport =
    object
      [ "defaultImport" .= _defaultImport jsImport,
        "namedImports" .= _namedImports jsImport,
        "from" .= SP.fromRelFileP (_from jsImport)
      ]
