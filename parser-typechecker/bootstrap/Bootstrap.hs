{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Data.ByteString    as BS
import           Data.Foldable      (toList, traverse_)
import           Data.Text          (unpack)
import qualified Data.Text.IO
import           System.Environment (getArgs)
import           System.Exit        (exitFailure)
import qualified Unison.FileParsers as FileParsers
import qualified Unison.Parser      as Parser
import qualified Unison.Parsers     as Parsers
import           Unison.PrintError  (renderNoteAsANSI, renderType')
import           Unison.Result      (pattern Result)
import qualified Unison.Result      as Result
import           Unison.Symbol      (Symbol)
import           Unison.Util.Monoid
import qualified Unison.Builtin as B
import qualified Unison.UnisonFile as UF

main :: IO ()
main = do
  args <- getArgs
  case args of
    [sourceFile]             -> go sourceFile Nothing
    [sourceFile, outputFile] -> go sourceFile (Just outputFile)
    _                        -> do
      putStrLn "usage:"
      putStrLn "  bootstrap <in-file.u> (typecheck only)"
      putStrLn "  bootstrap <in-file.u> <out-file.ub> (typecheck and serialize)"
 where
  go :: String -> Maybe String -> IO ()
  go sourceFile outputFile = do
    source             <- unpack <$> Data.Text.IO.readFile sourceFile
    (env0, unisonFile) <- Parsers.unsafeReadAndParseFile B.names sourceFile
    let (Result notes' r) =
          FileParsers.synthesizeAndSerializeUnisonFile
                                                B.typeLookup B.names unisonFile
        f (unisonFile', bs) = do
          putStrLn $ "typechecked as " ++ renderType' env0 (UF.typ unisonFile')
          traverse_ (flip BS.writeFile bs) outputFile
        showNote :: [Result.Note Symbol Parser.Ann] -> String
        showNote notes =
          intercalateMap "\n\n" (show . renderNoteAsANSI env0 source) notes
    putStrLn . showNote . toList $ notes'
    maybe exitFailure f r
