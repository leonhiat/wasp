module WaspignoreFile
    ( WaspignoreFile
    , parseWaspignoreFile
    , readWaspignoreFile
    , ignores
    ) where

import Control.Exception (catch)
import System.IO.Error (isDoesNotExistError)
import StrongPath (Path, Abs, File, toFilePath)
import System.FilePath.Glob (Pattern, compile, match)

newtype WaspignoreFile = WaspignoreFile [Pattern]

-- | These patterns are ignored by every 'WaspignoreFile'
defaultIgnorePatterns :: [Pattern]
defaultIgnorePatterns = map compile [".waspignore"]

-- | Parses a string to a 'WaspignoreFile'.
--
--   An ignore file contains lines that are one of:
--   * blank
--   * comments (starting with '#')
--   * a pattern
--
--   An ignore file always ignores `.waspignore`.
--
--   Patterns are glob 'Pattern's, for full details "System.FilePath.Glob". A
--   brief description is:
--
--   [@?@] Matches any single character except slashes.
--   [@*@] Matches a string of at least 1 character, excluding slashes.
--   [@[xyz\]@] Matches a single character in the set `xyz`.
--   [@[^xyz\]@] Matches a single character not in the set `xyz`.
--   [@**/@] Matches a string of at least 1 character, including slashes.
parseWaspignoreFile :: String -> WaspignoreFile
parseWaspignoreFile = WaspignoreFile .
                      (defaultIgnorePatterns++) .
                      map compile .
                      filter isPatternLine .
                      lines
    where
        isPatternLine :: String -> Bool
        isPatternLine [] = False
        isPatternLine ('#':_) = False
        isPatternLine _ = True

-- | Reads and parses the wasp ignore file. See 'parseWaspignoreFile' for details of
--   the file format, but it is very similar to `.gitignore`'s format.
--
--   If the ignore file does not exist, it is interpreted as a blank file.
readWaspignoreFile :: Path Abs File -> IO WaspignoreFile
readWaspignoreFile fp = do
    text <- readFile (toFilePath fp)
            `catch` (\e -> if isDoesNotExistError e then return ""
                           else ioError e)
    return $ parseWaspignoreFile text

-- | Tests whether a file should be ignored according to a 'WaspignoreFile'.
--
--   Example:
--
--   @
--   let ignoreFile = parseWaspignoreFile "**/*.tmp"
--   ignoreFile `ignores` "out.tmp" -- True
--   ignoreFile `ignores` "src/a.tmp" -- True
--   ignoreFile `ignores` "src/a.js" -- False
--   @
ignores :: WaspignoreFile -> FilePath -> Bool
ignores (WaspignoreFile pats) fp = any (`match` fp) pats
