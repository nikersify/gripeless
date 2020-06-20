module Entry.BlogMailing exposing (main)

import Browser
import Gegangen exposing (formatError)
import Gegangen.Requests as Requests
import Graphql.Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Icons
import RemoteData
import Token


type alias Flags =
    String


type Form
    = Ready String
    | Loading String
    | Failure (Graphql.Http.Error String)
    | Success


type alias Model =
    { apiURL : String
    , form : Form
    }


type Msg
    = UpdateValue String
    | Submitted
    | Reset
    | GotResponse Requests.StringResponse


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }


init : Flags -> ( Model, Cmd Msg )
init apiURL =
    ( { apiURL = apiURL, form = Ready "" }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateValue value ->
            case model.form of
                Ready _ ->
                    ( updateForm (Ready value) model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        Submitted ->
            case model.form of
                Ready value ->
                    ( updateForm (Loading value) model
                    , Requests.subscribeToBlogMailingList
                        model.apiURL
                        value
                        GotResponse
                        Token.empty
                    )

                _ ->
                    ( model, Cmd.none )

        Reset ->
            ( updateForm (Ready "") model, Cmd.none )

        GotResponse response ->
            case response of
                RemoteData.Loading ->
                    ( model, Cmd.none )

                RemoteData.NotAsked ->
                    ( model, Cmd.none )

                RemoteData.Success _ ->
                    ( updateForm Success model, Cmd.none )

                RemoteData.Failure error ->
                    ( updateForm (Failure error) model, Cmd.none )


updateForm : Form -> Model -> Model
updateForm form model =
    { model | form = form }


disclaimerText : String
disclaimerText =
    "We won't ever spam you with any promotional or marketing content. Pinky promise."


viewForm : String -> Bool -> Html Msg
viewForm v isLoading =
    div []
        [ Html.form
            [ onSubmit Submitted
            , class "inline-flex items-stretch shadow-md mb-2"
            ]
            [ input
                [ value v
                , onInput UpdateValue
                , type_ "email"
                , required True
                , placeholder "you@somewhere.com"
                , class "w-md w-64 px-4 py-1 rounded-l z-10 disabled:bg-gray-300"
                , disabled isLoading
                ]
                []
            , button
                [ type_ "submit"
                , class "rounded-r px-4 border-l"
                , if isLoading then
                    class "bg-gray-300 text-gray-600 cursor-default"

                  else
                    class "bg-white hover:bg-gray-100"
                ]
                [ if isLoading then
                    Icons.halfCircle "spin w-4 h-4"

                  else
                    text "Submit"
                ]
            ]
        , div [ class "text-gray-600 text-sm" ]
            [ text disclaimerText ]
        ]


view : Model -> Html Msg
view model =
    case model.form of
        Ready value ->
            viewForm value False

        Loading value ->
            viewForm value True

        Failure error ->
            div []
                [ div [ class "text-red-700 mb-1" ]
                    [ text "Failed to submit form" ]
                , div [ class "text-red-700 mb-1" ]
                    [ text <| formatError error ]
                , button
                    [ type_ "button"
                    , onClick Reset
                    , class "border bg-white rounded px-2 py-1"
                    ]
                    [ text "Try again" ]
                ]

        Success ->
            div [ class "text-green-700 inline-flex items-center" ]
                [ Icons.checkCircle "w-4 h-4 mr-1"
                , text "You'll receive notifications about new posts!"
                ]
