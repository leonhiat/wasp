{-# LANGUAGE TypeApplications #-}

module Wasp.AppSpec.Valid
  ( validateAppSpec,
    ValidationError (..),
    getApp,
    isAuthEnabled,
  )
where

import Data.List (find)
import Data.Maybe (isJust)
import Wasp.AppSpec (AppSpec)
import qualified Wasp.AppSpec as AS
import Wasp.AppSpec.App (App)
import qualified Wasp.AppSpec.App as AS.App
import qualified Wasp.AppSpec.App as App
import qualified Wasp.AppSpec.App.Auth as Auth
import qualified Wasp.AppSpec.App.Db as AS.Db
import Wasp.AppSpec.Core.Decl (takeDecls)
import qualified Wasp.AppSpec.Entity as Entity
import qualified Wasp.AppSpec.Entity.Field as Entity.Field
import qualified Wasp.AppSpec.Page as Page
import Wasp.AppSpec.Util (isPgBossJobExecutorUsed)

data ValidationError = GenericValidationError String
  deriving (Show, Eq)

validateAppSpec :: AppSpec -> [ValidationError]
validateAppSpec spec =
  case validateExactlyOneAppExists spec of
    Just err -> [err]
    Nothing ->
      -- NOTE: We check these only if App exists because they all rely on it existing.
      concat
        [ validateAppAuthIsSetIfAnyPageRequiresAuth spec,
          validateAuthUserEntityHasCorrectFieldsIfEmailAndPasswordAuthIsUsed spec,
          validateDbIsPostgresIfPgBossUsed spec
        ]

validateExactlyOneAppExists :: AppSpec -> Maybe ValidationError
validateExactlyOneAppExists spec =
  case AS.takeDecls @App (AS.decls spec) of
    [] -> Just $ GenericValidationError "You are missing an 'app' declaration in your Wasp app."
    [_] -> Nothing
    apps ->
      Just $
        GenericValidationError $
          "You have more than one 'app' declaration in your Wasp app. You have " ++ show (length apps) ++ "."

validateAppAuthIsSetIfAnyPageRequiresAuth :: AppSpec -> [ValidationError]
validateAppAuthIsSetIfAnyPageRequiresAuth spec =
  if anyPageRequiresAuth && not (isAuthEnabled spec)
    then
      [ GenericValidationError
          "Expected app.auth to be defined since there are Pages with authRequired set to true."
      ]
    else []
  where
    anyPageRequiresAuth = any ((== Just True) . Page.authRequired) (snd <$> AS.getPages spec)

validateDbIsPostgresIfPgBossUsed :: AppSpec -> [ValidationError]
validateDbIsPostgresIfPgBossUsed spec =
  if isPgBossJobExecutorUsed spec && not (isPostgresUsed spec)
    then
      [ GenericValidationError
          "Expected app.db.system to be PostgreSQL since there are jobs with executor set to PgBoss."
      ]
    else []

validateAuthUserEntityHasCorrectFieldsIfEmailAndPasswordAuthIsUsed :: AppSpec -> [ValidationError]
validateAuthUserEntityHasCorrectFieldsIfEmailAndPasswordAuthIsUsed spec = case App.auth (snd $ getApp spec) of
  Nothing -> []
  Just auth ->
    if Auth.EmailAndPassword `notElem` Auth.methods auth
      then []
      else
        let userEntity = snd $ AS.resolveRef spec (Auth.userEntity auth)
            userEntityFields = Entity.getFields userEntity
            maybeEmailField = find ((== "email") . Entity.Field.fieldName) userEntityFields
            maybePasswordField = find ((== "password") . Entity.Field.fieldName) userEntityFields
         in concat
              [ case maybeEmailField of
                  Just emailField
                    | Entity.Field.fieldType emailField == Entity.Field.FieldTypeScalar Entity.Field.String -> []
                  _ ->
                    [ GenericValidationError
                        "Expected an Entity referenced by app.auth.userEntity to have field 'email' of type 'string'."
                    ],
                case maybePasswordField of
                  Just passwordField
                    | Entity.Field.fieldType passwordField == Entity.Field.FieldTypeScalar Entity.Field.String -> []
                  _ ->
                    [ GenericValidationError
                        "Expected an Entity referenced by app.auth.userEntity to have field 'password' of type 'string'."
                    ]
              ]

-- | This function assumes that @AppSpec@ it operates on was validated beforehand (with @validateAppSpec@ function).
-- TODO: It would be great if we could ensure this at type level, but we decided that was too much work for now.
--   Check https://github.com/wasp-lang/wasp/pull/455 for considerations on this and analysis of different approaches.
getApp :: AppSpec -> (String, App)
getApp spec = case takeDecls @App (AS.decls spec) of
  [app] -> app
  apps ->
    error $
      ("Expected exactly 1 'app' declaration in your wasp code, but you have " ++ show (length apps) ++ ".")
        ++ " This should never happen as it should have been caught during validation of AppSpec."

-- | This function assumes that @AppSpec@ it operates on was validated beforehand (with @validateAppSpec@ function).
isAuthEnabled :: AppSpec -> Bool
isAuthEnabled spec = isJust (App.auth $ snd $ getApp spec)

-- | This function assumes that @AppSpec@ it operates on was validated beforehand (with @validateAppSpec@ function).
isPostgresUsed :: AppSpec -> Bool
isPostgresUsed spec = Just AS.Db.PostgreSQL == (AS.Db.system =<< AS.App.db (snd $ getApp spec))
