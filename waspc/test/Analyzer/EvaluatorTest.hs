{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}

module Analyzer.EvaluatorTest where

import AST.Core.Ref (Ref (..))
import Analyzer.Evaluator
import Analyzer.Evaluator.TH
import Analyzer.Parser (ExtImportName (ExtImportField, ExtImportModule), parse)
import Analyzer.TypeChecker (typeCheck)
import qualified Analyzer.TypeDefinitions as TD
import Data.Data (Data)
import Test.Tasty.Hspec

fromRight :: Show a => Either a b -> b
fromRight (Right x) = x
fromRight (Left e) = error $ show e

newtype Simple = Simple String deriving (Eq, Show, Data)

makeDeclType ''Simple

data Fields = Fields {a :: String, b :: Maybe Double} deriving (Eq, Show, Data)

makeDeclType ''Fields

data Person = Person {name :: String, age :: Integer} deriving (Eq, Show, Data)

makeDeclType ''Person

data BusinessType = Manufacturer | Seller | Store deriving (Eq, Show, Data)

makeEnumType ''BusinessType

data Special = Special {imps :: [ExtImport], json :: JSON, psl :: PSL} deriving (Eq, Show)

makeDeclType ''Special

data Business = Business
  { employees :: [Ref Person],
    worth :: Double,
    businessType :: BusinessType,
    location :: Maybe String
  }
  deriving (Eq, Show, Data)

makeDeclType ''Business

eval :: TD.TypeDefinitions -> [String] -> Either EvaluationError [Decl]
eval typeDefs source = evaluate typeDefs $ fromRight $ typeCheck typeDefs $ fromRight $ parse $ unlines source

spec_Evaluator :: Spec
spec_Evaluator = do
  describe "Analyzer.Evaluator" $
    describe "evaluate" $ do
      it "Evaluates a simple declaration" $ do
        let typeDefs = TD.addDeclType @Simple $ TD.empty
        let decls = eval typeDefs ["simple Test \"hello wasp\""]
        fmap takeDecls decls
          `shouldBe` Right [("Test", Simple "hello wasp")]
      it "Evaluates a declaration with a dictionary" $ do
        let typeDefs = TD.addDeclType @Fields $ TD.empty
        let decls = eval typeDefs ["fields Test { a: \"hello wasp\", b: 3.14 }"]
        fmap takeDecls decls
          `shouldBe` Right [("Test", Fields {a = "hello wasp", b = Just 3.14})]
      it "Evaluates a declaration with missing optional fields" $ do
        let typeDefs = TD.addDeclType @Fields $ TD.empty
        let decls = eval typeDefs ["fields Test { a: \"hello wasp\" }"]
        fmap takeDecls decls
          `shouldBe` Right [("Test", Fields {a = "hello wasp", b = Nothing})]
      it "Evaluates a complicated example" $ do
        let typeDefs =
              TD.addDeclType @Business $
                TD.addEnumType @BusinessType $
                  TD.addDeclType @Person $ TD.empty
        let source =
              [ "person Tim { name: \"Tim Stocker\", age: 40 }",
                "person John { name: \"John Cashier\", age: 23 }",
                "business Grocer { employees: [Tim, John], businessType: Store, worth: 115 }"
              ]
        fmap takeDecls (eval typeDefs source)
          `shouldBe` Right
            [ ( "Grocer",
                Business
                  { employees = [Ref "Tim", Ref "John"],
                    businessType = Store,
                    worth = 115.0,
                    location = Nothing
                  }
              )
            ]
      it "Evaluates ExtImports, JSON, and PSL" $ do
        let typeDefs = TD.addDeclType @Special $ TD.empty
        let source =
              [ "special Test {",
                "  imps: [import { field } from \"main.js\", import main from \"main.js\"],",
                "  json: {=json \"key\": 1 json=},",
                "  psl: {=psl ID Int psl=}",
                "}"
              ]
        fmap takeDecls (eval typeDefs source)
          `shouldBe` Right
            [ ( "Test",
                Special
                  [ExtImport (ExtImportField "field") "main.js", ExtImport (ExtImportModule "main") "main.js"]
                  (JSON " \"key\": 1 ")
                  (PSL " ID Int ")
              )
            ]
