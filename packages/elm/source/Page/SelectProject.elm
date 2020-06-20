module Page.SelectProject exposing
    ( Model
    , Msg
    , handleTokenBeforeQuery
    , init
    , toSession
    , update
    , updateSession
    , view
    )

import Browser
import Browser.Navigation as Nav
import Components
import Gegangen exposing (formatError)
import Gegangen.Models as Models
import Gegangen.Requests as Requests
import Html exposing (..)
import Html.Attributes exposing (class, href, src, type_)
import Html.Events exposing (onClick)
import Icons
import Ports.Auth as Auth
import Ports.Gripeless exposing (openGripeless)
import QueryType
import RemoteData exposing (RemoteData)
import Route.App as Route
import Session exposing (Session)
import UserData


type alias Model =
    { session : Session
    , ownedProjectsData : Requests.OwnedProjectsResponse
    , maybeRedirectToProjectName : Maybe String
    }


type Msg
    = OpenGripeless
    | ClickedSignOut
    | ReloadPage
    | RefreshProjects
    | GotOwnedProjectsResponse Requests.OwnedProjectsResponse


init : Session -> Maybe String -> ( Model, Cmd Msg )
init session maybeRedirectToProjectName =
    let
        model =
            { session = session
            , ownedProjectsData = RemoteData.NotAsked
            , maybeRedirectToProjectName = maybeRedirectToProjectName
            }
    in
    case session.user of
        UserData.Loaded (UserData.LoggedIn _) ->
            loadOwnedProjects model

        UserData.Loaded (UserData.Anonymous user) ->
            redirectToLogin model

        _ ->
            ( model, Cmd.none )


loadOwnedProjects : Model -> ( Model, Cmd Msg )
loadOwnedProjects model =
    ( { model | ownedProjectsData = RemoteData.Loading }
    , Auth.prepareQuery
        (QueryType.encode QueryType.OwnedProjects)
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OpenGripeless ->
            ( model, openGripeless ( model.session.gripelessProjectName, Nothing ) )

        ReloadPage ->
            ( model, Nav.reload )

        ClickedSignOut ->
            ( model
            , Cmd.batch
                [ Nav.replaceUrl model.session.key (Route.toString (Route.Login Nothing))
                , Auth.signOut ()
                ]
            )

        RefreshProjects ->
            loadOwnedProjects model

        GotOwnedProjectsResponse response ->
            let
                newModel =
                    { model | ownedProjectsData = response }
            in
            case ( response, model.maybeRedirectToProjectName ) of
                ( RemoteData.Success projects, Just projectName ) ->
                    if List.member projectName (List.map .name projects) then
                        ( model
                        , Nav.replaceUrl
                            model.session.key
                            (Route.toString
                                (Route.Dashboard projectName
                                    (Route.Gripes Nothing)
                                )
                            )
                        )

                    else
                        ( newModel, Cmd.none )

                _ ->
                    ( newModel, Cmd.none )


handleTokenBeforeQuery : Model -> Auth.DecodedPrepareQueryData -> ( Model, Cmd Msg )
handleTokenBeforeQuery model { token, queryType } =
    case queryType of
        Just QueryType.OwnedProjects ->
            ( model
            , Requests.ownedProjects
                model.session.apiURL
                GotOwnedProjectsResponse
                token
            )

        _ ->
            ( model, Cmd.none )


viewProjectList : List Models.Project -> List (Html Msg)
viewProjectList =
    List.map
        (\project ->
            a [ Route.link (Route.Dashboard project.name (Route.Gripes Nothing)) ]
                [ div [ class "border w-full mb-2 py-2 px-4 rounded hover:bg-red-300 hover:border-red-300" ]
                    [ text project.name
                    ]
                ]
        )


viewSpinner : Html Msg
viewSpinner =
    Components.spinner "my-16"


view : Model -> Browser.Document Msg
view model =
    { title = "Select Project | Gripeless"
    , body =
        [ Components.fullscreenBox model.session.host
            OpenGripeless
            [ h1 [ class "my-2 text-3xl font-black" ] [ text "Select project" ]
            , p [ class "mb-4" ]
                [ text "Pick a project of yours that you want to go to." ]
            , case model.session.user of
                UserData.Error error ->
                    Components.viewErrorBox "Failed to fetch user data" error ReloadPage

                UserData.Loading ->
                    viewSpinner

                UserData.Loaded (UserData.Anonymous _) ->
                    -- Invalid state, due to `redirectToLoginIfAnonymous`
                    text ""

                UserData.Loaded (UserData.LoggedIn user) ->
                    -- text ""
                    case model.ownedProjectsData of
                        RemoteData.NotAsked ->
                            text ""

                        RemoteData.Loading ->
                            viewSpinner

                        RemoteData.Failure error ->
                            Components.viewErrorBox "Failed to fetch projects"
                                (formatError error)
                                RefreshProjects

                        RemoteData.Success projects ->
                            div [] (viewProjectList projects)
            , a [ Route.link Route.CreateProject ]
                [ div
                    [ class "w-full text-gray-600 mt-4 mb-2 font-sm flex items-center hover:text-gray-800" ]
                    [ Icons.plus "w-6 h-6", text "Create a new project..." ]
                ]
            ]
        ]

    -- [ case model.session.user of
    --                 div []
    --                     [ div []
    --                         [ div [ class "text-sm text-gray-600" ] [ text "Logged in as" ]
    --                         , div [ class "mt-2 select-none border shadow inline-flex mx-auto items-center rounded-lg" ]
    --                             [ img
    --                                 [ class "rounded-l-lg w-8 h-8"
    --                                 , src (Maybe.withDefault "/img/default-avatar.png" user.picture)
    --                                 ]
    --                                 []
    --                             , span [ class "ml-2 mr-2" ] [ text user.email ]
    --                             ]
    --                         ]
    --                     , button
    --                         [ onClick ClickedSignOut, type_ "button" ]
    --                         [ text "Not you?" ]
    --                     , div [] [ h1 [ class "text-3xl mt-4 font-black" ] [ text "Select project" ] ]
    --                     , div [ class "mt-4" ] (viewProjectList projects)
    --                     ]
    -- ]
    }


redirectToLogin : Model -> ( Model, Cmd Msg )
redirectToLogin model =
    ( model
    , Nav.replaceUrl model.session.key
        (Route.toString (Route.Login Nothing))
    )


updateSession : Model -> Session -> ( Model, Cmd Msg )
updateSession model session =
    let
        newModel =
            { model | session = session }
    in
    case session.user of
        UserData.Loaded loadedUser ->
            case loadedUser of
                UserData.Anonymous _ ->
                    redirectToLogin newModel

                UserData.LoggedIn _ ->
                    if model.session.user /= session.user then
                        loadOwnedProjects newModel

                    else
                        ( newModel, Cmd.none )

        _ ->
            ( newModel, Cmd.none )


toSession : Model -> Session
toSession model =
    model.session
