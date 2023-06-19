{-# LANGUAGE DeriveDataTypeable #-}

module Wasp.AppSpec.App.WebSocket
  ( WebSocket (..),
  )
where

import Data.Data (Data)
import Wasp.AppSpec.ExtImport (ExtImport)

data WebSocket = WebSocket
  { fn :: ExtImport,
    autoConnect :: Maybe Bool
  }
  deriving (Show, Eq, Data)
