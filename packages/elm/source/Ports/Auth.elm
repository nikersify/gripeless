port module Ports.Auth exposing (DecodedPrepareQueryData, RawPrepareQueryData, UserUIDData, decodeTokenData, prepareQuery, queryPrepared, signIn, signInError, signOut, userUIDChanged)

import QueryType exposing (QueryType)
import Token exposing (Token)


port signIn : String -> Cmd msg


port signOut : () -> Cmd msg


port prepareQuery : String -> Cmd msg


port queryPrepared : (RawPrepareQueryData -> msg) -> Sub msg


port userUIDChanged : (Maybe UserUIDData -> msg) -> Sub msg


port signInError : (String -> msg) -> Sub msg


type alias UserUIDData =
    -- (uid, isAnonymous)
    ( String, Bool )


type alias RawPrepareQueryData =
    { token :
        Token.TokenData
    , queryName : String
    }


type alias DecodedPrepareQueryData =
    { token : Token
    , queryType : Maybe QueryType
    }


decodeTokenData : RawPrepareQueryData -> DecodedPrepareQueryData
decodeTokenData { token, queryName } =
    { token = Token.wrap token
    , queryType = QueryType.decode queryName
    }
