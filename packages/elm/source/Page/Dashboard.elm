module Page.Dashboard exposing
    ( Model
    , Msg
    , handleTokenBeforeQuery
    , init
    , subscriptions
    , toSession
    , update
    , updateRoute
    , updateSession
    , view
    )

import Api.Enum.OnboardingStep as OnboardingStep
import Api.Enum.ProjectRole as ProjectRole
import Browser
import Browser.Navigation as Nav
import Components
import DashboardPage
import Gegangen exposing (formatError)
import Gegangen.Models exposing (Project)
import Gegangen.Requests as Requests
import Html exposing (..)
import Html.Attributes exposing (class, href, src, target, type_)
import Html.Events exposing (onClick)
import Icons
import Mailto
import Onboarding
import Page.Dashboard.Gripes as Gripes
import Page.Dashboard.Settings as Settings
import Ports.Auth as Auth
import Ports.Gripeless exposing (openGripeless)
import QueryType
import RemoteData
import Route.App as Route exposing (DashboardRoute, Route)
import ScalarCodecs exposing (GripeID(..))
import Session exposing (Session)
import Time
import UserData exposing (User)
import Util exposing (alternate)



-- MODEL


type Page
    = Gripes Gripes.Model
    | Settings Settings.Model
    | Loading
        -- Using a record here so as to keep the same "shape" of all the
        -- pages so that elm-hot can know where the session (and more
        -- importantly its Browser.Navigation.Key) is stored at
        { route : DashboardRoute
        , session : Session
        }
    | Error
        { reason : String
        , error : String
        , session : Session
        }


loadingPage : DashboardRoute -> Session -> Page
loadingPage route session =
    Loading { route = route, session = session }


errorPage : { reason : String, error : String } -> Session -> Page
errorPage { reason, error } session =
    Error { reason = reason, error = error, session = session }


type alias Model =
    { page : Page
    , projectName : String
    , projectData : Requests.ProjectResponse
    , userDropdownExpanded : Bool
    , onboardingExpanded : Bool
    , onboardingData : Requests.OnboardingResponse
    }



-- INIT


init : Session -> String -> DashboardRoute -> ( Model, Cmd Msg )
init session projectName route =
    let
        ( model, cmd ) =
            changeRouteTo route
                { page = Loading { route = route, session = session }
                , projectName = projectName
                , projectData = RemoteData.NotAsked
                , userDropdownExpanded = False
                , onboardingExpanded = True
                , onboardingData = RemoteData.NotAsked
                }
    in
    case session.user of
        UserData.Loading ->
            ( model, cmd )

        UserData.Loaded _ ->
            let
                ( secondModel, secondCmd ) =
                    loadProjectData model
            in
            ( secondModel, Cmd.batch [ cmd, secondCmd ] )

        UserData.Error error ->
            updatePage
                ( errorPage
                    { reason = "Failed to fetch user data"
                    , error = error
                    }
                    session
                , Cmd.none
                )
                model



-- UPDATE


type Msg
    = NoOp Never
    | ReloadPage
    | OpenGripeless String
    | ClickedSignOut
    | ToggleUserDropdown
    | ToggleShowOnboarding
    | RefreshOnboarding
    | ClickedFinishOnboarding
    | GotProjectResponse Requests.ProjectResponse
    | GotOnboardingResponse Requests.OnboardingResponse
    | GotGripesMsg Gripes.Msg
    | GotSettingsMsg Settings.Msg


changeRouteTo : DashboardRoute -> Model -> ( Model, Cmd Msg )
changeRouteTo route model =
    let
        session =
            toSession model
    in
    case ( session.user, model.projectData ) of
        ( UserData.Loaded user, RemoteData.Success project ) ->
            case ( route, model.page ) of
                ( Route.Gripes maybeGripeId, Gripes gripes ) ->
                    updatePage
                        (Gripes.updatePageGripeId maybeGripeId gripes
                            |> updateWith Gripes GotGripesMsg
                        )
                        model

                ( Route.Gripes maybeGripeId, _ ) ->
                    updatePage
                        (Gripes.init session user project maybeGripeId
                            |> updateWith Gripes GotGripesMsg
                        )
                        model

                ( Route.Settings, _ ) ->
                    updatePage
                        (Settings.init session project
                            |> updateWith Settings GotSettingsMsg
                        )
                        model

        ( _, _ ) ->
            updatePage ( Loading { route = route, session = session }, Cmd.none ) model


ensureUserHasAccessToProject : Project -> User -> Model -> ( Model, Cmd Msg )
ensureUserHasAccessToProject project user model =
    -- Redirect to login/select gripe pages if user doesn't have access to the project
    let
        session =
            toSession model
    in
    case ( project.role, user ) of
        ( ProjectRole.Admin, _ ) ->
            -- User can be anonymous or logged in, but only
            -- allow them in if they're an admin
            case model.page of
                Loading { route } ->
                    let
                        ( newModel, cmd ) =
                            changeRouteTo route model

                        ( newModel2, cmd2 ) =
                            refreshOnboarding newModel
                    in
                    ( newModel2, Cmd.batch [ cmd, cmd2 ] )

                _ ->
                    ( model, Cmd.none )

        ( ProjectRole.None, UserData.Anonymous _ ) ->
            -- Anonymous user with no project role, redirect to
            -- login page with a query parameter to redirect
            -- them back to this one
            ( model
            , Nav.replaceUrl
                session.key
                (Route.toString (Route.Login (Just project.name)))
            )

        ( ProjectRole.None, UserData.LoggedIn _ ) ->
            -- User is logged in but has no access to this
            -- project, kick them with an error into selecting
            -- a project they can actually access
            ( model
            , Nav.replaceUrl
                session.key
                (Route.toString (Route.SelectProject Nothing))
            )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        session =
            toSession model
    in
    case ( msg, model.page ) of
        ( NoOp _, _ ) ->
            ( model, Cmd.none )

        ( OpenGripeless projectName, _ ) ->
            ( model, openGripeless ( projectName, Nothing ) )

        ( ReloadPage, _ ) ->
            ( model, Nav.reload )

        ( ClickedSignOut, _ ) ->
            ( model
            , Cmd.batch
                [ Auth.signOut ()
                , Nav.pushUrl
                    session.key
                    (Route.toString (Route.Login Nothing))
                ]
            )

        ( ToggleShowOnboarding, _ ) ->
            ( { model | onboardingExpanded = not model.onboardingExpanded }
            , Cmd.none
            )

        ( RefreshOnboarding, _ ) ->
            refreshOnboarding model

        ( ClickedFinishOnboarding, _ ) ->
            ( model, Auth.prepareQuery (QueryType.encode QueryType.FinishOnboarding) )

        ( ToggleUserDropdown, _ ) ->
            ( { model
                | userDropdownExpanded = not model.userDropdownExpanded
              }
            , Cmd.none
            )

        ( GotProjectResponse response, Loading _ ) ->
            let
                newModel =
                    { model | projectData = response }
            in
            case ( response, session.user ) of
                ( RemoteData.Success project, UserData.Loaded user ) ->
                    ensureUserHasAccessToProject project user newModel

                _ ->
                    noOp newModel

        ( GotProjectResponse _, _ ) ->
            -- Discard project responses if page isn't loading
            noOp model

        ( GotOnboardingResponse response, _ ) ->
            ( { model | onboardingData = response }, Cmd.none )

        ( GotGripesMsg subMsg, Gripes gripes ) ->
            updatePage
                (Gripes.update subMsg gripes
                    |> updateWith Gripes GotGripesMsg
                )
                model

        ( GotSettingsMsg subMsg, Settings settings ) ->
            updatePage
                (Settings.update subMsg settings
                    |> updateWith Settings GotSettingsMsg
                )
                model

        ( GotGripesMsg _, _ ) ->
            noOp model

        ( GotSettingsMsg _, _ ) ->
            noOp model


updateRoute : String -> DashboardRoute -> Model -> ( Model, Cmd Msg )
updateRoute projectName route model =
    changeRouteTo route model


updatePage : ( Page, Cmd Msg ) -> Model -> ( Model, Cmd Msg )
updatePage ( page, cmd ) model =
    ( { model | page = page }, cmd )


updateWith :
    (subModel -> Page)
    -> (subMsg -> Msg)
    -> ( subModel, Cmd subMsg )
    -> ( Page, Cmd Msg )
updateWith toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel, Cmd.map toMsg subCmd )


noOp : Model -> ( Model, Cmd Msg )
noOp model =
    ( model, Cmd.none )


refreshOnboarding : Model -> ( Model, Cmd Msg )
refreshOnboarding model =
    ( model, Auth.prepareQuery (QueryType.encode QueryType.Onboarding) )


handleTokenBeforeQuery : Model -> Auth.DecodedPrepareQueryData -> ( Model, Cmd Msg )
handleTokenBeforeQuery model tokenData =
    let
        session =
            toSession model
    in
    case tokenData.queryType of
        -- Dirty hack to let dashboard sub pages trigger an update on the
        -- onboarding data
        Just QueryType.Onboarding ->
            let
                request =
                    ( model
                    , Requests.onboarding
                        session.apiURL
                        model.projectName
                        GotOnboardingResponse
                        tokenData.token
                    )
            in
            case model.onboardingData of
                RemoteData.Success OnboardingStep.Done ->
                    noOp model

                RemoteData.Success _ ->
                    request

                RemoteData.NotAsked ->
                    request

                RemoteData.Loading ->
                    request

                RemoteData.Failure _ ->
                    request

        Just QueryType.FinishOnboarding ->
            ( model
            , Requests.finishOnboarding
                session.apiURL
                model.projectName
                GotOnboardingResponse
                tokenData.token
            )

        _ ->
            case model.page of
                Gripes gripes ->
                    updatePage
                        (Gripes.handleTokenBeforeQuery gripes tokenData
                            |> updateWith Gripes GotGripesMsg
                        )
                        model

                Settings settings ->
                    updatePage
                        (Settings.handleTokenBeforeQuery settings tokenData
                            |> updateWith Settings GotSettingsMsg
                        )
                        model

                Loading _ ->
                    case tokenData.queryType of
                        Just QueryType.Project ->
                            ( model
                            , Requests.project
                                session.apiURL
                                model.projectName
                                GotProjectResponse
                                tokenData.token
                            )

                        _ ->
                            ( model, Cmd.none )

                Error _ ->
                    ( model, Cmd.none )


loadProjectData : Model -> ( Model, Cmd Msg )
loadProjectData model =
    ( { model | projectData = RemoteData.Loading }
    , Auth.prepareQuery (QueryType.encode QueryType.Project)
    )



-- VIEW


failedToLoginText : String
failedToLoginText =
    "Failed to authenticate"


failedToFetchText : String
failedToFetchText =
    "Failed to fetch data"


viewHeaderButton : String -> Route -> Bool -> Html Msg
viewHeaderButton label route isActive =
    a
        [ Route.link route
        , class "px-4 py-1 text-gray-100 border rounded-lg text-sm mr-4"
        , if isActive then
            class "text-gray-100 bg-gray-800 border-transparent"

          else
            class "text-gray-400 bg-gray-700 border-gray-800 hover:bg-gray-800 hover:text-gray-100"
        ]
        [ text label ]


viewUserDropdown : String -> User -> Project -> Bool -> Html Msg
viewUserDropdown defaultAvatarURL user project expanded =
    div [ class "bg-gray-800 text-white relative w-64 z-30 flex-none" ]
        [ button
            [ onClick ToggleUserDropdown
            , class "block w-full hover:bg-gray-900"
            ]
            [ div [ class "flex justify-between items-center px-4 h-16 shadow-md" ]
                [ div [ class "flex items-center" ]
                    (case user of
                        UserData.LoggedIn loggedInUser ->
                            [ img [ src (Maybe.withDefault defaultAvatarURL loggedInUser.picture), class "rounded-full w-10 h-10 shadow" ] []
                            , div [ class "ml-3 text-left" ]
                                [ div [ class "font-medium" ]
                                    [ text
                                        (Maybe.withDefault
                                            loggedInUser.email
                                            loggedInUser.name
                                        )
                                    ]
                                , div [ class "text-sm text-gray-400" ] [ text project.name ]
                                ]
                            ]

                        UserData.Anonymous _ ->
                            [ img [ src defaultAvatarURL, class "rounded-full w-10 h-10 shadow" ] []
                            , div [ class "ml-3 text-left" ]
                                [ div [ class "font-medium" ]
                                    [ span [ class "text-sm text-yellow-400" ] [ text "⚠ " ]
                                    , text "Anonymous"
                                    ]
                                , div [ class "text-sm text-gray-400" ] [ text project.name ]
                                ]
                            ]
                    )
                , div [] [ alternate expanded Icons.cheveronUp Icons.cheveronDown "w-6 h-6 text-gray-200" ]
                ]
            ]
        , if expanded then
            div [ class "p-4 absolute inset-x-0 bg-gray-700 border-t border-gray-800" ]
                (case user of
                    UserData.LoggedIn _ ->
                        [ a
                            [ Route.link (Route.SelectProject Nothing)
                            , class "text-center block p-2 font-medium w-full hover:bg-gray-900 bg-gray-800 rounded-lg border border-transparent"
                            ]
                            [ text "Switch projects..." ]
                        , button
                            [ onClick ClickedSignOut
                            , class "p-2 font-medium w-full hover:bg-gray-900 border border-gray-800 rounded-lg mt-3"
                            ]
                            [ text "Sign out" ]
                        ]

                    UserData.Anonymous _ ->
                        [ a
                            [ Route.link (Route.Login (Just project.name))
                            , class "text-center block p-2 font-medium w-full hover:bg-gray-900 bg-gray-800 rounded-lg border border-transparent"
                            ]
                            [ text "Claim project" ]
                        , div [ class "text-sm text-gray-300 mt-3 flex" ]
                            [ div [ class "mr-1" ] [ Icons.information "w-4 h-4" ]
                            , div [] [ text "You will be made the owner of this project after you sign in with a new account." ]
                            ]
                        ]
                )

          else
            text ""
        ]


helpItems : String -> String -> String -> List (Html Msg)
helpItems supportEmail gripelessProjectName classes =
    [ a
        [ href (Mailto.mailto supportEmail |> Mailto.toString)
        , target "_blank"
        , class "px-3 py-1 text-gray-400 bg-gray-700 border-gray-800 text-sm flex items-center"
        , class "hover:bg-gray-800 hover:text-gray-100"
        , class classes
        ]
        [ text "Support"
        , Icons.mail "ml-2 w-5 h-5"
        ]
    , button
        [ onClick
            (OpenGripeless gripelessProjectName)
        , class "px-3 py-1 text-gray-400 bg-gray-700 border-gray-800 text-sm flex items-center"
        , class "hover:bg-gray-800 hover:text-gray-100"
        , class classes
        ]
        [ text "Report an issue"
        , Icons.exclamation "ml-2 w-5 h-5"
        ]
    , a
        [ href "/docs/"
        , target "_blank"
        , class "px-3 py-1 text-gray-400 bg-gray-700  border-gray-800 text-sm flex items-center"
        , class "hover:bg-gray-800 hover:text-gray-100"
        , class classes
        ]
        [ text "Documentation"
        , Icons.externalLink "ml-2 w-5 h-5"
        ]
    ]


viewHeader : String -> String -> User -> Project -> Page -> String -> Bool -> Html Msg
viewHeader supportEmail defaultAvatarURL user project page gripelessProjectName isUserDropdownExpanded =
    div [ class "flex-none w-full h-16 bg-gray-700 flex items-stretch" ]
        [ viewUserDropdown defaultAvatarURL user project isUserDropdownExpanded
        , div [ class "flex-grow flex justify-between" ]
            [ div [ class "ml-4 flex items-center" ]
                [ viewHeaderButton
                    "Gripes"
                    (Route.Dashboard project.name (Route.Gripes Nothing))
                    (case page of
                        Gripes _ ->
                            True

                        _ ->
                            False
                    )
                , viewHeaderButton
                    "Settings"
                    (Route.Dashboard project.name Route.Settings)
                    (case page of
                        Settings _ ->
                            True

                        _ ->
                            False
                    )

                -- , button [ class "px-5 py-2 text-gray-400 bg-gray-700 border border-gray-800 rounded-lg text-sm mr-5 hover:bg-gray-800 hover:text-gray-100" ] [ text "Settings" ]
                ]
            , div [ class "flex items-center lg:hidden pr-4" ]
                [ div
                    [ class "group relative cursor-pointer px-3 py-1 text-gray-400 bg-gray-700 border-gray-800 border rounded-lg text-sm flex items-center"
                    , class "hover:bg-gray-800 hover:text-gray-100"
                    ]
                    [ Icons.help "mr-2 w-5 h-5"
                    , text "Help"
                    , Icons.cheveronDown "ml-2 w-5 h-5"
                    , div [ class "absolute right-0 top-0 hidden group-hover:block p-2 w-48 rounded-lg bg-gray-700 border border-gray-800 shadow-lg cursor-auto" ]
                        (helpItems
                            supportEmail
                            gripelessProjectName
                            "rounded-lg mb-0 last:mb-0 w-full py-2"
                        )
                    ]
                ]
            , div
                [ class "items-center pr-4 hidden lg:flex" ]
                (helpItems supportEmail gripelessProjectName "rounded-lg ml-2")
            ]
        ]


viewDashboard : Model -> User -> Project -> Browser.Document Msg
viewDashboard model user project =
    let
        session =
            toSession model

        { title, body, sidebar } =
            case model.page of
                Gripes gripes ->
                    DashboardPage.mapMsg GotGripesMsg (Gripes.view gripes)

                Settings settings ->
                    DashboardPage.mapMsg GotSettingsMsg (Settings.view settings)

                Loading _ ->
                    -- Invalid state
                    DashboardPage.mapMsg NoOp DashboardPage.empty

                Error { reason, error } ->
                    -- Invalid state
                    DashboardPage.mapMsg NoOp DashboardPage.empty
    in
    { title = title
    , body =
        [ div [ class "flex flex-col w-screen h-screen bg-gray-300 relative" ]
            [ viewHeader
                session.supportEmail
                session.resources.defaultAvatarURL
                user
                project
                model.page
                session.gripelessProjectName
                model.userDropdownExpanded
            , div [ class "w-screen flex flex-grow overflow-y-auto items-stretch" ]
                [ div
                    [ class "flex-none w-64 overflow-y-auto bg-gray-100 shadow-lg z-10 p-4"
                    , class "flex flex-col justify-between"
                    ]
                    [ div [] sidebar ]
                , div [ class "flex-auto bg-gray-100" ] [ body ]
                ]
            , Onboarding.view
                { projectName = project.name
                , sdkURL = session.sdkURL
                , clickedOpenGripeless = OpenGripeless project.name
                , clickedFinishOnboarding = ClickedFinishOnboarding
                , retryOnboarding = ReloadPage
                , toggled = ToggleShowOnboarding
                , isExpanded = model.onboardingExpanded
                , stepData = model.onboardingData
                , supportEmail = session.supportEmail
                }
            ]
        ]
    }


view : Model -> Browser.Document Msg
view model =
    let
        session =
            toSession model

        { title, body } =
            case session.user of
                UserData.Loading ->
                    let
                        s =
                            "Authenticating…"
                    in
                    { title = s
                    , body = [ Components.viewFullscreenLoader s ]
                    }

                UserData.Error error ->
                    { title = "User error"
                    , body =
                        [ Components.viewFullscreenThing <|
                            [ Components.viewErrorBox
                                failedToLoginText
                                error
                                ReloadPage
                            ]
                        ]
                    }

                UserData.Loaded user ->
                    case model.projectData of
                        RemoteData.Loading ->
                            let
                                s =
                                    "Loading project…"
                            in
                            { title = s
                            , body = [ Components.viewFullscreenLoader s ]
                            }

                        RemoteData.NotAsked ->
                            let
                                s =
                                    "Preparing to load project…"
                            in
                            { title = s
                            , body = [ Components.viewFullscreenLoader s ]
                            }

                        RemoteData.Failure error ->
                            { title = "Failed to load project"
                            , body =
                                [ Components.viewFullscreenThing
                                    [ Components.viewErrorBox
                                        failedToFetchText
                                        (formatError error)
                                        ReloadPage
                                    ]
                                ]
                            }

                        RemoteData.Success project ->
                            viewDashboard model user project
    in
    { title = title ++ " | Gripeless"
    , body = body
    }



-- SUB


subscriptions : Model -> Sub Msg
subscriptions { page, onboardingData } =
    Sub.batch
        [ case onboardingData of
            RemoteData.Success OnboardingStep.ReportGripe ->
                Time.every 2000 (\_ -> RefreshOnboarding)

            _ ->
                Sub.none
        , case page of
            Gripes gripes ->
                Sub.map GotGripesMsg (Gripes.subscriptions gripes)

            Settings settings ->
                Sub.map GotSettingsMsg (Settings.subscriptions settings)

            Loading _ ->
                Sub.none

            Error _ ->
                Sub.none
        ]



-- MISC


toLoading : ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
toLoading ( model, cmd ) =
    let
        session =
            toSession model
    in
    case model.page of
        -- Discard the current page's model and go into loading
        Gripes gripes ->
            updatePage ( loadingPage (Route.Gripes gripes.gripeId) session, cmd ) model

        Settings _ ->
            updatePage ( loadingPage Route.Settings session, cmd ) model

        Loading { route } ->
            updatePage ( loadingPage route session, cmd ) model

        Error _ ->
            ( model, cmd )


updateSession : Model -> Session -> ( Model, Cmd Msg )
updateSession m session =
    let
        previousSession =
            toSession m

        ( newPage, cmd ) =
            case m.page of
                Loading { route } ->
                    ( loadingPage route session, Cmd.none )

                Settings settings ->
                    Settings.updateSession settings session
                        |> updateWith Settings GotSettingsMsg

                Gripes gripes ->
                    Gripes.updateSession gripes session
                        |> updateWith Gripes GotGripesMsg

                Error _ ->
                    ( m.page, Cmd.none )

        newModel =
            { m | page = newPage }
    in
    if previousSession.user /= session.user then
        case session.user of
            UserData.Loaded user ->
                toLoading (loadProjectData newModel)

            UserData.Loading ->
                toLoading ( newModel, Cmd.none )

            UserData.Error error ->
                updatePage
                    ( errorPage
                        { reason = "Failed to fetch user data"
                        , error = error
                        }
                        session
                    , Cmd.none
                    )
                    m

    else
        ( newModel, cmd )


toSession : Model -> Session
toSession model =
    case model.page of
        Loading { session } ->
            session

        Error { session } ->
            session

        Gripes gripes ->
            Gripes.toSession gripes

        Settings settings ->
            Settings.toSession settings
