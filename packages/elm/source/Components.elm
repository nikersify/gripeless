module Components exposing
    ( exampleBox
    , fullscreenBox
    , sidebarItemButton
    , sidebarItemLabel
    , sidebarSection
    , spinner
    , userPill
    , viewErrorBox
    , viewFullscreenLoader
    , viewFullscreenThing
    , viewPrimaryButton
    , viewSubmitShortcutLabel
    , viewTextarea
    )

import Gegangen.Models
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, preventDefaultOn)
import Icons
import Json.Decode as Decode
import Util exposing (alternate, flip, metaEnterDecoder, shiftEnterDecoder)


spinner : String -> Html msg
spinner classes =
    div
        [ class classes
        , class "text-center"
        ]
        [ Icons.halfCircle "spin w-8 h-8" ]


userPill : String -> Gegangen.Models.User -> Html msg
userPill defaultAvatarURL user =
    div [ class "border rounded-lg inline-flex items-center shadow select-none" ]
        [ img
            [ src (Maybe.withDefault defaultAvatarURL user.picture)
            , alt "Profile picture"
            , class "block w-10 h-10 rounded-l-lg"
            ]
            []
        , div [ class "px-2 leading-tight" ]
            [ div [] [ text (Maybe.withDefault user.email user.name) ]
            , div [ class "text-xs text-gray-600" ] [ text user.email ]
            ]
        ]



-- `msg` is required here to force us into always giving a way for users to
-- recover from the error


viewErrorBox : String -> String -> msg -> Html msg
viewErrorBox title error msg =
    div [ class "text-center rounded-lg bg-white text-red-700 border px-4 max-w-lg mx-auto" ]
        [ Icons.xCircle "w-12 h-12 mt-4"
        , div
            [ class "font-bold text-lg mt-2" ]
            [ text title ]
        , div [ class "mb-6" ] [ text error ]
        , button
            [ onClick msg
            , class "rounded border border-red-700 px-4 py-1 mb-6"
            , class "hover:text-white hover:bg-red-700 inline-flex items-center"
            ]
            [ text "Retry"
            , Icons.refresh "w-5 h-5 ml-1"
            ]
        ]


fullscreenBox : String -> msg -> List (Html msg) -> Html msg
fullscreenBox host msg children =
    div [ class "bg-gray-200 min-w-full min-h-screen flex flex-col items-center justify-center py-2" ]
        [ div [ class "bg-white rounded-lg shadow-md border p-4 max-w-lg mx-2 w-full" ] children
        , div [ class "text-gray-700 text-xs mt-4" ]
            [ button [ onClick msg ] [ text "Problems with this page?" ] ]
        , div [ class "text-gray-600 text-xs mt-4" ]
            [ a [ href ("//" ++ host) ] [ text "Gripeless · 2020" ] ]
        ]


viewTextarea :
    { id : Maybe String
    , onInput : String -> msg
    , onSubmit : msg
    , classes : String
    , isMac : Bool
    , isDisabled : Bool
    , value : String
    , placeholder : String
    }
    -> Html msg
viewTextarea args =
    textarea
        [ id <| Maybe.withDefault "" args.id
        , onInput args.onInput
        , disabled args.isDisabled
        , preventDefaultOn "keydown"
            (Decode.map
                (flip Tuple.pair True)
                (alternate args.isMac
                    metaEnterDecoder
                    shiftEnterDecoder
                    args.onSubmit
                )
            )
        , value args.value
        , class "w-full font-medium min-h-24 p-2 rounded placeholder-gray-600 border focus:shadow-lg outline-none"
        , class args.classes
        , class
            (if String.length args.value > 0 then
                "bg-gray-100"

             else
                "focus:bg-gray-100 bg-gray-200"
            )
        , placeholder args.placeholder
        ]
        []


viewPrimaryButton : String -> { isDisabled : Bool, isLoading : Bool } -> Html msg
viewPrimaryButton classes { isDisabled, isLoading } =
    button
        [ type_ "submit"
        , disabled isDisabled
        , class
            "px-8 py-2 border font-medium rounded-md text-lg flex items-center"
        , if isDisabled then
            class "cursor-not-allowed border-gray-400 bg-gray-300 text-gray-500"

          else
            class "bg-red-600 font-medium text-white border-red-700 hover:bg-red-700 hover:shadow"
        , class classes
        ]
        [ if isLoading then
            Icons.halfCircle "w-6 h-6 mx-2 spin"

          else
            text "Submit"
        ]


viewSubmitShortcutLabel : Bool -> Html msg
viewSubmitShortcutLabel isMac =
    label
        [ class "mr-4 text-gray-500 text-sm text-right" ]
        [ p [ class "hidden md:block" ]
            [ if isMac then
                text "⌘+Enter to submit"

              else
                text "Shift+Enter to submit"
            ]
        ]


sidebarSection : List (Html msg) -> Html msg
sidebarSection children =
    div [ class "mb-8" ] children


sidebarItemLabel : String -> Html msg
sidebarItemLabel string =
    label
        [ class "px-4 tracking-wider font-semibold text-gray-600 text-xs uppercase my-2 block"
        ]
        [ text string ]


sidebarItemButton :
    { icon : String -> Html msg
    , selectedIconColorClass : String
    , label : String
    , badge : Maybe (Html msg)
    , isSelected : Bool
    , onSelect : msg
    }
    -> Html msg
sidebarItemButton args =
    button
        [ -- Prevent default to prevent focusing the buttons on click on chromium
          Html.Events.preventDefaultOn "mousedown"
            (Decode.map (\x -> ( x, True )) (Decode.succeed args.onSelect))
        , class "button text-gray-600 py-2 px-4 font-medium w-full rounded-lg flex justify-between items-center mb-2"
        , class (alternate args.isSelected "bg-gray-200" "hover:bg-gray-200")
        ]
        [ span
            [ class "text-sm flex items-center"
            , class (alternate args.isSelected "text-gray-900" "")
            ]
            [ args.icon
                (alternate
                    args.isSelected
                    args.selectedIconColorClass
                    "text-gray-500"
                    ++ " w-6 h-6 mr-2"
                )
            , text args.label
            ]
        , case args.badge of
            Nothing ->
                text ""

            Just el ->
                span [ class "px-3 text-xs text-gray-600 bg-gray-300 rounded-full text-white" ] [ el ]
        ]


exampleBox : Maybe String -> Html msg -> Html msg
exampleBox maybeLabel content =
    div [ class "border-red-400" ]
        [ div [ class "rounded-t text-xs uppercase font-semibold px-2 py-1 bg-red-400 inline-block text-gray-800" ] [ text "Example" ]
        , div [ class "rounded-b-lg rounded-tr-lg shadow-lg border bg-gray-100 mb-1 border-red-400" ]
            [ content ]
        , case maybeLabel of
            Nothing ->
                text ""

            Just label ->
                div [ class "py-1 px-2 text-center text-sm text-gray-800" ] [ text label ]
        ]


viewFullscreenThing : List (Html msg) -> Html msg
viewFullscreenThing children =
    div [ class "flex flex-col items-center w-screen h-screen justify-center text-gray-600" ]
        children


viewFullscreenLoader : String -> Html msg
viewFullscreenLoader string =
    viewFullscreenThing
        [ spinner ""
        , div [ class "mt-4 text-sm" ]
            [ text string ]
        ]
