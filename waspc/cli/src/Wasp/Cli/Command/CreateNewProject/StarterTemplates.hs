module Wasp.Cli.Command.CreateNewProject.StarterTemplates
  ( getStarterTemplateNames,
    StarterTemplateName (..),
    findTemplateNameByString,
    defaultStarterTemplateName,
  )
where

import Data.Either (fromRight)
import Data.Foldable (find)
import Wasp.Cli.Command.CreateNewProject.StarterTemplates.Remote.Github (starterTemplateGithubRepo)
import qualified Wasp.Cli.GithubRepo as GR

data StarterTemplateName = RemoteStarterTemplate String | LocalStarterTemplate String
  deriving (Eq)

instance Show StarterTemplateName where
  show (RemoteStarterTemplate templateName) = templateName
  show (LocalStarterTemplate templateName) = templateName

getStarterTemplateNames :: IO [StarterTemplateName]
getStarterTemplateNames = do
  remoteTemplates <- fromRight [] <$> fetchRemoteStarterTemplateNames
  return $ localTemplates ++ remoteTemplates

fetchRemoteStarterTemplateNames :: IO (Either String [StarterTemplateName])
fetchRemoteStarterTemplateNames = do
  fmap extractTemplateNames <$> GR.fetchRepoRootFolderContents starterTemplateGithubRepo
  where
    extractTemplateNames :: GR.RepoFolderContents -> [StarterTemplateName]
    -- Each folder in the repo is a template.
    extractTemplateNames = map (RemoteStarterTemplate . GR._name) . filter ((== GR.Folder) . GR._type)

localTemplates :: [StarterTemplateName]
localTemplates = [defaultStarterTemplateName]

defaultStarterTemplateName :: StarterTemplateName
defaultStarterTemplateName = LocalStarterTemplate "basic"

findTemplateNameByString :: [StarterTemplateName] -> String -> Maybe StarterTemplateName
findTemplateNameByString templateNames query = find ((== query) . show) templateNames
