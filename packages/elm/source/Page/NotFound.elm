module Page.NotFound exposing (Msg, update, view)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Icons
import Ports.Gripeless exposing (openGripeless)
import Session exposing (Session)


type Msg
    = OpenGripeless
    | GoBack


update : Msg -> Session -> ( Session, Cmd Msg )
update msg session =
    case msg of
        OpenGripeless ->
            ( session
            , openGripeless
                ( session.gripelessProjectName
                , Nothing
                )
            )

        GoBack ->
            ( session, Nav.back session.key 1 )


view : Browser.Document Msg
view =
    { title = "Not found"
    , body =
        [ div [ class "w-screen h-screen flex items-center justify-center bg-gray-100" ]
            [ div [ class "text-center" ]
                [ div []
                    [ Icons.xCircle "w-16 h-16 text-gray-400" ]
                , h2
                    [ class "font-bold text-gray-500" ]
                    [ text "Page not found" ]
                , button
                    [ onClick GoBack
                    , class "mt-8 shadow rounded bg-white border py-2 px-4 inline-flex items-center"
                    , class "hover:bg-red-600 hover:text-white hover:border-transparent"
                    ]
                    [ Icons.arrowLeft "w-6 h-6 mr-2"
                    , text "Go back"
                    ]
                , p [ class "text-gray-600 text-sm mt-8" ]
                    [ text "Is this an error? "
                    , button
                        [ onClick OpenGripeless
                        , class "text-red-800"
                        ]
                        [ text "Create a gripe" ]
                    ]
                ]
            ]
        ]
    }
