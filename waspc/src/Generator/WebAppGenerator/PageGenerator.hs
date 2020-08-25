module Generator.WebAppGenerator.PageGenerator
       ( generatePages

       -- EXPORTED ONLY FOR TESTS:
       , generatePage
       , generatePageComponent
       , generatePageStyle
       ) where

import Data.Maybe (fromJust, fromMaybe)
import Data.Aeson ((.=), object)
import qualified Data.Aeson as Aeson
import qualified System.FilePath as FP
import qualified Path as P

import Path.Extra (reversePath)
import StrongPath (Path, File, Rel, Dir, (</>))
import qualified StrongPath as SP
import qualified Util
import Wasp (Wasp)
import qualified Wasp
import qualified Wasp.Page as WP
import qualified Wasp.Style as WStyle
import qualified Wasp.JsImport as WJsImport
import qualified Wasp.Entity as WEntity
import Generator.FileDraft
import Generator.ExternalCodeGenerator.Common (castRelPathFromSrcToGenExtCodeDir)
import qualified Generator.WebAppGenerator.EntityGenerator as EntityGenerator
import qualified Generator.WebAppGenerator.EntityGenerator.EntityFormGenerator as GEF
import qualified Generator.WebAppGenerator.EntityGenerator.EntityListGenerator as GEL
import qualified Generator.WebAppGenerator.Common as Common
import Generator.WebAppGenerator.ExternalCodeGenerator (extCodeDirInWebAppSrcDir)


generatePages :: Wasp -> [FileDraft]
generatePages wasp = concatMap (generatePage wasp) (Wasp.getPages wasp)

generatePage :: Wasp -> WP.Page -> [FileDraft]
generatePage wasp page =
    [ generatePageComponent wasp page
    ]
    ++ maybe [] fst (generatePageStyle wasp page)

generatePageComponent :: Wasp -> WP.Page -> FileDraft
generatePageComponent wasp page = Common.makeTemplateFD tmplPath dstPath (Just templateData)
  where
    tmplPath = SP.fromPathRelFile [P.relfile|src/_Page.js|] :: Path (Rel Common.WebAppTemplatesDir) File
    dstPath = Common.webAppSrcDirInWebAppRootDir </> pageDirPathInSrc
              </> (fromJust $ SP.parseRelFile $ (WP.pageName page) ++ ".js")
    templateData = object $
        [ "wasp" .= wasp
        , "page" .= page
        , "entities" .= map toEntityData (Wasp.getEntities wasp)
        , "jsImports" .= map toJsImportData (Wasp.getJsImports wasp)
        ]
        ++ maybe []
                 (\(_, path) -> ["pageStylePath" .= (buildImportPathFromPathInSrc path)])
                 (generatePageStyle wasp page)

    toEntityData entity = object
        [ "entity" .= entity
        , "entityLowerName" .= (Util.toLowerFirst $ WEntity.entityName entity)
        , "entityUpperName" .= (Util.toUpperFirst $ WEntity.entityName entity)
        , "entityStatePath" .=
            (buildImportPathFromPathInSrc $ EntityGenerator.entityStatePathInSrc entity)
        , "entityActionsPath" .=
            (buildImportPathFromPathInSrc $ EntityGenerator.entityActionsPathInSrc entity)
        , "entityClassPath" .=
            (buildImportPathFromPathInSrc $ EntityGenerator.entityClassPathInSrc entity)
        , "entityCreateForms" .= map toEntityFormData entityForms
        , "entityLists" .= map toEntityListData entityLists
        ]
        where
            -- Entity forms
            entityForms = Wasp.getEntityFormsForEntity wasp entity
            generateEntityFormPath entityForm =
                buildImportPathFromPathInSrc $ GEF.entityCreateFormPathInSrc entity entityForm

            toEntityFormData entityForm = object
                [ "entityForm" .= entityForm
                , "path" .= generateEntityFormPath entityForm
                ]

            -- Entity list
            entityLists = Wasp.getEntityListsForEntity wasp entity
            generateEntityListPath entityList =
                buildImportPathFromPathInSrc $ GEL.entityListPathInSrc entity entityList

            toEntityListData entityList = object
                [ "entityList" .= entityList
                , "path" .= generateEntityListPath entityList
                ]

    toJsImportData :: WJsImport.JsImport -> Aeson.Value
    toJsImportData jsImport = object
        [ "what" .= fromMaybe (error "Expected default JS import.") (WJsImport.jsImportDefaultImport jsImport)
        -- NOTE: Here we assume that "from" is relative to external code dir path.
        --   If this part will be reused, consider externalizing this assumption, so we don't have it on multiple places.
        , "from" .= buildImportPathFromPathInSrc
            (extCodeDirInWebAppSrcDir </> castRelPathFromSrcToGenExtCodeDir (WJsImport.jsImportFrom jsImport))
        ]

data PageDir

pageDirPathInSrc :: Path (Rel Common.WebAppSrcDir) (Dir PageDir)
pageDirPathInSrc = SP.fromPathRelDir [P.reldir|.|]

relPathFromPageToSrc :: FilePath
relPathFromPageToSrc = reversePath $ SP.toPathRelDir pageDirPathInSrc

-- | Takes path relative to the src path of generated project and turns it into relative path that can be
-- used as "from" part of the import in the Page source file.
-- NOTE: Here we return FilePath instead of Path because we need stuff like "./" or "../" in the path,
-- which Path would normalize away.
buildImportPathFromPathInSrc :: Path (Rel Common.WebAppSrcDir) a -> FilePath
buildImportPathFromPathInSrc pathInSrc = relPathFromPageToSrc FP.</> (SP.toFilePath pathInSrc)

-- Returns file draft(s) that need to be created (if any) +
-- file path via which to import the style (relative to generated src dir).
generatePageStyle :: Wasp -> WP.Page -> Maybe ([FileDraft], Path (Rel Common.WebAppSrcDir) File)
generatePageStyle _ page = makeDraftsAndPath <$> WP.pageStyle page
  where
    makeDraftsAndPath :: WStyle.Style -> ([FileDraft], Path (Rel Common.WebAppSrcDir) File)
    makeDraftsAndPath (WStyle.CssCode code) =
        let stylePathInSrcDir = fromJust $ SP.parseRelFile $ (WP.pageName page) ++ ".css"
            draftDstPath = Common.webAppSrcDirInProjectRootDir </> stylePathInSrcDir
        in ([createTextFileDraft draftDstPath code], stylePathInSrcDir)
    makeDraftsAndPath (WStyle.ExtCodeCssFile pathInExtCodeDir) =
        ([], extCodeDirInWebAppSrcDir </> (castRelPathFromSrcToGenExtCodeDir pathInExtCodeDir))
