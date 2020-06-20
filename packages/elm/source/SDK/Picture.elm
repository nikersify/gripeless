module SDK.Picture exposing
    ( Picture(..)
    , init
    , isValid
    , preparing
    , toOptionalArgument
    , view
    )

import File exposing (File)
import Graphql.OptionalArgument exposing (OptionalArgument(..))
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Icons


type Picture
    = NoPicture
    | Preparing
    | UploadingPicture ( File, Maybe String, Float )
    | UploadedPicture ( File, Maybe String, String )
    | FailedPicture String


init : Picture
init =
    NoPicture


preparing : Picture
preparing =
    Preparing


toOptionalArgument : Picture -> OptionalArgument String
toOptionalArgument picture =
    case picture of
        NoPicture ->
            Null

        Preparing ->
            Null

        UploadingPicture _ ->
            Null

        FailedPicture _ ->
            Null

        UploadedPicture ( _, _, id ) ->
            Present id


isValid : Picture -> Bool
isValid picture =
    case picture of
        NoPicture ->
            True

        Preparing ->
            False

        UploadedPicture _ ->
            True

        UploadingPicture _ ->
            False

        FailedPicture _ ->
            False


viewPreview : msg -> Maybe String -> Maybe Float -> Html msg
viewPreview clearMsg maybePreview maybeProgress =
    let
        isLoading =
            case maybeProgress of
                Just _ ->
                    True

                Nothing ->
                    False
    in
    div [ class "relative" ]
        [ img
            [ src
                (case maybePreview of
                    Just preview ->
                        preview

                    Nothing ->
                        ""
                )
            , class "w-10 h-10 rounded object-cover select-none"
            ]
            []
        , if isLoading then
            div [ class "absolute opacity-75 bg-white inset-0 rounded" ] []

          else
            text ""
        , button
            [ type_ "button"
            , onClick clearMsg
            , class "absolute border rounded-full bg-white shadow h-6 w-6 top-0 right-0 flex items-center justify-center"
            , class "transform -translate-y-1/2 translate-x-1/2"
            ]
            [ Icons.x "w-4 h-4" ]
        , case maybeProgress of
            Just progress ->
                div [ class "absolute left-0 right-0 h-1 bg-gray-800 bottom-0 mx-1 mb-1 rounded-full" ]
                    [ div [ style "width" (String.fromFloat (progress * 100) ++ "%"), class "bg-green-500 h-full rounded-full" ] []
                    ]

            Nothing ->
                text ""
        ]


view : msg -> Picture -> Html msg
view clearMsg picture =
    case picture of
        NoPicture ->
            text ""

        Preparing ->
            viewPreview clearMsg Nothing (Just 0)

        UploadingPicture ( _, maybePreview, progress ) ->
            viewPreview clearMsg maybePreview (Just progress)

        UploadedPicture ( _, maybePreview, _ ) ->
            viewPreview clearMsg maybePreview Nothing

        FailedPicture reason ->
            div
                [ class "text-xs max-w-sm flex items-center" ]
                [ div []
                    [ div [ class "text-xs text-red-600" ] [ text "Failed to upload picture" ]
                    , div [] [ text reason ]
                    ]
                , button
                    [ class "border px-2 py-1 ml-1 bg-white rounded text-sm"
                    , onClick clearMsg
                    ]
                    [ text "Retry" ]
                ]
