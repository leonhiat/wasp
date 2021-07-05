module Generator.Setup
  ( setup,
  )
where

import Control.Concurrent (Chan, newChan, readChan)
import Control.Concurrent.Async (concurrently)
import Generator.Common (ProjectRootDir)
import qualified Generator.Job as J
import Generator.Job.IO (printPrefixedJobMessage)
import Generator.ServerGenerator.Setup (setupServer)
import Generator.WebAppGenerator.Setup (setupWebApp)
import StrongPath (Abs, Dir, Path')
import System.Exit (ExitCode (..))

setup :: Path' Abs (Dir ProjectRootDir) -> IO (Either String ())
setup projectDir = do
  chan <- newChan
  let runSetupJobs = concurrently (setupServer projectDir chan) (setupWebApp projectDir chan)
  (_, result) <- concurrently (handleJobMessages chan) runSetupJobs
  case result of
    (ExitSuccess, ExitSuccess) -> return $ Right ()
    exitCodes -> return $ Left $ setupFailedMessage exitCodes
  where
    handleJobMessages = go Nothing (False, False)
      where
        go :: Maybe J.JobMessage -> (Bool, Bool) -> Chan J.JobMessage -> IO ()
        go _ (True, True) _ = return ()
        go prevJobMsg (isWebAppDone, isServerDone) chan = do
          jobMsg <- readChan chan
          case J._data jobMsg of
            J.JobOutput {} ->
              printPrefixedJobMessage prevJobMsg jobMsg
                >> go (Just jobMsg) (isWebAppDone, isServerDone) chan
            J.JobExit {} -> case J._jobType jobMsg of
              J.WebApp -> go (Just jobMsg) (True, isServerDone) chan
              J.Server -> go (Just jobMsg) (isWebAppDone, True) chan
              J.Db -> error "This should never happen. No db job should be active."

    setupFailedMessage (serverExitCode, webAppExitCode) =
      let serverErrorMessage = case serverExitCode of
            ExitFailure code -> " Server setup failed with exit code " ++ show code ++ "."
            _ -> ""
          webAppErrorMessage = case webAppExitCode of
            ExitFailure code -> " Web app setup failed with exit code " ++ show code ++ "."
            _ -> ""
       in "Setup failed!" ++ serverErrorMessage ++ webAppErrorMessage
