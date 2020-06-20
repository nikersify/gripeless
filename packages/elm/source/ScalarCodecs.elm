module ScalarCodecs exposing (GripeID(..), KeyValueString, PosixTime, codecs)

import Api.Scalar
import Json.Decode as Decode
import Json.Encode as Encode
import Time


type GripeID
    = GripeID String


type alias PosixTime =
    Time.Posix


type alias KeyValueString =
    ( String, String )


codecs : Api.Scalar.Codecs GripeID KeyValueString PosixTime
codecs =
    Api.Scalar.defineCodecs
        { codecGripeID =
            { encoder = \(GripeID raw) -> raw |> Encode.string
            , decoder = Decode.map GripeID Decode.string
            }
        , codecPosixTime =
            { encoder = Time.posixToMillis >> Encode.int
            , decoder = Decode.int |> Decode.map Time.millisToPosix
            }
        , codecKeyValueString =
            { encoder =
                \( k, v ) ->
                    Encode.list Encode.string [ k, v ]
            , decoder =
                Decode.list Decode.string
                    |> Decode.andThen
                        (\list ->
                            case list of
                                [ x, y ] ->
                                    Decode.succeed ( x, y )

                                _ ->
                                    Decode.fail "Invalid amount of items passed into KeyValue"
                        )
            }
        }
