module Command.Compile
    ( compileIO
    , compile
    , compileIOWithOptions
    ) where

import           Control.Monad.IO.Class (liftIO)
import           Control.Monad.Except     (throwError)

import           Command                  (Command, CommandError (..))
import           Command.Common           (findWaspProjectRootDirFromCwd,
                                           findWaspFile,
                                           waspSaysC)
import qualified Common
import           CompileOptions         (CompileOptions (..))
import qualified Lib
import           StrongPath             (Abs, Dir, Path, (</>))


compile :: Command ()
compile = do
    waspProjectDir <- findWaspProjectRootDirFromCwd
    let outDir = waspProjectDir </> Common.dotWaspDirInWaspProjectDir
                 </> Common.generatedCodeDirInDotWaspDir

    waspSaysC "Compiling wasp code..."
    compilationResult <- liftIO $ compileIO waspProjectDir outDir
    case compilationResult of
        Left compileError -> throwError $ CommandError $ "Compilation failed: " ++ compileError
        Right () -> waspSaysC "Code has been successfully compiled, project has been generated.\n"

-- | Compiles Wasp source code in waspProjectDir directory and generates a project
--   in given outDir directory.
compileIO :: Path Abs (Dir Common.WaspProjectDir)
        -> Path Abs (Dir Lib.ProjectRootDir)
        -> IO (Either String ())
compileIO waspProjectDir outDir = compileIOWithOptions options waspProjectDir outDir
  where
    options = CompileOptions
        { externalCodeDirPath = waspProjectDir </> Common.extCodeDirInWaspProjectDir
        , isBuild = False
        }

compileIOWithOptions :: CompileOptions
                     -> Path Abs (Dir Common.WaspProjectDir)
                     -> Path Abs (Dir Lib.ProjectRootDir)
                     -> IO (Either String ())
compileIOWithOptions options waspProjectDir outDir = do
    maybeWaspFile <- findWaspFile waspProjectDir
    case maybeWaspFile of
        Nothing -> return $ Left "No *.wasp file present in the root of Wasp project."
        Just waspFile -> Lib.compile waspFile outDir options
