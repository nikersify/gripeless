port module Dev.Stories exposing (main)

import Api.Enum.GripeStatus as GripeStatus exposing (GripeStatus)
import Browser
import File exposing (File)
import Html exposing (..)
import Html.Attributes exposing (..)
import Icons
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as E
import Task


port upsko : (E.Value -> msg) -> Sub msg


type alias Model =
    {}


type Msg
    = Upped E.Value
    | GotContents String



-- | GotDecode (Result )


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( {}, Cmd.none )


decoder : Decoder File
decoder =
    File.decoder


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotContents contents ->
            let
                _ =
                    Debug.log "contents" contents
            in
            ( model, Cmd.none )

        Upped upped ->
            let
                result =
                    Decode.decodeValue decoder upped
            in
            case result of
                Result.Err _ ->
                    let
                        _ =
                            Debug.log "error" "decode error error"
                    in
                    ( model, Cmd.none )

                Result.Ok file ->
                    let
                        _ =
                            Debug.log "file" file
                    in
                    ( model, Task.perform GotContents (File.toString file) )


subscriptions model =
    upsko Upped


gripeStatusIcon : GripeStatus -> (String -> Html Msg)
gripeStatusIcon status =
    case status of
        GripeStatus.New ->
            Icons.inbox

        GripeStatus.Actionable ->
            Icons.exclamation

        GripeStatus.Done ->
            Icons.checkCircle

        GripeStatus.Discarded ->
            Icons.trash


formatGripeStatus : GripeStatus -> String
formatGripeStatus status =
    case status of
        GripeStatus.New ->
            "New"

        GripeStatus.Actionable ->
            "Actionable"

        GripeStatus.Done ->
            "Done"

        GripeStatus.Discarded ->
            "Discarded"


viewStatusComponent : GripeStatus -> GripeStatus -> Html Msg
viewStatusComponent selectedStatus status =
    let
        isSelected =
            selectedStatus == status
    in
    div
        [ class "p-2 items-center inline-flex border-r last:border-r-0 text-center"
        , if isSelected then
            class "bg-red-200"

          else
            class ""
        ]
        [ gripeStatusIcon status "w-6 h-6"
        , if isSelected then
            span [ class "ml-2" ]
                [ text (formatGripeStatus status) ]

          else
            text ""
        ]


viewStatusesProgress : GripeStatus -> Html Msg
viewStatusesProgress status =
    div [ class "rounded-md border shadow inline-block" ]
        [ viewStatusComponent status GripeStatus.New
        , viewStatusComponent status GripeStatus.Actionable
        , viewStatusComponent status GripeStatus.Done
        , viewStatusComponent status GripeStatus.Discarded
        ]


viewStatus : GripeStatus -> Html Msg
viewStatus status =
    div
        [ class "px-2 py-1 items-center rounded inline-flex border text-sm bg-white"
        , class (gripeStatusBg status)
        ]
        [ gripeStatusIcon status ("w-5 h-5 " ++ gripeStatusIconColor status)
        , span [ class "ml-2 font-medium" ] [ text (formatGripeStatus status) ]
        ]


gripeStatusIconColor : GripeStatus -> String
gripeStatusIconColor status =
    case status of
        GripeStatus.New ->
            "text-blue-500"

        GripeStatus.Actionable ->
            "text-red-700"

        GripeStatus.Done ->
            "text-green-600"

        GripeStatus.Discarded ->
            "text-gray-600"


gripeStatusBg : GripeStatus -> String
gripeStatusBg status =
    case status of
        GripeStatus.New ->
            "bg-blue-100 text-blue-700 border-blue-200"

        GripeStatus.Actionable ->
            "bg-red-100 text-red-800 border-red-300"

        GripeStatus.Done ->
            "bg-green-100 text-green-800 border-green-200"

        GripeStatus.Discarded ->
            "bg-gray-200 text-gray-600 border-gray-400"


view : Model -> Browser.Document Msg
view model =
    let
        vs status =
            div [ class "mb-8" ]
                [ div [ class "text-gray-500 text-sm mb-2" ]
                    [ text (GripeStatus.toString status |> String.toLower) ]
                , div [] [ viewStatus status ]
                ]
    in
    { title = "[dev] Stories"
    , body =
        [ div
            [ class "m-16" ]
            [ vs GripeStatus.New
            , vs GripeStatus.Actionable
            , vs GripeStatus.Done
            , vs GripeStatus.Discarded
            ]
        ]
    }
