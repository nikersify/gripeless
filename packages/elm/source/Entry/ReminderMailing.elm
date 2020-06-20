module Entry.ReminderMailing exposing (main)

import Browser
import Gegangen exposing (formatError)
import Gegangen.Requests as Requests
import Graphql.Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput, onSubmit)
import Icons
import RemoteData
import Token


type alias Flags =
    String


type Form
    = Ready String
    | Loading
    | Failure (Graphql.Http.Error String)
    | Success


type alias Model =
    { apiURL : String
    , form : Form
    }


type Msg
    = UpdateValue String
    | Submitted
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
                    ( updateForm Loading model
                    , Requests.subscribeToReminderMailingList
                        model.apiURL
                        value
                        GotResponse
                        Token.empty
                    )

                _ ->
                    ( model, Cmd.none )

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


view : Model -> Html Msg
view model =
    case model.form of
        Failure error ->
            div [ class "mt-3 text-red-700" ]
                [ text <| formatError error ]

        Loading ->
            div [ class "mt-3 mx-12" ]
                [ Icons.halfCircle "spin w-6 h-6"
                ]

        Ready v ->
            Html.form
                [ onSubmit Submitted ]
                [ div [ class "relative" ]
                    [ input
                        [ type_ "email"
                        , class "shadow-lg text-xl pl-4 pr-16 py-2 w-64 border rounded"
                        , placeholder "you@work.com"
                        , value v
                        , onInput UpdateValue
                        , required True
                        ]
                        []
                    , button
                        [ class "absolute top-0 bottom-0 right-0 px-1 px-4 text-gray-600 hover:text-gray-800"
                        , if String.length v > 0 then
                            class "block"

                          else
                            class "hidden"
                        ]
                        [ Icons.arrowRight "w-6 h-6" ]
                    ]
                , div [ class "text-sm text-gray-600 mt-2" ] [ text "No time right now? We'll remind you soon." ]
                ]

        Success ->
            div [ class "text-green-700 mt-3" ]
                [ text "✓ Thank you! We'll get in touch soon." ]
