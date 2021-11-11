module Generator.ExternalCodeGenerator.JsTest where

import qualified StrongPath as SP
import Test.Tasty.Hspec
import Wasp.Generator.ExternalCodeGenerator.Common (asGenExtFile)
import Wasp.Generator.ExternalCodeGenerator.Js as Js

spec_resolveJsFileWaspImportsForExtCodeDir :: Spec
spec_resolveJsFileWaspImportsForExtCodeDir = do
  (asGenExtFile [SP.relfile|extFile.js|], "import foo from 'bar'") ~> "import foo from 'bar'"
  (asGenExtFile [SP.relfile|extFile.js|], "import foo from '@wasp/bar'") ~> "import foo from '../bar'"
  (asGenExtFile [SP.relfile|a/extFile.js|], "import foo from  \"@wasp/bar/foo\"")
    ~> "import foo from  \"../../bar/foo\""
  where
    (path, text) ~> expectedText =
      it (SP.toFilePath path ++ " " ++ show text ++ " -> " ++ show expectedText) $ do
        Js.resolveJsFileWaspImportsForExtCodeDir [SP.reldir|src|] path text `shouldBe` expectedText
