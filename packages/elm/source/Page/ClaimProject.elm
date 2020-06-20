module Page.ClaimProject exposing
    ( Model
    , Msg
    , handleTokenBeforeQuery
    , init
    , subscriptions
    , toSession
    , update
    , updateSession
    , view
    )

import Browser
import Browser.Navigation as Nav
import Components
import Gegangen
import Gegangen.Requests as Requests
import Html exposing (..)
import Ports.Auth as Auth
import QueryType
import RemoteData exposing (RemoteData)
import Route.App as Route
import Session exposing (Session)
import UserData


type alias Model =
    { session : Session
    , claimKey : Maybe String
    , claimProjectData : Requests.ProjectResponse
    }


type Msg
    = ReloadPage
    | GotClaimProjectResponse Requests.ProjectResponse


init : Session -> Maybe String -> ( Model, Cmd Msg )
init session claimKey =
    updateSession
        { session = session
        , claimKey = claimKey
        , claimProjectData = RemoteData.NotAsked
        }
        session


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReloadPage ->
            ( model, Nav.reload )

        GotClaimProjectResponse data ->
            let
                newModel =
                    { model | claimProjectData = data }
            in
            case data of
                RemoteData.Loading ->
                    ( newModel, Cmd.none )

                RemoteData.NotAsked ->
                    ( newModel, Cmd.none )

                RemoteData.Failure _ ->
                    ( newModel, Cmd.none )

                RemoteData.Success project ->
                    ( newModel
                    , Nav.pushUrl
                        model.session.key
                        (Route.toString (Route.Dashboard project.name (Route.Gripes Nothing)))
                    )


handleTokenBeforeQuery : Model -> Auth.DecodedPrepareQueryData -> ( Model, Cmd Msg )
handleTokenBeforeQuery model tokenData =
    case ( tokenData.queryType, model.claimKey ) of
        ( Just QueryType.ClaimProject, Just claimKey ) ->
            ( { model
                | claimProjectData = RemoteData.Loading
              }
            , Requests.claimProject
                model.session.apiURL
                claimKey
                GotClaimProjectResponse
                tokenData.token
            )

        _ ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


view : Model -> Browser.Document Msg
view model =
    { title = "Claiming project... | Gripeless"
    , body =
        [ case model.session.user of
            UserData.Loading ->
                Components.viewFullscreenLoader "Authenticating…"

            UserData.Error error ->
                Components.viewFullscreenThing
                    [ Components.viewErrorBox "Failed to authenticate" error ReloadPage ]

            UserData.Loaded _ ->
                case model.claimProjectData of
                    RemoteData.NotAsked ->
                        Components.viewFullscreenThing
                            [ Components.viewErrorBox
                                "Missing claim project key"
                                "Please double check the URL and reload the page"
                                ReloadPage
                            ]

                    RemoteData.Loading ->
                        Components.viewFullscreenLoader "Claiming project..."

                    RemoteData.Failure error ->
                        Components.viewFullscreenThing
                            [ Components.viewErrorBox
                                "Failed to claim project"
                                (Gegangen.formatError error)
                                ReloadPage
                            ]

                    RemoteData.Success project ->
                        text "Project claimed!"
        ]
    }


claimProject : Model -> ( Model, Cmd Msg )
claimProject model =
    ( model, Auth.prepareQuery (QueryType.encode QueryType.ClaimProject) )


updateSession : Model -> Session -> ( Model, Cmd Msg )
updateSession model session =
    let
        newModel =
            { model | session = session }
    in
    if model.session.user /= session.user then
        case session.user of
            UserData.Loaded _ ->
                claimProject newModel

            _ ->
                ( newModel, Cmd.none )

    else
        ( newModel, Cmd.none )


toSession : Model -> Session
toSession model =
    model.session
