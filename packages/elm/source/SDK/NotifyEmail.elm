module SDK.NotifyEmail exposing
    ( NotifyEmail
    , getIfEditing
    , initEditing
    , initEmpty
    , initPrefilled
    , inputID
    , isValid
    , toOptionalArgument
    , view
    )

import Graphql.OptionalArgument exposing (OptionalArgument(..))
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Icons
import Util exposing (onSpecificKeyUp)


type NotifyEmail
    = NoEmail
    | PrefilledEmail String
    | EditingEmail String


initEmpty : NotifyEmail
initEmpty =
    NoEmail


initPrefilled : String -> NotifyEmail
initPrefilled =
    PrefilledEmail


initEditing : String -> NotifyEmail
initEditing =
    EditingEmail


getIfEditing : NotifyEmail -> Maybe String
getIfEditing notifyEmail =
    case notifyEmail of
        NoEmail ->
            Nothing

        PrefilledEmail _ ->
            Nothing

        EditingEmail email ->
            Just email


toOptionalArgument : NotifyEmail -> OptionalArgument String
toOptionalArgument notifyEmail =
    case notifyEmail of
        NoEmail ->
            Absent

        EditingEmail email ->
            Present email

        PrefilledEmail email ->
            Present email


isValid : NotifyEmail -> Bool
isValid notifyEmail =
    case notifyEmail of
        NoEmail ->
            True

        PrefilledEmail _ ->
            True

        EditingEmail email ->
            case String.split "@" email of
                [ a, b ] ->
                    String.length a > 0 && String.length b > 0

                _ ->
                    False


inputID : String
inputID =
    "notify-email-input"


view : (NotifyEmail -> msg) -> NotifyEmail -> Html msg
view changedMsg notifyEmail =
    case notifyEmail of
        PrefilledEmail email ->
            div [ class "text-xs text-gray-700 flex items-center select-none" ]
                [ Icons.notification "w-4 h-4 mr-1"
                , span [] [ text "You will be notified by email when this issue gets fixed." ]
                ]

        EditingEmail email ->
            div []
                [ div [ class "flex items-stretch mb-2" ]
                    [ input
                        [ value email
                        , type_ "email"
                        , onInput (EditingEmail >> changedMsg)
                        , onSpecificKeyUp "Escape" (changedMsg NoEmail)
                        , id inputID
                        , class "px-2 py-1 border text-sm placeholder-gray-600 rounded-l font-medium focus:bg-gray-100 z-10 outline-none focus:shadow-md"
                        , if String.length email > 0 then
                            class "bg-gray-100"

                          else
                            class "bg-gray-200"
                        , placeholder "john@doe.com"
                        ]
                        []
                    , button
                        [ onClick (changedMsg NoEmail)
                        , type_ "button"
                        , class "bg-white rounded-r border px-2 hover:bg-gray-100"
                        ]
                        [ Icons.x "w-4 h-4" ]
                    ]
                , div [ class "text-xs text-gray-700 flex items-center select-none" ]
                    [ Icons.notification "w-4 h-4 mr-1"
                    , span [] [ text "You will be notified on this address when this issue gets fixed." ]
                    ]
                ]

        NoEmail ->
            div [ class "mb-3" ]
                [ button
                    [ onClick (changedMsg (EditingEmail ""))
                    , class "text-xs text-red-700 hover:text-red-900"
                    , type_ "button"
                    ]
                    [ text "Notify me when this issue gets fixed..."
                    ]
                ]
