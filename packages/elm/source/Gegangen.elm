module Gegangen exposing (formatError)

import Graphql.Http
import Json.Decode


formatError : Graphql.Http.Error err -> String
formatError error =
    case error of
        Graphql.Http.GraphqlError _ graphqlErrors ->
            String.join " & " (List.map .message graphqlErrors)

        Graphql.Http.HttpError httpError ->
            case httpError of
                Graphql.Http.BadUrl msg ->
                    "Invalid url: " ++ msg

                Graphql.Http.Timeout ->
                    "Request timed out"

                Graphql.Http.NetworkError ->
                    "Network error"

                Graphql.Http.BadStatus metadata _ ->
                    "Got invalid response status: "
                        ++ String.fromInt metadata.statusCode
                        ++ " - "
                        ++ metadata.statusText

                Graphql.Http.BadPayload payloadError ->
                    Json.Decode.errorToString payloadError
