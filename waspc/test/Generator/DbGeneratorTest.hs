module Generator.DbGeneratorTest where

import Test.Tasty.Hspec (Spec, it, shouldBe)
import Wasp.Generator.DbGenerator.Common
  ( MigrateArgs (..),
    defaultMigrateArgs,
  )
import Wasp.Generator.DbGenerator.Jobs (asPrismaCliArgs)

spec_Jobs :: Spec
spec_Jobs =
  it "should produce expected args" $ do
    asPrismaCliArgs defaultMigrateArgs `shouldBe` []
    asPrismaCliArgs (MigrateArgs {_migrationName = Nothing, _isCreateOnlyMigration = True})
      `shouldBe` ["--create-only"]
    asPrismaCliArgs (MigrateArgs {_migrationName = Just "something", _isCreateOnlyMigration = False})
      `shouldBe` ["--name", "something"]
    asPrismaCliArgs (MigrateArgs {_migrationName = Just "something else longer", _isCreateOnlyMigration = False})
      `shouldBe` ["--name", "something else longer"]
    asPrismaCliArgs (MigrateArgs {_migrationName = Just "something", _isCreateOnlyMigration = True})
      `shouldBe` ["--create-only", "--name", "something"]
