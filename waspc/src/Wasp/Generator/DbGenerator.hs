{-# LANGUAGE TypeApplications #-}

module Wasp.Generator.DbGenerator
  ( genDb,
    warnIfDbNeedsMigration,
    genPrismaClient,
    postWriteDbGeneratorActions,
  )
where

import Data.Aeson (object, (.=))
import Data.Maybe (fromMaybe, maybeToList)
import StrongPath (Abs, Dir, Path', (</>))
import qualified StrongPath as SP
import System.Directory (doesFileExist)
import Wasp.AppSpec (AppSpec, getEntities)
import qualified Wasp.AppSpec as AS
import qualified Wasp.AppSpec.App as AS.App
import qualified Wasp.AppSpec.App.Db as AS.Db
import qualified Wasp.AppSpec.Entity as AS.Entity
import Wasp.AppSpec.Valid (getApp)
import Wasp.Generator.Common (ProjectRootDir)
import Wasp.Generator.DbGenerator.Common
  ( dbMigrationsDirInDbRootDir,
    dbRootDirInProjectRootDir,
    dbSchemaChecksumOnLastDbConcurrenceFileProjectRootDir,
    dbSchemaChecksumOnLastGenerateFileProjectRootDir,
    dbSchemaFileInDbTemplatesDir,
    dbSchemaFileInProjectRootDir,
    dbTemplatesDirInTemplatesDir,
  )
import qualified Wasp.Generator.DbGenerator.Operations as DbOps
import Wasp.Generator.FileDraft (FileDraft, createCopyDirFileDraft, createTemplateFileDraft)
import Wasp.Generator.Monad
  ( Generator,
    GeneratorError (..),
    GeneratorWarning (GeneratorNeedsMigrationWarning),
    logAndThrowGeneratorError,
  )
import qualified Wasp.Psl.Ast.Model as Psl.Ast.Model
import qualified Wasp.Psl.Generator.Model as Psl.Generator.Model
import Wasp.Util (checksumFromFilePath, hexToString, ifM, (<:>))

genDb :: AppSpec -> Generator [FileDraft]
genDb spec =
  genPrismaSchema spec <:> (maybeToList <$> genMigrationsDir spec)

genPrismaSchema :: AppSpec -> Generator FileDraft
genPrismaSchema spec = do
  (datasourceProvider, datasourceUrl) <- case dbSystem of
    AS.Db.PostgreSQL -> return ("postgresql", "env(\"DATABASE_URL\")")
    AS.Db.SQLite ->
      if AS.isBuild spec
        then logAndThrowGeneratorError $ GenericGeneratorError "SQLite (a default database) is not supported in production. To build your Wasp app for production, switch to a different database. Switching to PostgreSQL: https://wasp-lang.dev/docs/language/features#migrating-from-sqlite-to-postgresql ."
        else return ("sqlite", "\"file:./dev.db\"")

  let templateData =
        object
          [ "modelSchemas" .= map entityToPslModelSchema (AS.getDecls @AS.Entity.Entity spec),
            "datasourceProvider" .= (datasourceProvider :: String),
            "datasourceUrl" .= (datasourceUrl :: String)
          ]

  return $ createTemplateFileDraft dstPath tmplSrcPath (Just templateData)
  where
    dstPath = dbSchemaFileInProjectRootDir
    tmplSrcPath = dbTemplatesDirInTemplatesDir </> dbSchemaFileInDbTemplatesDir
    dbSystem = fromMaybe AS.Db.SQLite (AS.Db.system =<< AS.App.db (snd $ getApp spec))

    entityToPslModelSchema :: (String, AS.Entity.Entity) -> String
    entityToPslModelSchema (entityName, entity) =
      Psl.Generator.Model.generateModel $
        Psl.Ast.Model.Model entityName (AS.Entity.getPslModelBody entity)

genMigrationsDir :: AppSpec -> Generator (Maybe FileDraft)
genMigrationsDir spec =
  return $
    AS.migrationsDir spec >>= \waspMigrationsDir ->
      Just $ createCopyDirFileDraft (SP.castDir genProjectMigrationsDir) (SP.castDir waspMigrationsDir)
  where
    genProjectMigrationsDir = dbRootDirInProjectRootDir </> dbMigrationsDirInDbRootDir

-- | This function operates on generated code, and thus assumes the file drafts were written to disk
postWriteDbGeneratorActions :: AppSpec -> Path' Abs (Dir ProjectRootDir) -> IO ([GeneratorWarning], [GeneratorError])
postWriteDbGeneratorActions spec dstDir = do
  dbGeneratorWarnings <- maybeToList <$> warnIfDbNeedsMigration spec dstDir
  dbGeneratorErrors <- maybeToList <$> genPrismaClient spec dstDir
  return (dbGeneratorWarnings, dbGeneratorErrors)

-- | Checks if user needs to run `wasp db migrate-dev` due to changes in schema.prisma, and if so, returns a warning.
-- When doing this, it looks at schema.prisma in the generated project.
--
-- This function makes following assumptions:
--  - schema.prisma will exist in the generated project even if no Entities were defined.
--    Due to how Prisma itself works, this assumption is currently fulfilled.
--  - schema.prisma.wasp-last-db-concurrence-checksum contains the checksum of the schema.prisma as it was when we last ensured it matched the DB.
--
-- Given that, there are two cases in which we wish to warn the user to run `wasp db migrate-dev`:
-- (1) If schema.prisma.wasp-last-db-concurrence-checksum exists, but is not equal to checksum(schema.prisma), we know there were changes to schema.prisma and they should migrate.
-- (2) If schema.prisma.wasp-last-db-concurrence-checksum does not exist, but the user has entities defined in schema.prisma (and thus, AppSpec).
--     This could imply they have never migrated locally, or that they have but are simply missing their generated project dir.
--     Common scenarios for the second warning include:
--       - After a fresh checkout, or after `wasp clean`.
--       - When they previously had no entities and just added their first.
--     In either of those scenarios, validate against DB itself to avoid redundant warnings.
--
--     NOTE: As one final optimization, if they do not have a schema.prisma.wasp-last-db-concurrence-checksum but the schema is
--     in sync with the database and all migrations are applied, we generate that file to avoid future checks.
warnIfDbNeedsMigration :: AppSpec -> Path' Abs (Dir ProjectRootDir) -> IO (Maybe GeneratorWarning)
warnIfDbNeedsMigration spec projectRootDir = do
  dbSchemaChecksumFileExists <- doesFileExist dbSchemaChecksumFp
  if dbSchemaChecksumFileExists
    then warnIfSchemaDiffersFromChecksum dbSchemaFp dbSchemaChecksumFp
    else
      if entitiesExist
        then warnProjectDiffersFromDb projectRootDir
        else return Nothing
  where
    dbSchemaFp = SP.fromAbsFile $ projectRootDir </> dbSchemaFileInProjectRootDir
    dbSchemaChecksumFp = SP.fromAbsFile $ projectRootDir </> dbSchemaChecksumOnLastDbConcurrenceFileProjectRootDir
    entitiesExist = not . null $ getEntities spec

warnIfSchemaDiffersFromChecksum :: FilePath -> FilePath -> IO (Maybe GeneratorWarning)
warnIfSchemaDiffersFromChecksum dbSchemaFp dbSchemaChecksumFp = do
  dbSchemaFileChecksum <- hexToString <$> checksumFromFilePath dbSchemaFp
  dbChecksumFileContents <- readFile dbSchemaChecksumFp
  if dbSchemaFileChecksum /= dbChecksumFileContents
    then return . Just $ GeneratorNeedsMigrationWarning "Your Prisma schema has changed, please run `wasp db migrate-dev` when ready."
    else return Nothing

-- | Checks if the project's Prisma schema file and migrations dir matches the DB state.
-- Issues a warning if it cannot connect, or if either check fails.
warnProjectDiffersFromDb :: Path' Abs (Dir ProjectRootDir) -> IO (Maybe GeneratorWarning)
warnProjectDiffersFromDb projectRootDir = do
  schemaMatchesDb <- DbOps.doesSchemaMatchDb projectRootDir
  case schemaMatchesDb of
    Just True -> do
      allMigrationsAppliedToDb <- DbOps.areAllMigrationsAppliedToDb projectRootDir
      if allMigrationsAppliedToDb == Just True
        then do
          -- NOTE: Since we know schema == db and all migrations are applied,
          -- we can write this file to prevent future redundant Prisma checks.
          DbOps.writeDbSchemaChecksumToFile projectRootDir (SP.castFile dbSchemaChecksumOnLastDbConcurrenceFileProjectRootDir)
          return Nothing
        else return . Just $ GeneratorNeedsMigrationWarning "You have unapplied migrations. Please run `wasp db migrate-dev` when ready."
    Just False -> return . Just $ GeneratorNeedsMigrationWarning "Your Prisma schema does not match your database, please run `wasp db migrate-dev`."
    -- NOTE: If there was an error, it could mean we could not connect to the SQLite db, since it does not exist.
    -- Or it could mean their DATABASE_URL is wrong, or database is down, or any other number of causes.
    -- In any case, migrating will either solve it (in the SQLite case), or allow Prisma to give them enough info to troubleshoot.
    Nothing -> return . Just $ GeneratorNeedsMigrationWarning "Wasp was unable to verify your database is up to date. Running `wasp db migrate-dev` may fix this and will provide more info."

genPrismaClient :: AppSpec -> Path' Abs (Dir ProjectRootDir) -> IO (Maybe GeneratorError)
genPrismaClient spec projectRootDir = do
  ifM wasCurrentSchemaAlreadyGenerated (return Nothing) generatePrismaClientIfEntitiesExist
  where
    wasCurrentSchemaAlreadyGenerated :: IO Bool
    wasCurrentSchemaAlreadyGenerated = do
      let dbSchemaFp = SP.fromAbsFile $ projectRootDir SP.</> dbSchemaFileInProjectRootDir
      let dbSchemaChecksumFp = SP.fromAbsFile $ projectRootDir SP.</> dbSchemaChecksumOnLastGenerateFileProjectRootDir

      dbSchemaChecksumFileExists <- doesFileExist dbSchemaChecksumFp
      if dbSchemaChecksumFileExists
        then do
          dbSchemaFileChecksum <- hexToString <$> checksumFromFilePath dbSchemaFp
          dbChecksumFileContents <- readFile dbSchemaChecksumFp
          return $ dbSchemaFileChecksum == dbChecksumFileContents
        else return False

    generatePrismaClientIfEntitiesExist :: IO (Maybe GeneratorError)
    generatePrismaClientIfEntitiesExist = do
      let entitiesExist = not . null $ getEntities spec
      if entitiesExist
        then either (Just . GenericGeneratorError) (const Nothing) <$> DbOps.generatePrismaClient projectRootDir
        else return Nothing
