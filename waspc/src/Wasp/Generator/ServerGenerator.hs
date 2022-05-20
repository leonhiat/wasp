{-# LANGUAGE TypeApplications #-}

module Wasp.Generator.ServerGenerator
  ( genServer,
    operationsRouteInRootRouter,
    npmDepsForWasp,
  )
where

import Data.Aeson (object, (.=))
import Data.Maybe
  ( fromJust,
    fromMaybe,
    isJust,
  )
import StrongPath
  ( Dir,
    File',
    Path,
    Path',
    Posix,
    Rel,
    reldir,
    reldirP,
    relfile,
    (</>),
  )
import Wasp.AppSpec (AppSpec)
import qualified Wasp.AppSpec as AS
import qualified Wasp.AppSpec.App as AS.App
import qualified Wasp.AppSpec.App.Auth as AS.App.Auth
import qualified Wasp.AppSpec.App.Dependency as AS.Dependency
import qualified Wasp.AppSpec.App.Server as AS.App.Server
import qualified Wasp.AppSpec.Entity as AS.Entity
import Wasp.AppSpec.Util (isPgBossJobExecutorUsed)
import Wasp.AppSpec.Valid (getApp, isAuthEnabled)
import Wasp.Generator.Common (nodeVersion, nodeVersionBounds, npmVersionBounds, prismaVersionBounds)
import Wasp.Generator.ExternalCodeGenerator (genExternalCodeDir)
import Wasp.Generator.ExternalCodeGenerator.Common (GeneratedExternalCodeDir)
import Wasp.Generator.FileDraft (FileDraft, createCopyFileDraft)
import Wasp.Generator.JsImport (getJsImportDetailsForExtFnImport)
import Wasp.Generator.Monad (Generator)
import qualified Wasp.Generator.NpmDependencies as N
import Wasp.Generator.ServerGenerator.AuthG (genAuth)
import qualified Wasp.Generator.ServerGenerator.Common as C
import Wasp.Generator.ServerGenerator.ConfigG (genConfigFile)
import qualified Wasp.Generator.ServerGenerator.ExternalCodeGenerator as ServerExternalCodeGenerator
import Wasp.Generator.ServerGenerator.JobGenerator (depsRequiredByJobs, genJobExecutors, genJobs)
import Wasp.Generator.ServerGenerator.OperationsG (genOperations)
import Wasp.Generator.ServerGenerator.OperationsRoutesG (genOperationsRoutes)
import qualified Wasp.SemanticVersion as SV
import Wasp.Util ((<++>))

genServer :: AppSpec -> Generator [FileDraft]
genServer spec =
  sequence
    [ genReadme,
      genPackageJson spec (npmDepsForWasp spec),
      genNpmrc,
      genNvmrc,
      genGitignore
    ]
    <++> genSrcDir spec
    <++> genExternalCodeDir ServerExternalCodeGenerator.generatorStrategy (AS.externalCodeFiles spec)
    <++> genDotEnv spec
    <++> genJobs spec
    <++> genJobExecutors

genDotEnv :: AppSpec -> Generator [FileDraft]
genDotEnv spec = return $
  case AS.dotEnvFile spec of
    Just srcFilePath
      | not $ AS.isBuild spec ->
          [ createCopyFileDraft
              (C.serverRootDirInProjectRootDir </> dotEnvInServerRootDir)
              srcFilePath
          ]
    _ -> []

dotEnvInServerRootDir :: Path' (Rel C.ServerRootDir) File'
dotEnvInServerRootDir = [relfile|.env|]

genReadme :: Generator FileDraft
genReadme = return $ C.mkTmplFd (C.asTmplFile [relfile|README.md|])

genPackageJson :: AppSpec -> N.NpmDepsForWasp -> Generator FileDraft
genPackageJson spec waspDependencies = do
  combinedDependencies <- N.genNpmDepsForPackage spec waspDependencies
  return $
    C.mkTmplFdWithDstAndData
      (C.asTmplFile [relfile|package.json|])
      (C.asServerFile [relfile|package.json|])
      ( Just $
          object
            [ "depsChunk" .= N.getDependenciesPackageJsonEntry combinedDependencies,
              "devDepsChunk" .= N.getDevDependenciesPackageJsonEntry combinedDependencies,
              "nodeVersionBounds" .= show nodeVersionBounds,
              "npmVersionBounds" .= show npmVersionBounds,
              "startProductionScript"
                .= ( (if not (null $ AS.getDecls @AS.Entity.Entity spec) then "npm run db-migrate-prod && " else "")
                       ++ "NODE_ENV=production node ./src/server.js"
                   )
            ]
      )

npmDepsForWasp :: AppSpec -> N.NpmDepsForWasp
npmDepsForWasp spec =
  N.NpmDepsForWasp
    { N.waspDependencies =
        AS.Dependency.fromList
          [ ("cookie-parser", "~1.4.4"),
            ("cors", "^2.8.5"),
            ("debug", "~2.6.9"),
            ("express", "~4.16.1"),
            ("morgan", "~1.9.1"),
            ("@prisma/client", show prismaVersionBounds),
            ("jsonwebtoken", "^8.5.1"),
            ("secure-password", "^4.0.0"),
            ("dotenv", "8.2.0"),
            ("helmet", "^4.6.0")
          ]
          ++ depsRequiredByJobs spec,
      N.waspDevDependencies =
        AS.Dependency.fromList
          [ ("nodemon", "^2.0.4"),
            ("standard", "^14.3.4"),
            ("prisma", show prismaVersionBounds)
          ]
    }

genNpmrc :: Generator FileDraft
genNpmrc =
  return $
    C.mkTmplFdWithDstAndData
      (C.asTmplFile [relfile|npmrc|])
      (C.asServerFile [relfile|.npmrc|])
      Nothing

genNvmrc :: Generator FileDraft
genNvmrc =
  return $
    C.mkTmplFdWithDstAndData
      (C.asTmplFile [relfile|nvmrc|])
      (C.asServerFile [relfile|.nvmrc|])
      -- We want to specify only the major version here. If we specified the
      -- entire version string (i.e., 16.0.0), our project would work only with
      -- that exact version, which we don't want. Unfortunately, the nvmrc file
      -- format doesn't allow semver compatibility strings (e.g., ^16.0.0) so
      -- listing the major version was the next best thing.
      (Just (object ["nodeVersion" .= show (SV.major nodeVersion)]))

genGitignore :: Generator FileDraft
genGitignore =
  return $
    C.mkTmplFdWithDstAndData
      (C.asTmplFile [relfile|gitignore|])
      (C.asServerFile [relfile|.gitignore|])
      Nothing

genSrcDir :: AppSpec -> Generator [FileDraft]
genSrcDir spec =
  sequence
    [ copyTmplFile [relfile|app.js|],
      copyTmplFile [relfile|utils.js|],
      copyTmplFile [relfile|core/AuthError.js|],
      copyTmplFile [relfile|core/HttpError.js|],
      genDbClient spec,
      genConfigFile spec,
      genServerJs spec
    ]
    <++> genRoutesDir spec
    <++> genOperationsRoutes spec
    <++> genOperations spec
    <++> genAuth spec
  where
    copyTmplFile = return . C.mkSrcTmplFd

genDbClient :: AppSpec -> Generator FileDraft
genDbClient spec = return $ C.mkTmplFdWithDstAndData tmplFile dstFile (Just tmplData)
  where
    maybeAuth = AS.App.auth $ snd $ getApp spec

    dbClientRelToSrcP = [relfile|dbClient.js|]
    tmplFile = C.asTmplFile $ [reldir|src|] </> dbClientRelToSrcP
    dstFile = C.serverSrcDirInServerRootDir </> C.asServerSrcFile dbClientRelToSrcP

    tmplData =
      if isJust maybeAuth
        then
          object
            [ "isAuthEnabled" .= True,
              "userEntityUpper" .= (AS.refName (AS.App.Auth.userEntity $ fromJust maybeAuth) :: String)
            ]
        else object []

genServerJs :: AppSpec -> Generator FileDraft
genServerJs spec =
  return $
    C.mkTmplFdWithDstAndData
      (C.asTmplFile [relfile|src/server.js|])
      (C.asServerFile [relfile|src/server.js|])
      ( Just $
          object
            [ "doesServerSetupFnExist" .= isJust maybeSetupJsFunction,
              "serverSetupJsFnImportStatement" .= fromMaybe "" maybeSetupJsFnImportStmt,
              "serverSetupJsFnIdentifier" .= fromMaybe "" maybeSetupJsFnImportIdentifier,
              "isPgBossJobExecutorUsed" .= isPgBossJobExecutorUsed spec
            ]
      )
  where
    maybeSetupJsFunction = AS.App.Server.setupFn =<< AS.App.server (snd $ getApp spec)
    maybeSetupJsFnImportDetails = getJsImportDetailsForExtFnImport relPosixPathFromSrcDirToExtSrcDir <$> maybeSetupJsFunction
    (maybeSetupJsFnImportIdentifier, maybeSetupJsFnImportStmt) =
      (fst <$> maybeSetupJsFnImportDetails, snd <$> maybeSetupJsFnImportDetails)

-- | TODO: Make this not hardcoded!
relPosixPathFromSrcDirToExtSrcDir :: Path Posix (Rel (Dir C.ServerSrcDir)) (Dir GeneratedExternalCodeDir)
relPosixPathFromSrcDirToExtSrcDir = [reldirP|./ext-src|]

genRoutesDir :: AppSpec -> Generator [FileDraft]
genRoutesDir spec =
  -- TODO(martin): We will probably want to extract "routes" path here same as we did with "src", to avoid hardcoding,
  -- but I did not bother with it yet since it is used only here for now.
  return
    [ C.mkTmplFdWithDstAndData
        (C.asTmplFile [relfile|src/routes/index.js|])
        (C.asServerFile [relfile|src/routes/index.js|])
        ( Just $
            object
              [ "operationsRouteInRootRouter" .= (operationsRouteInRootRouter :: String),
                "isAuthEnabled" .= (isAuthEnabled spec :: Bool)
              ]
        )
    ]

operationsRouteInRootRouter :: String
operationsRouteInRootRouter = "operations"
