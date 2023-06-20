module Wasp.Cli.Command.Db.Reset
  ( reset,
  )
where

import Control.Monad.IO.Class (liftIO)
import StrongPath ((</>))
import Wasp.Cli.Command (Command)
import Wasp.Cli.Command.Message (cliSendMessageC)
import Wasp.Cli.Command.Require (InWaspProject (InWaspProject), require)
import qualified Wasp.Cli.Common as Common
import Wasp.Generator.DbGenerator.Operations (dbReset)
import qualified Wasp.Message as Msg

reset :: Command ()
reset = do
  InWaspProject waspProjectDir <- require
  let genProjectDir =
        waspProjectDir </> Common.dotWaspDirInWaspProjectDir </> Common.generatedCodeDirInDotWaspDir

  cliSendMessageC $ Msg.Start "Resetting the database..."

  liftIO (dbReset genProjectDir) >>= \case
    Left errorMsg -> cliSendMessageC $ Msg.Failure "Database reset failed" errorMsg
    Right () -> cliSendMessageC $ Msg.Success "Database reset successfully!"
