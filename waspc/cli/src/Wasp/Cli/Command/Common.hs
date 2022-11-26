module Wasp.Cli.Command.Common
  ( findWaspProjectRootDirFromCwd,
    findWaspProjectRoot,
  )
where

import Control.Monad (unless, when)
import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import Data.Maybe (fromJust)
import StrongPath (Abs, Dir, Path')
import qualified StrongPath as SP
import System.Directory
  ( doesFileExist,
    doesPathExist,
    getCurrentDirectory,
  )
import qualified System.FilePath as FP
import Wasp.Cli.Command (Command, CommandError (..))
import Wasp.Cli.Common (dotWaspRootFileInWaspProjectDir)
import Wasp.Common (WaspProjectDir)

findWaspProjectRoot :: Path' Abs (Dir ()) -> Command (Path' Abs (Dir WaspProjectDir))
findWaspProjectRoot currentDir = do
  let absCurrentDirFp = SP.fromAbsDir currentDir
  doesCurrentDirExist <- liftIO $ doesPathExist absCurrentDirFp
  unless doesCurrentDirExist (throwError notFoundError)
  let dotWaspRootFilePath = absCurrentDirFp FP.</> SP.fromRelFile dotWaspRootFileInWaspProjectDir
  isCurrentDirRoot <- liftIO $ doesFileExist dotWaspRootFilePath
  if isCurrentDirRoot
    then return $ SP.castDir currentDir
    else do
      let parentDir = SP.parent currentDir
      when (parentDir == currentDir) (throwError notFoundError)
      findWaspProjectRoot parentDir
  where
    notFoundError =
      CommandError
        "Wasp command failed"
        ( "Couldn't find wasp project root - make sure"
            ++ " you are running this command from a Wasp project."
        )

findWaspProjectRootDirFromCwd :: Command (Path' Abs (Dir WaspProjectDir))
findWaspProjectRootDirFromCwd = do
  absCurrentDir <- liftIO getCurrentDirectory
  findWaspProjectRoot (fromJust $ SP.parseAbsDir absCurrentDir)
