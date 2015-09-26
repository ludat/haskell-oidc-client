{-# LANGUAGE OverloadedStrings #-}
{-|
Module: Web.OIDC.Discovery
Maintainer: krdlab@gmail.com
Stability: experimental
-}
module Web.OIDC.Discovery
    ( discover
    , IssuerLocation
    , Provider
    , module I
    ) where

import Control.Applicative ((<$>))
import Control.Monad.Catch (throwM, catch)
import Data.Aeson (decode)
import Data.Maybe (fromMaybe)
import Data.Monoid (mempty)
import qualified Jose.Jwk as Jwk
import Network.HTTP.Client (Manager, parseUrl, httpLbs, responseBody)
import Web.OIDC.Types
import Web.OIDC.Discovery.Issuers as I

-- | This function obtains OpenID Provider configuration and JWK set.
discover
    :: IssuerLocation   -- ^ OpenID Provider's Issuer location
    -> Manager
    -> IO Provider
discover location manager = do
    conf <- getConfiguration `catch` rethrow
    case conf of
        Just c  -> Provider c . jwks <$> getJwkSetJson (jwksUri c) `catch` rethrow
        Nothing -> throwM $ DiscoveryException "failed to decode configuration"
  where
    getConfiguration = do
        req <- parseUrl (location ++ "/.well-known/openid-configuration")
        res <- httpLbs req manager
        return $ decode $ responseBody res
    getJwkSetJson url = do
        req <- parseUrl url
        res <- httpLbs req manager
        return $ responseBody res
    jwks j = fromMaybe single (Jwk.keys <$> decode j)
      where
        single = case decode j of
                     Just k  -> return k
                     Nothing -> mempty
