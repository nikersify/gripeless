module Util exposing
    ( alternate
    , flip
    , metaEnterDecoder
    , mouseEventToPoint
    , onSpecificKeyUp
    , shiftEnterDecoder
    , specificKeyDecoder
    )

import Html
import Html.Events exposing (on)
import Json.Decode as Decode
import Point exposing (Point)


alternate : Bool -> a -> a -> a
alternate bool a b =
    if bool then
        a

    else
        b


flip : (a -> b -> c) -> b -> a -> c
flip f a b =
    f b a


specificKeyDecoder : String -> msg -> Decode.Decoder msg
specificKeyDecoder target message =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                if key == target then
                    Decode.succeed message

                else
                    Decode.fail ""
            )


onSpecificKeyUp : String -> msg -> Html.Attribute msg
onSpecificKeyUp target message =
    on "keyup" (specificKeyDecoder target message)


modifierEnterDecoder : String -> msg -> Decode.Decoder msg
modifierEnterDecoder modifier msg =
    Decode.map2 Tuple.pair
        (Decode.field "key" Decode.string)
        (Decode.field modifier Decode.bool)
        |> Decode.andThen
            (\( key, modifier_ ) ->
                if key == "Enter" && modifier_ then
                    Decode.succeed msg

                else
                    Decode.fail "Not shift+enter"
            )


shiftEnterDecoder : msg -> Decode.Decoder msg
shiftEnterDecoder =
    modifierEnterDecoder "shiftKey"


metaEnterDecoder : msg -> Decode.Decoder msg
metaEnterDecoder =
    modifierEnterDecoder "metaKey"


mouseEventToPoint : Decode.Decoder Point
mouseEventToPoint =
    Decode.map2 Tuple.pair
        (Decode.field "x" Decode.float)
        (Decode.field "y" Decode.float)
