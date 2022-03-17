{-# LANGUAGE TypeApplications #-}

module Wasp.AppSpec
  ( AppSpec (..),
    Decl,
    getDecls,
    takeDecls,
    Ref,
    refName,
    getActions,
    getQueries,
    getEntities,
    getPages,
    getRoutes,
    resolveRef,
  )
where

import Data.List (find)
import Data.Maybe (fromMaybe)
import StrongPath (Abs, Dir, File', Path')
import Wasp.AppSpec.Action (Action)
import Wasp.AppSpec.Core.Decl (Decl, IsDecl, takeDecls)
import Wasp.AppSpec.Core.Ref (Ref, refName)
import Wasp.AppSpec.Entity (Entity)
import qualified Wasp.AppSpec.ExternalCode as ExternalCode
import Wasp.AppSpec.Page (Page)
import Wasp.AppSpec.Query (Query)
import Wasp.AppSpec.Route (Route)
import Wasp.Common (DbMigrationsDir)

-- | AppSpec is the main/central intermediate representation (IR) of the whole Wasp compiler,
-- describing the web app specification with all the details needed to generate it.
-- It is standalone and de-coupled from other parts of the compiler and knows nothing about them,
-- instead other parts are using it: Analyzer produces AppSpec while Generator consumes it.
data AppSpec = AppSpec
  { -- | List of declarations like App, Page, Route, ... that describe the web app.
    decls :: [Decl],
    -- | List of external code files (they are referenced/used by the declarations).
    externalCodeFiles :: [ExternalCode.File],
    -- | Absolute path to the directory in wasp project source that contains external code files.
    externalCodeDirPath :: !(Path' Abs (Dir ExternalCode.SourceExternalCodeDir)),
    -- | Absolute path to the directory in wasp project source that contains database migrations.
    migrationsDir :: Maybe (Path' Abs (Dir DbMigrationsDir)),
    -- | Absolute path to the .env file in wasp project source. It contains env variables to be
    -- provided to the server only during the development.
    dotEnvFile :: Maybe (Path' Abs File'),
    -- | If true, it means project is being compiled for production/deployment -> it is being "built".
    -- If false, it means project is being compiled for development purposes (e.g. "wasp start").
    isBuild :: Bool
  }

-- TODO: Make this return "Named" declarations?
-- We would have something like NamedDecl or smth like that. Or at least have a @type Named@ or smth like that.
-- Or @WithName@ or just @Named@.
-- I like the best: `newtype Named a = Named (String, a)`
-- I created a github issue for it: https://github.com/wasp-lang/wasp/issues/426 .
getDecls :: IsDecl a => AppSpec -> [(String, a)]
getDecls = takeDecls . decls

getQueries :: AppSpec -> [(String, Query)]
getQueries = getDecls @Query

getActions :: AppSpec -> [(String, Action)]
getActions = getDecls @Action

getEntities :: AppSpec -> [(String, Entity)]
getEntities = getDecls @Entity

getPages :: AppSpec -> [(String, Page)]
getPages = getDecls @Page

getRoutes :: AppSpec -> [(String, Route)]
getRoutes = getDecls @Route

resolveRef :: (IsDecl d) => AppSpec -> Ref d -> (String, d)
resolveRef spec ref =
  fromMaybe
    ( error $
        "Failed to resolve declaration reference: " ++ refName ref ++ "."
          ++ " This should never happen, as Analyzer should ensure all references in AppSpec are valid."
    )
    $ find ((== refName ref) . fst) $ getDecls spec
