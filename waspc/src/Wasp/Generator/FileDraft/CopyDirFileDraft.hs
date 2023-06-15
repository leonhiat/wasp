module Wasp.Generator.FileDraft.CopyDirFileDraft
  ( CopyDirFileDraft (..),
    CopyDirFileDraftDstDirStrategy (..),
  )
where

import Control.Monad (when)
import qualified Data.ByteString as BS
import StrongPath
  ( Abs,
    Dir',
    Path',
    Rel,
    (</>),
  )
import qualified StrongPath as SP
import Wasp.Generator.Common (ProjectRootDir)
import Wasp.Generator.FileDraft.Writeable
import Wasp.Generator.FileDraft.WriteableMonad
  ( WriteableMonad
      ( copyDirectoryRecursive,
        createDirectoryIfMissing,
        removeDirectoryRecursive
      ),
    doesDirectoryExist,
  )
import Wasp.Util (checksumFromByteString, checksumFromChecksums)
import Wasp.Util.IO (listDirectoryDeep)

-- | File draft based on another dir that is to be recursively copied.
--
-- TODO: revisit the quick and dirty Linux interpretation of "everything is a file"
-- and treating a directory (`CopyDirFileDraft`) as a `FileDraft`. As is, this may be
-- a source of potential confusion and possibly tech debt to resolve later.
data CopyDirFileDraft = CopyDirFileDraft
  { -- | Path where the dir will be copied to.
    _dstPath :: !(Path' (Rel ProjectRootDir) Dir'),
    -- | Absolute path of source dir to copy.
    _srcPath :: !(Path' Abs Dir'),
    -- | What to do with the dst dir if it already exists.
    _dstDirStrategy :: !CopyDirFileDraftDstDirStrategy
  }
  deriving (Show, Eq)

data CopyDirFileDraftDstDirStrategy
  = -- | Remove the dst dir if it already exists.
    RemoveExistingDstDir
  | -- | Write over the dst dir if it already exists, without removing the existing files.
    WriteOverExistingDstDir
  deriving (Show, Eq)

instance Writeable CopyDirFileDraft where
  write projectRootAbsPath draft = do
    srcDirExists <- doesDirectoryExist $ SP.fromAbsDir srcPathAbsDir
    dstDirExists <- doesDirectoryExist $ SP.fromAbsDir dstPathAbsDir

    case _dstDirStrategy draft of
      RemoveExistingDstDir ->
        when dstDirExists $ removeDirectoryRecursive dstPathAbsDir
      WriteOverExistingDstDir -> pure ()

    when srcDirExists $ do
      createDirectoryIfMissing True (SP.fromAbsDir dstPathAbsDir)
      copyDirectoryRecursive srcPathAbsDir dstPathAbsDir
    where
      srcPathAbsDir = _srcPath draft
      dstPathAbsDir = projectRootAbsPath </> _dstPath draft

  getDstPath draft = Right $ _dstPath draft

  -- NOTE: This is relatively expensive operation here, since we are reading all the files in the directory.
  getChecksum draft = do
    descendentFiles <- listDirectoryDeep $ _srcPath draft
    descendentFilesChecksums <-
      mapM ((checksumFromByteString <$>) . BS.readFile . SP.fromAbsFile . (_srcPath draft SP.</>)) descendentFiles
    return $ checksumFromChecksums descendentFilesChecksums
