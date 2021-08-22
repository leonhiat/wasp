{-# LANGUAGE LambdaCase #-}

module Analyzer.Evaluator
  ( EvaluationError (..),
    evaluate,
    Decl,
    takeDecls,
    module Analyzer.Evaluator.Types,
  )
where

import Analyzer.Evaluator.Decl (Decl, takeDecls)
import Analyzer.Evaluator.EvaluationError
import Analyzer.Evaluator.Types
import Analyzer.Type
import qualified Analyzer.TypeChecker.AST as AST
import qualified Analyzer.TypeDefinitions as TD
import Control.Monad.Except
import Control.Monad.Reader
import Control.Monad.State
import qualified Data.HashMap.Strict as H

type Eval a = StateT (H.HashMap String Decl) (ReaderT TD.TypeDefinitions (Except EvaluationError)) a

-- | Evaluate type-checked AST to produce a list of declarations.
evaluate :: TD.TypeDefinitions -> AST.TypedAST -> Either EvaluationError [Decl]
evaluate typeDefs (AST.TypedAST stmts) = runExcept $ flip runReaderT typeDefs $ evalStateT (evalStmts stmts) H.empty

-- TODO:
-- Currently, trying to reference declarations declared after the current one
-- fails. There are some solutions mentioned in docs/wasplang that should be
-- investigated.
evalStmts :: [AST.TypedStmt] -> Eval [Decl]
evalStmts = foldr (\stmt -> (<*>) ((:) <$> evalStmt stmt)) (pure [])

evalStmt :: AST.TypedStmt -> Eval Decl
evalStmt (AST.Decl name param (DeclType declTypeName)) =
  asks (TD.getDeclType declTypeName) >>= \case
    Nothing -> error "impossible: Decl statement has non-existant type after type checking"
    Just declType -> do
      typeDefs <- ask
      bindings <- get
      case TD.dtDeclFromAST declType typeDefs bindings name param of
        Left err -> throwError err
        Right decl -> do
          modify $ H.insert name decl
          pure decl
evalStmt _ = error "impossible: Decl statement has non-Decl type after type checking"
