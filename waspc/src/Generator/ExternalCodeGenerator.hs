module Generator.ExternalCodeGenerator
       ( generateExternalCodeDir
       ) where

import qualified System.FilePath as FP
import qualified Path

import Wasp (Wasp)
import qualified Wasp
import qualified ExternalCode as EC
import qualified Generator.FileDraft as FD
import qualified Generator.ExternalCodeGenerator.Common as C
import Generator.ExternalCodeGenerator.Js (generateJsFile)


-- | Takes external code files from Wasp and generates them in new location as part of the generated project.
-- It might not just copy them but also do some changes on them, as needed.
generateExternalCodeDir :: C.ExternalCodeGeneratorStrategy
                        -> Wasp
                        -> [FD.FileDraft]
generateExternalCodeDir strategy wasp =
    map (generateFile strategy) (Wasp.getExternalCodeFiles wasp)

generateFile :: C.ExternalCodeGeneratorStrategy -> EC.File -> FD.FileDraft
generateFile strategy file
    | extension `elem` [".js", ".jsx"] = generateJsFile strategy file
    | otherwise = let relDstPath = (C._extCodeDirInProjectRootDir strategy) Path.</> EC.filePathInExtCodeDir file
                      absSrcPath = EC.fileAbsPath file
                  in FD.createCopyFileDraft relDstPath absSrcPath
  where
    extension = FP.takeExtension $ Path.toFilePath $ EC.filePathInExtCodeDir file



